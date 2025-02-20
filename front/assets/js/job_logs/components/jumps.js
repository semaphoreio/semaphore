import { Scroll } from "../scroll"

export class Jumps {
  constructor(logs, jumpSelector, logContainerSelector) {
    this.logs = logs
    this.selector = jumpSelector
    this.logContainerSelector = logContainerSelector

    this.handleJumpTopClick()
    this.handleJumpBottomClick()
  }

  handleJumpTopClick() {
    let selector = `${this.selector} [data-action=jumpTop]`
    let container = document.querySelector(this.logContainerSelector)

    this.logs.on("click", selector, (e) => {
      Scroll.top(container)
      e.preventDefault()
    })
  }

  handleJumpBottomClick() {
    let selector = `${this.selector} [data-action=jumpBottom]`
    let container = document.querySelector(this.logContainerSelector)

    this.logs.on("click", selector, (e) => {
      Scroll.bottom(container)
      e.preventDefault()
    })
  }

  update() {}
}
