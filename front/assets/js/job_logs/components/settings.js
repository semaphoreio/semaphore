import { MemoryCookie } from "../../memory_cookie"
import { State } from "../state"

import $ from "jquery"

export class Settings {
  constructor(logs, selector) {
    this.logs = logs
    this.selector = selector

    this.handleDarkThemeClick()
    this.handleWrapLinesClick()
    this.handleStickyCommandsClick()
    this.handleTimestampsCommandsClick()
  }

  handleDarkThemeClick() {
    let selector = `${this.selector} [data-action=toggleDarkTheme]`

    this.logs.on("click", selector, (e) => {
      if (State.get('dark')) {
        MemoryCookie.set('logDark', false)
        State.set('dark', false)
      } else {
        MemoryCookie.set('logDark', true)
        State.set('dark', true)
      }
    })
  }

  handleWrapLinesClick() {
    let selector = `${this.selector} [data-action=toggleWrapLines]`

    this.logs.on("click", selector, (e) => {
      if (State.get('wrap')) {
        MemoryCookie.set('logWrap', false)
        State.set('wrap', false)
        MemoryCookie.set('logTimestamps', false)
        State.set('timestamps', false)
      } else {
        MemoryCookie.set('logWrap', true)
        State.set('wrap', true)
      }
    })
  }

  handleStickyCommandsClick() {
    let selector = `${this.selector} [data-action=toggleStickyCommands]`

    this.logs.on("click", selector, (e) => {
      if (State.get('sticky')) {
        MemoryCookie.set('logSticky', false)
        State.set('sticky', false)
      } else {
        MemoryCookie.set('logSticky', true)
        State.set('sticky', true)
      }
    })
  }

  handleTimestampsCommandsClick() {
    let selector = `${this.selector} [data-action=toggleTimestampsCommands]`

    this.logs.on("click", selector, (e) => {
      if (State.get('timestamps')) {
        MemoryCookie.set('logTimestamps', false)
        State.set('timestamps', false)
      } else {
        MemoryCookie.set('logTimestamps', true)
        State.set('timestamps', true)
        MemoryCookie.set('logWrap', true)
        State.set('wrap', true)
      }
    })
  }

  update() {
    this.updateOne("toggleDarkTheme", "dark");
    this.updateOne("toggleWrapLines", "wrap");
    this.updateOne("toggleStickyCommands", "sticky");
    this.updateOne("toggleTimestampsCommands", "timestamps");
  }

  updateOne(action, state) {
    document.querySelectorAll(`${this.selector} [data-action=${action}]`).forEach((node) => {
      node.checked = State.get(state)
    })
  }
}
