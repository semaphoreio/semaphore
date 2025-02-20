import $ from "jquery";

import { Requester } from "./components/requester"

export class Me {
  static init() {
    return new Me()
  }

  constructor() {
    let divs = {
      toogleRequester: "#toggleRequester"
    }

    this.components = {
      requester: new Requester(this, divs.toogleRequester)
    }
  }

  on(event, selector, callback) {
    console.log(`Registering event: '${event}', target: '${selector}'`)

    $("body").on(event, selector, (e) => {
      console.log(`Event for '${event}' on ${selector} started`)
      let result = callback(e)
      console.log(`Event for '${event}' on ${selector} finished`)

      return result
    })
  }
}
