require('domurl')

import { QueryList } from "../query_list"
import { Props } from "../props"
import toggleSpinner from "../people/spinner";
import reRenderPage from "../people/render_response_html";
import { App } from "../app";

export var GroupManagement = {
  init: function() {
    this.modal = document.getElementById("groups_modal_overlay")

    this.group = null
    this.memberIdsToAdd = []
    this.memberIdsToRemove = []

    this.initPopupModal()
    this.initModifyGroupListeners()
  },

  initPopupModal() {
    if(this.modal){
      var createGroupBtn = document.getElementById("open_group_popup");
      createGroupBtn.addEventListener("click", () => this.openGroupsPopup(null))
      var cancelModalBtn = document.getElementById("cancel_btn");
      cancelModalBtn.addEventListener("click", () => this.closeGroupPopup())
      var saveChangesBtn = document.getElementById("save_changes_btn");
      saveChangesBtn.addEventListener("click", () => this.saveChanges())
      
      const nameInput = document.getElementById("name_input");
      nameInput.addEventListener("input", () => this.refreshSaveChangesBtnState())
      const descriptionInput = document.getElementById("description_input");
      descriptionInput.addEventListener("input", () => this.refreshSaveChangesBtnState())
    }
  },

  initModifyGroupListeners() {
    const modifyGroupBtns = document.getElementsByName("modify-group-btn")
    modifyGroupBtns.forEach(elem => {
      elem.addEventListener("click", () => this.openGroupsPopup(elem))
    })
  },

  async openGroupsPopup(modifyGroupBtn) {
    toggleSpinner()

    if(modifyGroupBtn != null) {
      groupId = modifyGroupBtn.attributes.group_id.value
      await this.fetchGroup(groupId)
    }

    this.initGroupNonMembersFilter()
    this.modal.style.display = "block";

    toggleSpinner()
  },

  closeGroupPopup() {
    this.group = null
    this.memberIdsToAdd = []
    this.memberIdsToRemove = []

    this.clearUserAutocompleteInput()
    document.getElementById("group-users").innerHTML = '';
    document.getElementById("name_input").value = '';
    document.getElementById("description_input").value = '';

    // Removing all listeners from 'add members' field
    const autocompleteInput = document.querySelector(".group-members-jumpto");
    const newautocompleteInput = autocompleteInput.cloneNode(true);
    autocompleteInput.parentNode.replaceChild(newautocompleteInput, autocompleteInput);

    this.modal.style.display = "none"
  },

  async fetchGroup(groupId) {
    const dataUrl="groups/" + groupId
    const csrf = document.getElementsByName('csrf-token')[0]['content']

    return fetch(dataUrl, {
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-TOKEN": csrf
      }})
      .then(response => response.json())
      .then(group => {
        this.group = group
        document.getElementById("name_input").value = group.name
        document.getElementById("description_input").value = group.description
        group.members.forEach(member => this.renderNewUser(member))
      })
      .catch(error => {
        console.error("Error while fetching group members: " + error)
        Notice.error("An error occurred while fetching group members. " +
          "If this issue persists, please check console for any logs and contact our support team.")
      })
  },

  saveChanges(){
    if(this.group){
      this.sendModifyGroupRequests()
    }else{
      this.sendCreateGroupRequest()
    }
  },

  sendModifyGroupRequests() {
    const csrf = document.getElementsByName('csrf-token')[0]['content']
    toggleSpinner()

    const modifyGroupsUrl="groups/" + this.group.id

    fetch(modifyGroupsUrl, {
      method: 'PUT',
      body: JSON.stringify({
        name: document.getElementById("name_input").value,
        description: document.getElementById("description_input").value,
        members_to_add: this.memberIdsToAdd,
        members_to_remove: this.memberIdsToRemove
      }),
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-TOKEN": csrf
      },
      redirect: 'manual'
    })
    .then(_ => fetch("people", {
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
      console.error("Error while adding members to the the group: " + e)
      Notice.error("An error occurred while adding members to the group. Please check console for any logs and contact our support team.")
    })
  },

  sendCreateGroupRequest() {
    const csrf = document.getElementsByName('csrf-token')[0]['content']
    const createGroupUrl = "groups"

    const name = document.getElementById("name_input").value;
    const description = document.getElementById("description_input").value;

    fetch(createGroupUrl, {
      method: 'POST',
      body: JSON.stringify({name: name, description: description, member_ids: this.memberIdsToAdd}),
      headers: {
        "Content-Type": "application/json",
          "X-CSRF-TOKEN": csrf
      },
      redirect: 'manual'
    })
    .then(_ => fetch("people", {
      method: 'GET'
    }))
    .then((response) => {
      return response.text();
    })
    .then((html) => {
      reRenderPage(html)
      App.run()
      App["people_page"]()
    })
    .catch(e =>{
      console.error("Error while creating a group: " + e)
      Notice.error("An error occurred  while creating a group. Please check console for any logs and contact our support team.")
    })

  },

  initGroupNonMembersFilter() {
    var dataUrl
    if(this.group) {
      dataUrl="groups/" + this.group.id + "/non_members.json"
    } else {
      dataUrl="groups/nil/non_members.json"
    }

    if(document.querySelector(".group-members-jumpto")) {
      let list = new QueryList(".group-members-jumpto", {
        dataUrl: dataUrl,
        handleSubmit: (selectedUser) => {
          this.addUser(selectedUser)
          this.clearUserAutocompleteInput()
        },
        mapResults: (results, selectedIndex) => {
          return results.reduce((acc, result, index) => {
          const props = new Props(index, selectedIndex, "autocomplete")

          if(!this.memberIdsToAdd.includes(result.id)){
            acc.push(
              `<span ${props}>
                ${result.has_avatar
                  ? `<img src="${result.avatar}" class="ba b--black-50 br-100 mr2" width="32">`
                  : `<div class="bg-washed-gray w2 h2 br-100 mr2 ba b--black-50"></div>`
                }
                <span>${escapeHtml(result.name)}</span>
              </span>`
            )
          }
          return acc
          }, []).join("")
        }
      })

      list.getResultValue = function(result) {return result.name}
    }
  },

  addUser(selectedUser) {
    if(this.group == null || !this.group.member_ids.includes(selectedUser.id)){
      this.memberIdsToAdd.push(selectedUser.id)
      this.renderNewUser(selectedUser)

      this.refreshSaveChangesBtnState()
    }
  },

  removeUser(userId) {
    if(this.memberIdsToAdd.includes(userId)){
      this.memberIdsToAdd = this.memberIdsToAdd.filter(id => id != userId)
    }else if(this.group && this.group.member_ids.includes(userId)){
      this.memberIdsToRemove.push(userId)
    }

    const divToRemove = document.getElementById(userId);
    if (divToRemove) {
      divToRemove.remove();
    }

    this.refreshSaveChangesBtnState()
  },

  renderNewUser(user) {
    const usersList = document.getElementById('group-users');

    newUserDiv=
    `
    <div id="${user.id}" class="flex items-center justify-between bg-white shadow-1 mv1 mh1 ph3 pv2 br3">
      <div class="flex items-center">
        ${user.avatar
          ? `<img src="${user.avatar}" class="w2 h2 br-100 mr2 ba b--black-50">`
          : `<div class="bg-washed-gray w2 h2 br-100 mr2 ba b--black-50"></div>`
        }
        <div class="flex items-center">
          <div class="b">${escapeHtml(user.name)}</div>
          ${user.github_login ? `<div class="ml2 f6 gray">@${user.github_login}</div>` : `` }
        </div>
      </div>
      <button name="rmv_btn" class="btn btn-secondary">×</button>
    </div>
    `
    usersList.insertAdjacentHTML('afterbegin', newUserDiv);
    const removeUserBtn = document.getElementById(user.id).querySelector('[name="rmv_btn"]');;
    removeUserBtn.onclick = () => this.removeUser(user.id)
  },

  clearUserAutocompleteInput() {
    const listRoot = document.querySelector(".group-members-jumpto")
    listRoot.querySelector('input[type=hidden]').value=''
    listRoot.querySelector('input[type=text]').value=''
    listRoot.querySelector('input[type=text]').blur()
    listRoot.querySelector('input[type=text]').focus()
  },

  refreshSaveChangesBtnState() {
    if(this.group) {
      document.getElementById("save_changes_btn").disabled = this.areMandatoryFieldsEmpty() || !this.isAnyChangeMade()
    }else{
      document.getElementById("save_changes_btn").disabled = this.areMandatoryFieldsEmpty()
    }
  },

  areMandatoryFieldsEmpty() {
    const name = document.getElementById("name_input").value
    const description = document.getElementById("description_input").value
    return !name || !description
  },

  isAnyChangeMade() {
    let isNameChanged, isDescriptionChanged
    if(this.group) {
      isNameChanged = document.getElementById("name_input").value !== this.group.name
      isDescriptionChanged = document.getElementById("description_input").value !== this.group.description
    }else{
      isNameChanged = document.getElementById("name_input").value !== ''
      isDescriptionChanged = document.getElementById("description_input").value !== ''
    }
    return isNameChanged || isDescriptionChanged || this.memberIdsToAdd.length > 0 || this.memberIdsToRemove.length > 0
  }
}
