# frozen_string_literal: true

require "net/http"

module Stella
  # SMS short links: https://www.runstella.com/l/<8-character hash>. Stella's
  # API owns the hash → address mapping (it's a customer's work order); this
  # only asks it. A port of the Astro site's src/pages/l/[hash].ts, itself a
  # port of the old site's redirector.php. Links already sitting in customers'
  # text messages point here, so the address has to stay on the site.
  #
  # The API and its client credentials come from the host's environment:
  # API_BASE_URL, AUTH_LOGIN_CLIENT_ID and AUTH_LOGIN_CLIENT_SECRET.
  module ShortLink
    class Error < StandardError; end

    HASH = /\A[0-9a-zA-Z]{8}\z/
    TOKEN_CACHE_KEY = "stella/short_link/token"
    TIMEOUT = 15

    module_function

    # The address the hash stands for; raises Error when there isn't one.
    def resolve(hash)
      raise Error, "not a short link hash" unless HASH.match?(hash.to_s)

      base, client_id, client_secret = ENV.values_at("API_BASE_URL", "AUTH_LOGIN_CLIENT_ID", "AUTH_LOGIN_CLIENT_SECRET")
      if [base, client_id, client_secret].any?(&:blank?)
        raise Error, "missing API_BASE_URL, AUTH_LOGIN_CLIENT_ID or AUTH_LOGIN_CLIENT_SECRET"
      end
      base = base.chomp("/")

      response = post("#{base}/api/order-link", {hash:}.to_json, "Content-Type" => "application/json",
        "Authorization" => "Bearer #{token(base, client_id, client_secret)}")
      Rails.cache.delete(TOKEN_CACHE_KEY) if response.code == "401"

      link = parse(response)["link"]
      raise Error, "order-link lookup failed: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess) && link.is_a?(String) && link.present?

      # Only ever send people to a web page: never javascript:, data: and the like.
      uri = URI.parse(link)
      raise Error, "unsafe redirect scheme #{uri.scheme}" unless %w[http https].include?(uri.scheme&.downcase) && uri.host.present?

      link
    rescue URI::InvalidURIError, JSON::ParserError, SystemCallError, IOError, OpenSSL::SSL::SSLError, Timeout::Error, SocketError => e
      raise Error, e.message
    end

    # client_credentials tokens are good until they expire, so one serves
    # every click until a minute before then, rather than one per click.
    def token(base, client_id, client_secret)
      cached = Rails.cache.read(TOKEN_CACHE_KEY)
      return cached if cached

      response = post("#{base}/oauth/token",
        URI.encode_www_form(grant_type: "client_credentials", client_id:, client_secret:),
        "Content-Type" => "application/x-www-form-urlencoded")
      body = parse(response)
      raise Error, "token request failed: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess) && body["access_token"].present?

      ttl = body["expires_in"].to_i - 60
      Rails.cache.write(TOKEN_CACHE_KEY, body["access_token"], expires_in: ttl) if ttl.positive?
      body["access_token"]
    end

    def post(url, body, headers)
      uri = URI.parse(url)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
        http.post(uri.request_uri, body, headers.merge("Accept" => "application/json"))
      end
    end

    def parse(response)
      body = JSON.parse(response.body.to_s)
      body.is_a?(Hash) ? body : {}
    rescue JSON::ParserError
      {}
    end
  end
end
