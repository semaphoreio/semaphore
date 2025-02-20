import { MemoryCookie } from "../../memory_cookie"
import { State } from "../state"

import $ from "jquery"

export class LiveSettings {
  constructor(logs, selector) {
    this.logs = logs
    this.selector = selector

    this.handleLiveClick()
  }

  handleLiveClick() {
    let selector = `${this.selector} [data-action=toggleLive]`

    this.logs.on("click", selector, (e) => {
      if (State.get('live')) {
        MemoryCookie.set('logLive', false)
        State.set('live', false)
      } else {
        MemoryCookie.set('logLive', true)
        State.set('live', true)
      }
    })
  }

  update() {
    let live = document.querySelector(`${this.selector} [data-action=toggleLive]`)
    if(live == null) { return }

    if(State.get('live')) {
      live.classList.remove("bg-gray", "hover-bg-red")
      live.classList.add("bg-red", "hover-bg-gray")
      live.innerText = "Live ON"
    } else {
      live.classList.add("bg-gray", "hover-bg-red")
      live.classList.remove("bg-red", "hover-bg-gray")
      live.innerText = "Live OFF"
    }

    // let spinner = document.querySelector(`${this.selector} #job-log-fetching`)

    // if(State.get('fetching') == 'in_progress') {
    //   spinner.classList.remove('dn')
    // } else {
    //   spinner.classList.add('dn')
    // }
  }
}
