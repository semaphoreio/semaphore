import $ from "jquery"

import { Tippy } from "../tippy"

import { Component } from "./component"
import { Template } from "./template"
import { Model } from "./model"

export class JumpTo {
  static init() {
    let config = {
      starred: window.InjectedDataByBackend.JumpTo.Starred,
      projects: InjectedDataByBackend.JumpTo.Projects,
      dashboards: InjectedDataByBackend.JumpTo.Dashboards
    }

    return new JumpTo(config)
  }

  constructor(config) {
    this.config = config

    this.setUpModelComponentEventLoop()

    this.tippy = Tippy.defaultDropdown('.js-projects-menu-trigger', 'bottom-start')[0]
  }

  setUpModelComponentEventLoop() {
    this.model = new Model(this.config.starred, this.config.projects, this.config.dashboards)

    let divs = {
      results: "#jump-to-results",
      input: "#jump-to-input"
    }
    this.component = new Component(this, divs.results, divs.input, this.model)

    this.model.onUpdate(this.update.bind(this))

    this.update();
  }

  update() {
    this.component.update()
  }

  hideTippy() {
    this.tippy.hide()
  }

  on(event, selector, callback, options) {
    options = options || {}

    //
    // Use case for afterUserEvents:
    //
    // 1. You modified an input field in the config panel
    // 2. When you click on some other field two events are activated:
    //
    //   - the 'change' event on the input field
    //   - the 'click' event on the other event
    //
    // 3. If we trigger a refresh of the UI from the 'change' event, the element
    //    that is clicked suddenly no longer exists. A new click is necessary.
    //
    // To avoid this problem, we can register an event to be only triggered when
    // the user finishes with the 'click' event.
    //

    let afterUserEvents = !!options.afterUserEvents

    console.log(`Registering event: '${event}', target: '${selector}'. AfterUserEvents: ${afterUserEvents}`)

    let handler = (e) => {
      console.log(`Event for '${event}' on ${selector} started`)
      let result = callback(e)
      console.log(`Event for '${event}' on ${selector} finished`)

      return result
    }

    let delayedHandler = (e) => {
      if(_isMouseDown) {
        setTimeout(() => delayedHandler(e), 30)
      } else {
        handler(e)
      }
    }

    $("body").on(event, selector, (e) => {
      if(afterUserEvents) {
        return delayedHandler(e)
      } else {
        return handler(e)
      }
    })
  }
}
