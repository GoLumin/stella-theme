// src/components/Header.astro: the mobile menu, the bar's shadow once the
// page scrolls, and the mega menus (hover, focus, Escape).
const header = document.getElementById("site-header")
const burger = header?.querySelector(".v2h-burger")
const mobile = document.getElementById("site-mobile")

if (header && burger && mobile) {
  burger.addEventListener("click", () => {
    const open = burger.getAttribute("aria-expanded") === "true"
    burger.setAttribute("aria-expanded", String(!open))
    mobile.hidden = open
    document.body.style.overflow = open ? "" : "hidden"
  })
  mobile.querySelectorAll("a").forEach((a) =>
    a.addEventListener("click", () => {
      burger.setAttribute("aria-expanded", "false")
      mobile.hidden = true
      document.body.style.overflow = ""
    })
  )

  const onScroll = () => header.classList.toggle("scrolled", window.scrollY > 8)
  onScroll()
  window.addEventListener("scroll", onScroll, { passive: true })

  header.querySelectorAll(".v2h-item.has-mega").forEach((item) => {
    const link = item.querySelector(".v2h-link")
    const close = () => { item.classList.remove("open"); link.setAttribute("aria-expanded", "false") }
    const open = () => { item.classList.add("open"); link.setAttribute("aria-expanded", "true") }
    item.addEventListener("mouseenter", open)
    item.addEventListener("mouseleave", close)
    item.addEventListener("focusin", open)
    item.addEventListener("focusout", (e) => { if (!item.contains(e.relatedTarget)) close() })
    item.addEventListener("keydown", (e) => {
      if (e.key === "Escape") { close(); link.focus() }
    })
  })
}
