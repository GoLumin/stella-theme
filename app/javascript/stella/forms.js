// src/scripts/cms-forms.ts: every form[data-cms-form] posts to the Forms
// plugin's public endpoint (its action) without leaving the page. Its
// data-success is the form's thank-you, so with JavaScript off it still
// posts somewhere real. The honeypot (data-honeypot, the Forms plugin's
// field) is one people never see; anything in it means a bot, and the CMS
// accepts and silently drops those.
const GENERIC_ERROR = "Something went wrong sending that. Please try again, or call us if it keeps happening."

function showMessage(form, kind, text) {
  let note = form.querySelector(".form-msg")
  if (!note) {
    note = document.createElement("p")
    note.className = "form-msg"
    note.setAttribute("role", kind === "error" ? "alert" : "status")
    form.appendChild(note)
  }
  note.dataset.kind = kind
  note.textContent = text
  note.scrollIntoView({ behavior: "smooth", block: "nearest" })
}

function clearFieldErrors(form) {
  form.querySelectorAll("[aria-invalid]").forEach((el) => el.removeAttribute("aria-invalid"))
}

function markFieldErrors(form, errors) {
  if (!errors || typeof errors !== "object") return false
  let first = null
  for (const name of Object.keys(errors)) {
    const el = form.elements.namedItem(name)
    if (el instanceof HTMLElement) {
      el.setAttribute("aria-invalid", "true")
      first ??= el
    }
  }
  first?.focus()
  return first !== null
}

async function submit(form, button) {
  const honeypot = form.dataset.honeypot || "_hp"
  const values = { [honeypot]: "" }
  new FormData(form).forEach((v, k) => {
    if (typeof v === "string" && v.trim() !== "") values[k] = v.trim()
  })

  let res
  try {
    res = await fetch(form.action, {
      method: "POST",
      headers: { "Content-Type": "application/json", Accept: "application/json" },
      body: JSON.stringify(values),
    })
  } catch {
    showMessage(form, "error", "We couldn't reach the server. Check your connection and try again.")
    return
  }

  const body = await res.json().catch(() => null)

  if (res.ok) {
    form.reset()
    form.dataset.sent = ""
    if (button) button.disabled = true
    showMessage(form, "ok", body?.success_message || form.dataset.success || "Thanks — it's in.")
    return
  }

  if (res.status === 422 && markFieldErrors(form, body?.errors)) {
    showMessage(form, "error", "Please check the highlighted fields and try again.")
  } else if (res.status === 429 || body?.error === "rate_limited") {
    showMessage(form, "error", "Too many submissions from this network. Please wait a few minutes and try again.")
  } else if (body?.error === "captcha_failed") {
    showMessage(form, "error", "The spam check didn't go through. Please wait a moment and send it again.")
  } else {
    showMessage(form, "error", GENERIC_ERROR)
  }
}

document.querySelectorAll("form[data-cms-form]").forEach((form) => {
  // People never see this field; a bot filling every input will.
  const hp = document.createElement("input")
  hp.type = "text"
  hp.name = form.dataset.honeypot || "_hp"
  hp.tabIndex = -1
  hp.autocomplete = "off"
  hp.setAttribute("aria-hidden", "true")
  hp.style.cssText = "position:absolute;left:-10000px;width:1px;height:1px;opacity:0;"
  form.appendChild(hp)

  form.addEventListener("submit", async (e) => {
    e.preventDefault()
    if ("sent" in form.dataset) return
    clearFieldErrors(form)
    // Some forms set novalidate to style their own states; validate anyway.
    if (!form.reportValidity()) return

    const button = form.querySelector('button[type="submit"]')
    if (button) button.disabled = true
    form.setAttribute("aria-busy", "true")
    try {
      await submit(form, button)
    } finally {
      form.removeAttribute("aria-busy")
      if (button && !("sent" in form.dataset)) button.disabled = false
      // A Turnstile token is good once: the next try needs a fresh one.
      const widget = form.querySelector(".cf-turnstile")
      if (widget) window.turnstile?.reset(widget)
    }
  })
})
