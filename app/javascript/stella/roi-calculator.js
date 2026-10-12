// src/components/RoiCalculator.svelte's behavior, without Svelte: as the
// visitor changes a number, a slider or a scenario, the calculator's figures
// and sentences are worked out again, with the same sums and formatting the
// component used (the page arrives with them filled in, by StellaRoiHelper).
const root = document.querySelector(".roi[data-c-roi-app]")
const configEl = document.querySelector("script[data-roi-config]")

if (root && configEl) {
  const config = JSON.parse(configEl.textContent)
  const v = {}
  const inputs = {}
  for (const f of config.fields) {
    inputs[f.key] = root.querySelector(`#roi-${f.key}`)
    v[f.key] = readInput(inputs[f.key])
  }

  // Svelte's bind:value on a number input: a number, or null when it's empty (which sums as 0).
  function readInput(input) {
    if (!input || input.value === "") return null
    const n = Number(input.value)
    return Number.isFinite(n) ? n : null
  }

  const money = (n) =>
    new Intl.NumberFormat("en-US", { style: "currency", currency: "USD", maximumFractionDigits: 0 }).format(Number.isFinite(n) ? n : 0)

  function figures() {
    const util = v.utilization / 100
    const projectedUtil = Math.min(1, util + v.util_lift / 100)
    const currentDelivery = v.trucks * v.jobs * v.revenue * v.days
    const currentStorage = v.containers * util * v.rent
    const projectedDelivery = v.trucks * (v.jobs + v.extra_jobs) * v.revenue * v.days
    const projectedStorage = v.containers * projectedUtil * v.rent
    const deliveryLift = projectedDelivery - currentDelivery
    const storageLift = projectedStorage - currentStorage
    const monthlyImpact = deliveryLift + storageLift
    const adminSavings = v.hours * config.hourly * config.factor
    const totalImpact = monthlyImpact + adminSavings
    return {
      current_delivery: currentDelivery,
      current_storage: currentStorage,
      projected_delivery: projectedDelivery,
      projected_storage: projectedStorage,
      delivery_lift: deliveryLift,
      storage_lift: storageLift,
      monthly_impact: monthlyImpact,
      annual_impact: monthlyImpact * 12,
      admin_savings: adminSavings,
      total_impact: totalImpact,
      current_total: currentDelivery + currentStorage,
      payback_days: totalImpact > 0 ? Math.max(1, Math.round((v.cost / totalImpact) * 30)) : 0,
    }
  }

  const fill = (tpl, a) =>
    String(tpl ?? "").replace(/\{(\w+)\}/g, (whole, k) => {
      const table = {
        current_total: money(a.current_total),
        monthly_impact: money(a.monthly_impact),
        annual_impact: money(a.annual_impact),
        admin_savings: money(a.admin_savings),
        total_impact: money(a.total_impact),
        extra_jobs: v.extra_jobs.toFixed(1),
        util_lift: String(Math.round(v.util_lift)),
        payback_days: String(a.payback_days),
      }
      return k in table ? table[k] : whole
    })

  const readout = (f) => {
    const n = f.decimals ? v[f.key].toFixed(f.decimals) : String(Math.round(v[f.key]))
    return `${f.prefix ?? ""}${n}${f.suffix ?? ""}`
  }

  function render() {
    const a = figures()
    for (const f of config.fields) {
      if (f.kind !== "slider") continue
      inputs[f.key].style.setProperty("--pct", `${((v[f.key] - f.min) * 100) / (f.max - f.min)}%`)
      root.querySelector(`output[for="roi-${f.key}"]`).textContent = readout(f)
    }
    root.querySelectorAll(".roi-card").forEach((card, i) => {
      const c = config.cards[i]
      card.querySelector(".roi-card-v").textContent = money(a[c.key])
      if (c.lift) card.querySelector(".roi-card-lift").textContent = `${money(a[c.lift])} lift`
    })
    root.querySelectorAll(".roi-discussion p").forEach((p, i) => { p.textContent = fill(config.discussion[i], a) })
    root.querySelector(".roi-payback").textContent = fill(config.payback, a)
    root.querySelector(".roi-total-v").firstChild.textContent = money(a.total_impact)
  }

  for (const f of config.fields) {
    inputs[f.key].addEventListener("input", () => {
      v[f.key] = readInput(inputs[f.key])
      render()
    })
  }

  // A scenario sets the two "better scheduling" sliders, and stays marked until another is picked.
  root.querySelectorAll(".roi-preset").forEach((button, i) => {
    button.addEventListener("click", () => {
      root.querySelectorAll(".roi-preset").forEach((b, j) => {
        b.classList.toggle("is-active", i === j)
        b.setAttribute("aria-pressed", String(i === j))
      })
      const preset = config.presets[i]
      v.extra_jobs = preset.extra_jobs
      v.util_lift = preset.util_lift
      inputs.extra_jobs.value = String(preset.extra_jobs)
      inputs.util_lift.value = String(preset.util_lift)
      render()
    })
  })
}
