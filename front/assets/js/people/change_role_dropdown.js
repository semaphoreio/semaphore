require('domurl')

import Url from "domurl";
import reRenderPage from "./render_response_html";
import toggleSpinner from "./spinner";
import { App } from "../app";

export var ChangeRoleDropdown = {
  init: function() {
    this.registerTippyChangeRoleDropdowns()
    this.registerRoleChangeListeners()
  },

  registerTippyChangeRoleDropdowns() {
    const changeRoleBtns = document.getElementsByName("change_role_btn")
    if(changeRoleBtns){
      changeRoleBtns.forEach(elem => this.registerTippyChangeRoleDropdown(elem))
    }
  },

  registerTippyChangeRoleDropdown(elem) {
    const dropdown=document.querySelector('#role_selector_'+elem.attributes.member_id.value)

    tippy('#' + elem.id, {
      content: dropdown,
      popperOptions: { strategy: 'fixed' },
      allowHTML: true,
      trigger: 'click',
      theme: 'dropdown',
      interactive: true,
      placement: 'bottom-end',
      duration: [100, 50],
      maxWidth: '640px',
      onShow: (instance) => {
        instance.popper.addEventListener('click', () => {
          // Hide the tooltip
          instance.hide();
        });
       },
    })

    dropdown.className=""
    elem.addEventListener("click", () => this.registerRoleChangeListeners())
  },

  registerRoleChangeListeners() {
    const roleButtons = document.getElementsByName("role_button")
    if(roleButtons){
      roleButtons.forEach(elem => {
        if ((elem.classList.contains("not-selected") || elem.classList.contains("can-be-retracted")) && !elem.hasOnClickListener) {
          elem.hasOnClickListener=true
          elem.addEventListener("click", () => this.roleChanged(elem))
        }
      })
    }
  },

  roleChanged(roleBtn) {
    var url
    if(roleBtn.classList.contains("not-selected")){
      url = new Url(InjectedDataByBackend.AssignRoleUrl)
    }else{
      url = new Url(InjectedDataByBackend.RetractRoleUrl)
    }

    const csrf = document.getElementsByName('csrf-token')[0]['content']
    const body = {
      user_id: roleBtn.attributes.user_id.value,
      project_id: InjectedDataByBackend.ProjectId,
      role_id: roleBtn.attributes.role_id.value,
      member_type: roleBtn.attributes.member_type.value
    }

    toggleSpinner()
    fetch(url, {
      method: 'POST',
      body: JSON.stringify(body),
      headers: {
      "Content-Type": "application/json",
      "X-CSRF-TOKEN": csrf
      }
    })
    .then((response) => {
      return response.text();
    })
    .then((html) => {
      reRenderPage(html)
      App.run()
      App["people_page"]()
    })
    .catch((error) => {
      console.log(error)
      toggleSpinner()
      Notice.error("An error occurred while changing the role. Please contact our support team.")
    })
  }
}
