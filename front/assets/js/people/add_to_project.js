require('domurl')

import { QueryList } from "../query_list"
import { Props } from "../props"
import Url from "domurl";
import toggleSpinner from "./spinner";
import reRenderPage from "./render_response_html";
import { App } from "../app";

export var AddToProject = {
  init: function() {
    this.initPopupModal()
    this.initRoleSelectionListeners()
    this.initAddMembersListener()
    this.selectedUserIds = []
  },

  initPopupModal() {
    var modal = document.getElementById("modal_overlay");

    if(modal){
      var addPeopleToProjectBtn = document.getElementById("add_people_to_project");
      var addGroupsToProjectBtn = document.getElementById("add_group_to_project");
      var addServiceAccountsToProjectBtn = document.getElementById("add_service_accounts_to_project");
      var cancelModalBtn = document.getElementById("cancel_btn");

      if(addPeopleToProjectBtn){
        addPeopleToProjectBtn.onclick = () => {
          modal.style.display = "block";
          this.initProjectNonMembersFilter("user")
        }
      }

      if(addGroupsToProjectBtn){
        addGroupsToProjectBtn.onclick = () => {
          modal.style.display = "block";
          this.initProjectNonMembersFilter("group")
        }
      }

      if(addServiceAccountsToProjectBtn){
        addServiceAccountsToProjectBtn.onclick = () => {
          modal.style.display = "block";
          this.initProjectNonMembersFilter("service_account")
        }
      }

      cancelModalBtn.onclick = () => {
        this.selectedUserIds = []
        document.getElementById('users').innerHTML = ''

         // Removing all listeners from 'add members' field
        const autocompleteInput = document.querySelector(".project-jumpto")
        const newautocompleteInput = autocompleteInput.cloneNode(true)
        autocompleteInput.parentNode.replaceChild(newautocompleteInput, autocompleteInput)

        modal.style.display = "none"
      }
    }
  },

  initRoleSelectionListeners() {
    const roleDivs = document.getElementsByName("role_div")
    if(roleDivs){
      roleDivs.forEach(elem => {
        elem.addEventListener("click", () => this.roleSelectionChanged(elem))
      })
    }
  },

  roleSelectionChanged(seletedRoleDiv) {
    const popupWindow = document.getElementById("modal_overlay")

    const previouslySelectedRole = popupWindow.querySelector(".selected")
    previouslySelectedRole.className = "not-selected"
    // Removing the tick mark
    previouslySelectedRole.querySelector(".material-symbols-outlined").innerHTML = "&nbsp;"

    seletedRoleDiv.className="selected"
    // Adding the tick mark
    seletedRoleDiv.querySelector(".material-symbols-outlined").innerHTML = "done"

    document.querySelector("[selected-role-id]").setAttribute("selected-role-id", seletedRoleDiv.id);
  },

  initAddMembersListener() {
    var addMembersBtn = document.getElementById("add_members_btn");

    if(addMembersBtn){
      addMembersBtn.addEventListener("click", () => this.sendParallelAssignRoleRequests())
    }
  },

  sendParallelAssignRoleRequests() {
    const assignRoleUrl = new Url(InjectedDataByBackend.AssignRoleUrl)
    const csrf = document.getElementsByName('csrf-token')[0]['content']
    const project_id = InjectedDataByBackend.ProjectId
    const role_id = document.querySelector("[selected-role-id]")?.getAttribute("selected-role-id") || ""

    toggleSpinner()
    Promise.all(this.selectedUserIds.map(userId => {
      const body = {
        user_id: userId,
        project_id: project_id,
        role_id: role_id
      }

      return fetch(assignRoleUrl, {
        method: 'POST',
        body: JSON.stringify(body),
        headers: {
        "Content-Type": "application/json",
        "X-CSRF-TOKEN": csrf
        },
        redirect: 'manual'
      })
    }))
    .then(() => fetch("/projects/"+project_id+"/people", {
      method: 'GET'
    }))
    .then((response) => response.text())
    .then((html) => {
      reRenderPage(html)
      App.run()
      App["people_page"]()
    })
    .catch(e =>{
      toggleSpinner()
      console.error("Error while adding members to the project: " + e)
      Notice.error("An error occurred while adding members to the project. Please check console for any logs and contact our support team.")
    })
  },

  initProjectNonMembersFilter(user_type) {
    if(document.querySelector(".project-jumpto")) {
      let list = new QueryList(".project-jumpto", {
        dataUrl: InjectedDataByBackend.FetchNonMembersUrl + "?type=" + user_type,
        handleSubmit: (selectedUser) => {
          this.addUser(selectedUser)
          this.clearUserAutocompleteInput()
        },
        mapResults: function(results, selectedIndex) {
          return results.map((result, index) => {
          const props = new Props(index, selectedIndex, "autocomplete")
          let assets_path = document.querySelector("meta[name='assets-path']").getAttribute("content")

          return `<span ${props}>
            ${result.subject_type === "service_account"
              ? `<div class="dib w2 h2 br-100 mr2 ba b--black-50 tc bg-light-gray"><span class="material-symbols-outlined f6 gray" style="line-height: 2;">smart_toy</span></div>`
              : result.has_avatar
                ? `<img src="${result.avatar}" class="ba b--black-50 br-100 mr2" width="32">`
                : `<img src="${assets_path}/images/org-${result.name.charAt(0).toLowerCase()}.svg" class="bg-washed-gray w2 h2 br-100 mr2 ba b--black-50"></div>`
            }
            <span>${escapeHtml(result.name)}</span>
            </span>`
          }).join("")
        }
      })

      list.getResultValue = function(result) {return result.name}
    }
  },

  addUser(selectedUser) {
    if(!this.selectedUserIds.includes(selectedUser.id)){
      this.selectedUserIds.push(selectedUser.id)
      this.renderNewUser(selectedUser)

      document.getElementById("add_members_btn").disabled = false
    }
  },

  removeUser(userId) {
    this.selectedUserIds = this.selectedUserIds.filter(id => id != userId)
    const divToRemove = document.getElementById(userId);
    if (divToRemove) {
      divToRemove.remove();
    }

    if(this.selectedUserIds == []) {
      document.getElementById("add_members_btn").disabled = true
    }
  },

  renderNewUser(user) {
    const usersList = document.getElementById('users');
    let assets_path = document.querySelector("meta[name='assets-path']").getAttribute("content")

    newUserDiv=
    `
    <div id="${user.id}" class="flex items-center justify-between bg-white shadow-1 mv1 mh1 ph3 pv2 br3">
      <div class="flex items-center">
        ${user.subject_type === "service_account"
          ? `<div class="w2 h2 br-100 mr2 ba b--black-50 flex items-center justify-center bg-light-gray"><span class="material-symbols-outlined f6 gray">smart_toy</span></div>`
          : user.has_avatar
            ? `<img src="${user.avatar}" class="w2 h2 br-100 mr2 ba b--black-50">`
            : `<img src="${assets_path}/images/org-${user.name.charAt(0).toLowerCase()}.svg" class="bg-washed-gray w2 h2 br-100 mr2 ba b--black-50">`
        }
        <div class="flex items-center">
          <div class="b">${escapeHtml(user.name)}</div>
          ${user.github_login ? `<div class="ml2 f6 gray">@${user.github_login}</div>` : `` }
        </div>
      </div>
      <button class="btn btn-secondary">×</button>
    </div>
    `
    usersList.insertAdjacentHTML('afterbegin', newUserDiv);
    const removeUserBtn = document.getElementById(user.id);
    removeUserBtn.onclick = () => this.removeUser(user.id)
  },

  clearUserAutocompleteInput() {
    const listRoot = document.querySelector(".project-jumpto")
    listRoot.querySelector('input[type=hidden]').value=''
    listRoot.querySelector('input[type=text]').value=''
    listRoot.querySelector('input[type=text]').blur()
    listRoot.querySelector('input[type=text]').focus()
  }
}
