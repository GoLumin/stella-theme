// src/layouts/Layout.astro's script: scroll reveal, count-up numbers, and
// live formatting of phone and website inputs. Progressive enhancement:
// without it, everything is visible and plain.
const prefersReduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches

/* Scroll reveal: leaves content visible without JS. */
const revealNodes = document.querySelectorAll(".reveal")
if (prefersReduced || !("IntersectionObserver" in window)) {
  revealNodes.forEach((n) => n.classList.add("in"))
} else {
  const io = new IntersectionObserver(
    (entries) => {
      entries.forEach((e) => {
        if (e.isIntersecting) { e.target.classList.add("in"); io.unobserve(e.target) }
      })
    },
    { threshold: 0.14, rootMargin: "0px 0px -8% 0px" }
  )
  revealNodes.forEach((n) => io.observe(n))
}

/* Count-up for [data-count] elements. */
if (!prefersReduced && "IntersectionObserver" in window) {
  const fmt = (n, dp) => n.toLocaleString("en-US", { minimumFractionDigits: dp, maximumFractionDigits: dp })
  const countIO = new IntersectionObserver(
    (entries) => {
      entries.forEach((e) => {
        if (!e.isIntersecting) return
        const el = e.target
        countIO.unobserve(el)
        const target = parseFloat(el.dataset.count || "0")
        const dp = (el.dataset.count || "").includes(".") ? el.dataset.count.split(".")[1].length : 0
        const prefix = el.dataset.prefix || ""
        const suffix = el.dataset.suffix || ""
        const start = performance.now()
        const tick = (now) => {
          const p = Math.min((now - start) / 2400, 1)
          const eased = 1 - Math.pow(1 - p, 3)
          el.textContent = prefix + fmt(target * eased, dp) + suffix
          if (p < 1) requestAnimationFrame(tick)
          else el.textContent = prefix + fmt(target, dp) + suffix
        }
        requestAnimationFrame(tick)
      })
    },
    { threshold: 0.5 }
  )
  document.querySelectorAll("[data-count]").forEach((n) => countIO.observe(n))
}

/* Live input formatting: phone → (555) 555-5555 as you type; website tidies to a bare host. */
document.querySelectorAll('input[data-format="phone"]').forEach((el) => {
  el.addEventListener("input", () => {
    const d = el.value.replace(/\D/g, "").slice(0, 10)
    let out = d
    if (d.length > 6) out = `(${d.slice(0, 3)}) ${d.slice(3, 6)}-${d.slice(6)}`
    else if (d.length > 3) out = `(${d.slice(0, 3)}) ${d.slice(3)}`
    else if (d.length > 0) out = `(${d}`
    el.value = out
  })
})
document.querySelectorAll('input[data-format="url"]').forEach((el) => {
  el.addEventListener("blur", () => {
    const v = el.value.trim()
    if (v && !/^https?:\/\//i.test(v)) el.value = "https://" + v
  })
})
