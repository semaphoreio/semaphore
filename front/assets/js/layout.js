import $ from "jquery";

//
// Utilities for handling the layout of the page.
//

class MaxHeight {
  //
  // Makes sure that a given panel takes up all the
  // vertical space available to it.
  //
  // On every window resize, the layout is recalculated.
  //
  // The layout makes sure that the height is maintained during
  // window resizes.
  //
  // If the element's visibility is toggled, your must call
  // the update() function manually.
  //
  // Example:
  //
  //   let layout = new Layout.MaxHeight("#sidebar")
  //
  //   $("#sidebar").on("click", "[data-action=show]", () => {
  //     $("#sidebar").show()
  //
  //     // Must be called every time the visibility changes.
  //     layout.update()
  //   })
  //
  constructor(panelSelector, bottom = 0, min = 0) {
    this.panelSelector = panelSelector
    this.element = $(this.panelSelector)
    this.bottom = bottom
    this.min = min

    this.update()

    // update sizes on window size change
    $(window).on("resize", this.update.bind(this))
  }

  update() {
    //
    // Initial set up of the element.
    //
    // The browser needs a bit time to calculate the sizes correctly.
    // We give it 50ms.
    //
    setTimeout(() => {
      let height = $(window).height() - this.element.offset().top - this.bottom
      height = Math.max(...[this.min,height])

      this.element.css({"height": height + "px"})
    }, 50)
  }
}

export var Layout = {
  MaxHeight: MaxHeight
}
