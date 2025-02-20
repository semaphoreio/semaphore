import { MemoryCookie } from "../../memory_cookie"
import $ from "jquery"

export class Requester {
  constructor(me, selector) {
    this.me = me
    this.selector = selector

    this.handleToogleClick()
  }

  handleToogleClick() {
    let selector = `${this.selector} a`
    let strong = $(`${this.selector} strong`)

    this.me.on("click", selector, (e) => {
      if (e.target.innerText == "Show everyone's") {
        e.target.innerText = "Show mine"
        strong.text("Everyone's latest work")

        MemoryCookie.set('rootRequester', false)

        Pollman.stop();

        let pollman = document.querySelector('.pollman-container')

        pollman.setAttribute("data-poll-param-requester", "false")

        Pollman.fetchAndReplace(pollman);

        Pollman.start();
      } else {
        e.target.innerText = "Show everyone's"
        strong.text("My latest work")
        MemoryCookie.set('rootRequester', true)

        Pollman.stop();

        let pollman = document.querySelector('.pollman-container')

        pollman.setAttribute("data-poll-param-requester", "true")

        Pollman.fetchAndReplace(pollman);

        Pollman.start();
      }

      e.preventDefault()
    })
  }
}
