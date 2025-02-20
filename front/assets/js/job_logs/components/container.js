import { State } from "../state"

export class Container {
  constructor(logs, selector) {
    this.logs = logs
    this.selector = selector
  }

  update() {
    let container = document.querySelector(this.selector)

    if (State.get('timestamps')) {
      container.classList.add('timestamps')
    } else {
      container.classList.remove('timestamps')
    }

    if (State.get('dark')) {
      container.classList.add('job-log-container--dark')
    } else {
      container.classList.remove('job-log-container--dark')
    }

    if (State.get('wrap')) {
      container.classList.remove('nowrap')
    } else {
      container.classList.add('nowrap')
    }

    if (State.get('sticky')) {
      container.classList.add('sticky-commands')
    } else {
      container.classList.remove('sticky-commands')
    }

    if (["ready", "in_progress", "finished"].includes(State.get("fetching"))) {
      container.querySelector("#job-log").classList.remove("dn")
      container.querySelector("#job-log-failure-message").classList.add("dn")
      container.querySelector("#job-log-pending-message").classList.add("dn")
    }

    if(["dont_start", "failure"].includes(State.get("fetching"))) {
      container.querySelector("#job-log").classList.add("dn")
      container.querySelector("#job-log-failure-message").classList.remove("dn")

      container.querySelector("#job-log-failure-message p").innerText = State.get("failure_msg")
    }

    if(State.get("trimmed_logs")) {
      container.querySelector("#job-log").classList.add("dn")
      container.querySelector("#job-log-info-message").classList.remove("dn")
    }

    if (State.get("state") == "pending") {
      container.querySelector("#job-log").classList.add("dn")
      container.querySelector("#job-log-pending-message").classList.remove("dn")
    }
  }
}
