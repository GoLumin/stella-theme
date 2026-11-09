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

  // .past-hero: the first block (the hero) has scrolled up under the bar, so
  // on small screens the bar swaps Login for Book a demo. A page with no hero
  // swaps as soon as it scrolls.
  const hero = document.querySelector("main > :first-child")
  const onScroll = () => {
    header.classList.toggle("scrolled", window.scrollY > 8)
    const past = hero
      ? hero.getBoundingClientRect().bottom <= header.getBoundingClientRect().bottom
      : window.scrollY > 8
    header.classList.toggle("past-hero", past)
  }
  onScroll()
  window.addEventListener("scroll", onScroll, { passive: true })
  window.addEventListener("resize", onScroll, { passive: true })

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
