require('domurl')

import debounce from "../debounce";
import Url from "domurl";
import { ChangeRoleDropdown } from "./change_role_dropdown";
import { RetractRole } from "./retract_role";
import toggleSpinner from "./spinner";

export var ListPeople = {
  init: function () {
    this.pageNo = 0
    this.initSearchFilter()
    this.initRoleFilterDropdown()
    this.registerLoadMoreListener()
  },

  initRoleFilterDropdown() {
    const filterByRoleBtn = document.querySelector('#filter_by_role_btn') 

    if(filterByRoleBtn){
      const dropdown=document.querySelector('#roleSelector')

      tippy('#filter_by_role_btn', {
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
      filterByRoleBtn.addEventListener("click", () => this.registerRoleFilterOptions())
    }
  },

  registerRoleFilterOptions() {
    const roleButtons = document.getElementsByName("filter_role_btn")
    if(roleButtons){
      roleButtons.forEach(elem => {
        if(elem.hasOnClickListener){
          return
        }
        elem.hasOnClickListener=true
        elem.addEventListener("click", () => {
          const filterByRoleBtn = document.querySelector('#filter_by_role_btn') 
          const selectedRoleLabel = document.getElementById("selected_role_name")

          if(elem.classList.contains('selected')){
            // Deselect currently selected filter option
            selectedRoleLabel.innerHTML = "Role"
            elem.className = "not-selected"
            elem.querySelector(".material-symbols-outlined").innerHTML = "&nbsp;"
            filterByRoleBtn.setAttribute("selected_role_id", "")
          }else{
            // Deselect currently selected filter option and select the one user just clicked on
            selectedRoleLabel.innerHTML = elem.querySelector('[name="role_name"]').innerHTML

            const previouslySelectedRole = document.querySelector(".selected")
            if(previouslySelectedRole){
              previouslySelectedRole.className = "not-selected"
              previouslySelectedRole.querySelector(".material-symbols-outlined").innerHTML = "&nbsp;"
            }

            elem.className="selected"
            elem.querySelector(".material-symbols-outlined").innerHTML = "done"
            const selectedRoleId = elem.attributes.role_id.value
            filterByRoleBtn.setAttribute("selected_role_id", selectedRoleId)
          }

          this.fetchMembers()
        })
      })
    }
  },

  initSearchFilter() {
    const searchField = document.querySelector("input[name=search_input_field]")
    const throttledInputChange = debounce(()=>this.fetchMembers(), 200)
    if(searchField){
      searchField.addEventListener('input', () => throttledInputChange())
    }
  },

  registerLoadMoreListener() {
    const loadMoreBtn = document.getElementById("load_more_btn")
    if(loadMoreBtn) {
      loadMoreBtn.addEventListener("click", ()=>this.fetchMembers(this.pageNo + 1, false))
    }
  },

  fetchMembers(pageNo = 0, clearExsisting = true) {
    const fetchMembersUrl = new Url(InjectedDataByBackend.RenderMembers)

    const filterByRoleBtn = document.querySelector('#filter_by_role_btn') 
    const roleId = filterByRoleBtn.attributes.selected_role_id.value
    const filterName = document.querySelector("input[name=search_input_field]").value

    fetchMembersUrl.query.name_contains = filterName || ""
    fetchMembersUrl.query.members_with_role = roleId
    fetchMembersUrl.query.page_no = pageNo;
    fetchMembersUrl.query.project_id = InjectedDataByBackend.ProjectId

    toggleSpinner()
    fetch(fetchMembersUrl.toString())
    .then(response => {
      if(!response.ok){
        throw new Error("Error while filtering members")
      }
      this.updatePaginationInfo(response, pageNo)
      return response.text()
    })
    .then(newMembers => {
      this.updateMembersList(newMembers, clearExsisting)
      this.updateGroupsList(newMembers, clearExsisting)
      toggleSpinner()
    })
    .catch((e) => {
      console.error("Error while filtering members: " + e)
      toggleSpinner()
      Notice.error("An error occurred while filtering members. Please contact our support team.")
    })
  },

  updatePaginationInfo(response, pageNo) {
    this.pageNo = pageNo
    this.totalPages = parseInt(response.headers.get('total_pages'))
    const loadMoreBtn = document.getElementById("load_more_btn")
    if(loadMoreBtn) {
      loadMoreBtn.disabled = this.totalPages == pageNo + 1
    }
  },

  updateMembersList(newMembersHtml, clearExisting) {
    const membersList = document.getElementById('members');
    if(clearExisting){ 
      membersList.innerHTML=''
    }
    const template = document.createElement('div');
    template.innerHTML=newMembersHtml;
    const newMembers = template.querySelectorAll('#members > div');

    newMembers.forEach(div => {
      membersList.appendChild(div);
      const change_role_btn=div.querySelector('[name="change_role_btn"]')
      if(change_role_btn){
        ChangeRoleDropdown.registerTippyChangeRoleDropdown(change_role_btn)
      }
      const remove_btn=div.querySelector('[name="remove-btn"]')
      if(remove_btn){
        remove_btn.addEventListener("click", () => RetractRole.retractRole(remove_btn))
      }
   });
  },

  updateGroupsList(newGroupsHtml, clearExisting) {
    const groupsList = document.getElementById('groups');
    if (groupsList == null) return 
    if(clearExisting) groupsList.innerHTML=''

    const template = document.createElement('div');
    template.innerHTML=newGroupsHtml;
    const newGroups = template.querySelectorAll('#groups > div');

    newGroups.forEach(div => {
      groupsList.appendChild(div);
      const change_role_btn=div.querySelector('[name="change_role_btn"]')
      if(change_role_btn){
        ChangeRoleDropdown.registerTippyChangeRoleDropdown(change_role_btn)
      }
      const remove_btn=div.querySelector('[name="remove-btn"]')
      if(remove_btn){
        remove_btn.addEventListener("click", () => RetractRole.retractRole(remove_btn))
      }
   });
  }
}