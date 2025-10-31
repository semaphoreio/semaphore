import { Cookie } from "./cookie"

export class MemoryCookie {
  static set(key, value) {
    let values = this.getAll()
    values[key] = value

    values = JSON.stringify(values)
    values = window.btoa(values)

    Cookie.setPermanent('memory', values, false)
  }

  static get(key) {
    let values = this.getAll()

    return values[key]
  }

  static getAll() {
    let values = Cookie.get('memory')

    if(values == null) {
      values = {}
    } else {
      values = window.atob(values)
      values = JSON.parse(values)
    }

    let defaults = {
      rootSidebar: false,
      rootRequester: true,
      projectType: "",
      projectListing: "all_pipelines",
      projectRequester: "false",
      logDark: false,
      logWrap: true,
      logLive: true,
      logSticky: true,
      logTimestamps: true
    };

    return Object.assign(defaults, values || {});
  }
}
