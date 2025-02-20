import $ from "jquery"

import { State } from "./initializing/state"
import { Template } from "./initializing/template"
import { Notice } from "../notice"

//
// The InitializingScreen is a poll-and-wait JS application
// that polls the project state and displays the information about the progress
// to the user.
//
// A project has multiple deps that need to be created before the user can
// continue to the next screen. These are:
//
//  - connection to github
//  - connection to artifacts
//  - connection to cache
//  - analysis of a project
//
// Depending on the state of the above, the page displays either a spinner or
// a green checkmark to the customer.
//
// When the waiting is done (i.e. project.state == "ready"), we redirect the
// customer to the "next_screen_url" provided by the backend. Usually, this is
// the template picker screen.
//

export class InitializingScreen {
  static run() {
    let checkURL = window.InjectedDataByBackend.CheckURL

    let s = new InitializingScreen(checkURL)
    s.update()
  }

  constructor(checkURL) {
    this.outputSelector = "#project-onboarding-initializing-message"
    this.checkURL = checkURL

    this.state = new State()
    this.poll = true
  }

  update() {
    this.render()

    fetch(this.checkURL)
    .then((response) => { return response.json() })
    .then((data) => {
      this.state.update(data)

      if(this.state.ready) {
        this.handleProjectIsReadyEvent(data["next_screen_url"])
      } else if(this.state.errorMessage != "") {
        this.handleErrorEvent(this.state.errorMessage)
      } else {
        this.render()
      }
    }).finally(() => {
      if(this.poll) {
        setTimeout(() => this.update(), 3000)
      }
    })
  }

  handleErrorEvent(message) {
    this.poll = false
    this.render()

    Notice.error(message)
  }

  handleProjectIsReadyEvent(url) {
    this.poll = false // stop polling
    this.render()

    //
    // If the screen transitions immiditaly it looks broken. The waiting was
    // never completed. A 2 second timeout increases the wait time, but decreses
    // the wtf moment.
    //

    setTimeout(() => { window.location = url }, 2000)
  }

  render() {
    let html = Template.render(this.state)

    $(this.outputSelector).html(html)
  }

}
