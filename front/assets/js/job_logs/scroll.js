export var Scroll = {
  top: (container) => {
    container.scrollTop = 0
  },

  bottom: (container) => {
    container.scrollTop = container.scrollHeight
  },

  to: (container, element) => {
    const containerPosition = container.getBoundingClientRect()
    const elementPosition = element.getBoundingClientRect()

    if (elementPosition.top < containerPosition.top) {
      // Element is above viewable area
      container.scrollTop -= containerPosition.top - elementPosition.top
    } else if (elementPosition.bottom > containerPosition.bottom) {
      // Element is below viewable area
      container.scrollTop += elementPosition.bottom - containerPosition.bottom
    }
  }
}
