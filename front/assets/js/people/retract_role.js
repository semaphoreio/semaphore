require('domurl')

import Url from "domurl";
import reRenderPage from "./render_response_html";
import toggleSpinner from "./spinner";
import { App } from "../app";

export var RetractRole = {
  init: function () {
    this.registerRemoveListeners()
  },

  registerRemoveListeners() {
    const removePeopleBtns = document.getElementsByName("remove-btn")
    removePeopleBtns.forEach(elem => {
      elem.addEventListener("click", () => this.retractRole(elem))
    })
  },

  retractRole(removePeopleBtn) {
    if (!this.confirmRemoval(InjectedDataByBackend.ProjectId)){
      return
    }

    const retractRoleUrl = new Url(InjectedDataByBackend.RetractRoleUrl)
    const csrf = document.getElementsByName('csrf-token')[0]['content']
    const body = {
      user_id: removePeopleBtn.attributes.user_id.value,
      project_id: InjectedDataByBackend.ProjectId,
    }

    toggleSpinner()
    fetch(retractRoleUrl, {
      method: 'POST',
      body: JSON.stringify(body),
      headers: {
      "Content-Type": "application/json",
      "X-CSRF-TOKEN": csrf
      }
    })
    .then((response)=>response.text())
    .then((html) => {
      reRenderPage(html)
      App.run()
      App["people_page"]()
    })
    .catch((error) => {
      console.log(error)
      toggleSpinner()
      Notice.error("An error occurred while removing a member, please contact our customer support.")
    })
  },

  confirmRemoval(project_id) {
    if(project_id){
      return confirm("Are you sure you want to remove the user from the project?")
    }else{
      return confirm("Are you sure you want to remove the user from your organization?")
    }
  },
}
