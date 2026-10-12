// src/pages/blog/index.astro: the category buttons show only that category's
// posts, and say so when there are none.
const grid = document.getElementById("post-grid")
const buttons = grid ? document.querySelectorAll(".filter") : []
const cards = document.querySelectorAll("#post-grid .post")
const empty = document.getElementById("post-empty")

buttons.forEach((btn) => {
  btn.addEventListener("click", () => {
    const want = btn.dataset.filter
    buttons.forEach((b) => b.classList.toggle("is-on", b === btn))

    let shown = 0
    cards.forEach((card) => {
      const match = want === "all" || card.dataset.category === want
      card.hidden = !match
      if (match) shown += 1
    })

    if (empty) empty.hidden = shown > 0
  })
})
