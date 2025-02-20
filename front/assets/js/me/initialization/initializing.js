import $ from "jquery"

export class AccountInitializingScreen {
  static run() {
    let userId = window.InjectedDataByBackend.UserId
    let orgId = window.InjectedDataByBackend.OrgId
    let checkURL = window.InjectedDataByBackend.CheckURL
    let nextScreen = window.InjectedDataByBackend.NextScreen

    let initializer = new AccountInitializingScreen(userId, orgId, checkURL, nextScreen)
    initializer.update()
  }

  constructor(userId, orgId, checkURL, nextScreen) {
    this.spinnerHtmlSelector = "#spinners"

    this.userId=userId
    this.orgId=orgId
    this.checkURL=checkURL
    this.nextScreen=nextScreen
  }

  update() {
    this.render()

    fetch(this.checkURL + "?" + new URLSearchParams({
      user_id: this.userId,
      org_id: this.orgId,
    }))
    .then((response) => { return response.json() })
    .then((data)=> {
      if(data.permissions_setup) {
        this.redirectAfterSetup()
      } else {
        setTimeout(() => this.update(), 2000)
      }
    })
  }

  render() {
    let html = Spinner.render(this.initialized)
    $(this.spinnerHtmlSelector).html(html)
  }

  redirectAfterSetup() {
    //
    // If the screen transitions immiditaly it looks broken.
    //
    setTimeout(() => { window.location = this.nextScreen }, 2000)
  }
}

class Spinner {
  static render(initialized){
    return `
      <div>
        <ul style="list-style: none; padding: 0;">
        ${this.spinnerMessage(initialized)}
      </div>
    `
  }

  static spinnerMessage(initialized) {
    let assetsPath = $("meta[name='assets-path']").attr("content")
    let style = "vertical-align: bottom;"
    let msg = "Setting up permissions"

    let sign = ""
    if(initialized) {
      sign = `<span class="green" style="${style}; padding-right: 12px; padding-left: 3px;">✓</span>`
    } else {
      sign = `<img style="${style}; padding-right: 9px;" src="${assetsPath}/images/spinner-2.svg">`
    }

    return `<li>${sign}<span>${msg}</span></li>`
  }
}