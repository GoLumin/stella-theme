# frozen_string_literal: true

# The ROI calculator (src/components/RoiCalculator.svelte): its first state,
# worked out here so the page arrives with the default figures in place, as
# the Astro site's server render did. stella/roi-calculator.js does the same
# sums in the browser as the visitor changes them; the two must agree.
module StellaRoiHelper
  ROI_FIELDS = [
    {key: "trucks", kind: "number", min: 0, step: 1, label: "Number of trucks", value: 2},
    {key: "jobs", kind: "number", min: 0, step: 0.1, label: "Dispatched jobs per day", value: 4},
    {key: "revenue", kind: "number", min: 0, step: 1, label: "Average revenue per job ($)", value: 193},
    {key: "days", kind: "number", min: 1, step: 1, label: "Working days per month", value: 22},
    {key: "containers", kind: "number", min: 0, step: 1, label: "Number of containers", value: 200},
    {key: "rent", kind: "number", min: 0, step: 1, label: "Avg monthly rental per container ($)", value: 175},
    {key: "utilization", kind: "slider", min: 0, max: 100, step: 1, suffix: "%", label: "Current utilization rate", value: 92},
    {key: "extra_jobs", kind: "slider", min: 0, max: 3, step: 0.1, decimals: 1, label: "Expected extra jobs per truck per day from better scheduling", value: 2},
    {key: "util_lift", kind: "slider", min: 0, max: 25, step: 1, prefix: "+", suffix: " pts", label: "Expected utilization lift from better asset visibility", value: 5},
    {key: "hours", kind: "number", min: 0, step: 1, label: "Billing/admin hours per month", value: 80},
    {key: "cost", kind: "number", min: 0, step: 1, label: "Estimated Stella monthly cost ($)", value: 2000}
  ].freeze

  ROI_CARDS = [
    {key: "current_delivery", label: "Current monthly delivery revenue"},
    {key: "current_storage", label: "Current monthly storage revenue"},
    {key: "projected_delivery", label: "Projected monthly delivery revenue", lift: "delivery_lift"},
    {key: "projected_storage", label: "Projected monthly storage revenue", lift: "storage_lift"},
    {key: "monthly_impact", label: "Total monthly revenue impact"},
    {key: "annual_impact", label: "Annual revenue impact"},
    {key: "admin_savings", label: "Admin cost savings"},
    {key: "total_impact", label: "Total financial impact"}
  ].freeze

  ROI_DISCUSSION = [
    "Today you're generating about {current_total} a month across delivery activity and storage revenue.",
    "Add {extra_jobs} more jobs per truck per day and lift utilization by {util_lift} points, and that's {monthly_impact} in new monthly revenue.",
    "Add roughly {admin_savings} a month in admin savings, and the total monthly upside reaches {total_impact}."
  ].freeze

  # Everything the calculator draws from the block: its fields (the block's
  # labels and starting values over the component's), scenarios, constants,
  # copy, and the figures for the starting values.
  def stella_roi(data)
    overrides = data.fields.filter_map { |field| [stella_str(field.key), field] if stella_str(field.key).present? }.to_h
    fields = ROI_FIELDS.map do |field|
      given = overrides[field[:key]]
      field.merge(label: stella_str(given&.label, field[:label]), value: stella_roi_num(given&.value, field[:value]))
    end
    presets = data.scenarios.map do |scenario|
      {label: stella_str(scenario.label), extra_jobs: stella_roi_num(scenario.extra_jobs, nil), util_lift: stella_roi_num(scenario.util_lift, nil)}
    end.select { it[:label].present? && it[:extra_jobs] && it[:util_lift] }
    hourly = stella_roi_num(data.admin_hourly_rate, 28)
    factor = stella_roi_num(data.admin_savings_factor, 0.5)
    lines = ->(value, fallback) { stella_list(value).reject(&:empty?).presence || fallback }
    values = fields.to_h { [it[:key], it[:value]] }

    {fields:, presets:, hourly:, factor:, values:, figures: stella_roi_figures(values, hourly, factor),
     inputs_title: stella_str(data.inputs_title, "Your numbers"), scenarios_label: stella_str(data.scenarios_label, "Scenario"),
     formula_title: stella_str(data.formula_title, "How this is worked out"),
     formula_lines: lines.(data.formula_lines, ["Delivery revenue/month = trucks × dispatched jobs/day × revenue/job × working days",
       "Storage revenue/month = containers × utilization × monthly rental",
       "Admin savings/month = billing/admin hours × #{stella_roi_money(hourly)} × #{(factor * 100).round}%"]),
     summary_title: stella_str(data.summary_title, "What it adds up to"),
     cards: ROI_CARDS.map { it.merge(label: stella_str(data["card_#{it[:key]}"], it[:label])) },
     discussion_title: stella_str(data.discussion_title, "What this means"),
     discussion: lines.(data.discussion_lines, ROI_DISCUSSION),
     payback: stella_str(data.payback_template, "This pays for itself in {payback_days} days."),
     total_label: stella_str(data.total_label, "Total upside"), disclaimer: stella_str(data.disclaimer)}
  end

  # What stella/roi-calculator.js needs to work the sums again, as a
  # <script type="application/json" data-roi-config>.
  def stella_roi_config(roi)
    config = {fields: roi[:fields].map { it.slice(:key, :kind, :min, :max, :decimals, :prefix, :suffix) }, presets: roi[:presets],
              hourly: roi[:hourly], factor: roi[:factor], discussion: roi[:discussion], payback: roi[:payback],
              cards: roi[:cards].map { it.slice(:key, :lift) }}
    tag.script(ERB::Util.json_escape(config.to_json).html_safe, type: "application/json", data: {roi_config: ""}) # rubocop:disable Rails/OutputSafety -- JSON-escaped
  end

  # The component's sums (its $derived values).
  def stella_roi_figures(v, hourly, factor)
    util = v["utilization"] / 100.0
    projected_util = [1, util + (v["util_lift"] / 100.0)].min
    current_delivery = v["trucks"] * v["jobs"] * v["revenue"] * v["days"]
    current_storage = v["containers"] * util * v["rent"]
    projected_delivery = v["trucks"] * (v["jobs"] + v["extra_jobs"]) * v["revenue"] * v["days"]
    projected_storage = v["containers"] * projected_util * v["rent"]
    monthly = (projected_delivery - current_delivery) + (projected_storage - current_storage)
    admin = v["hours"] * hourly * factor
    total = monthly + admin
    {"current_delivery" => current_delivery, "current_storage" => current_storage, "projected_delivery" => projected_delivery,
     "projected_storage" => projected_storage, "delivery_lift" => projected_delivery - current_delivery,
     "storage_lift" => projected_storage - current_storage, "monthly_impact" => monthly, "annual_impact" => monthly * 12,
     "admin_savings" => admin, "total_impact" => total, "current_total" => current_delivery + current_storage,
     "payback_days" => total.positive? ? [1, ((v["cost"].to_f / total) * 30).round].max : 0}
  end

  # A template's {placeholders} filled from the figures (the component's fill()).
  def stella_roi_fill(template, roi)
    f = roi[:figures]
    table = {"current_total" => stella_roi_money(f["current_total"]), "monthly_impact" => stella_roi_money(f["monthly_impact"]),
             "annual_impact" => stella_roi_money(f["annual_impact"]), "admin_savings" => stella_roi_money(f["admin_savings"]),
             "total_impact" => stella_roi_money(f["total_impact"]), "extra_jobs" => format("%.1f", roi[:values]["extra_jobs"]),
             "util_lift" => roi[:values]["util_lift"].round.to_s, "payback_days" => f["payback_days"].to_s}
    template.to_s.gsub(/\{(\w+)\}/) { table.fetch(::Regexp.last_match(1), ::Regexp.last_match(0)) }
  end

  # Intl.NumberFormat("en-US", {style: "currency", currency: "USD", maximumFractionDigits: 0}).
  def stella_roi_money(amount)
    amount = amount.to_f.finite? ? amount.to_f.round : 0
    "#{"-" if amount.negative?}$#{amount.abs.to_s.reverse.scan(/\d{1,3}/).join(",").reverse}"
  end

  # A slider's readout ("92%", "2.0", "+5 pts").
  def stella_roi_readout(field, value)
    number = field[:decimals] ? format("%.#{field[:decimals]}f", value) : value.round.to_s
    "#{field[:prefix]}#{number}#{field[:suffix]}"
  end

  # How far along its track a slider sits, as the component's --pct.
  def stella_roi_pct(field, value) = stella_roi_js_number(((value - field[:min]) * 100.0) / (field[:max] - field[:min]))

  # A number as JavaScript writes it: 92, not 92.0.
  def stella_roi_js_number(number) = (number.to_f == number.to_f.truncate) ? number.to_f.truncate.to_s : number.to_f.to_s

  # parseFloat, else the fallback.
  def stella_roi_num(value, fallback)
    return value if value.is_a?(Numeric)

    match = value.to_s.match(/\A\s*([+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)/)
    match ? match[1].to_f.then { (it == it.truncate) ? it.truncate : it } : fallback
  end
end
