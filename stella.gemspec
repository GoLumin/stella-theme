# frozen_string_literal: true

require_relative "lib/stella/version"

Gem::Specification.new do |spec|
  spec.name = "stella"
  spec.version = Stella::VERSION
  spec.summary = "The Stella website (runstella.com), as a CMS theme"
  spec.authors = ["Lumin"]
  spec.files = Dir["{app,config,lib,public}/**/*"]
  spec.required_ruby_version = ">= 3.3"
  spec.add_dependency "rails", ">= 8.1"
end
