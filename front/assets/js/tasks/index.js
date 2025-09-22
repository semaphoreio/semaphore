import CreateWizard from '../create_wizard'
import EditWizard from '../edit_wizard'

import BasicsComponent from './components/basics'
import TargetComponent from './components/target'
import ParametersComponent from './components/parameters'
import RecurrenceComponent from './components/recurrence'
import JustRunForm from './just_run_form'
import HistoryPage from './history_page'
import SearchBar from './search_bar'

const sectionNames = ['basics', 'target', 'parameters', 'recurrence']

export class Tasks {
  static init(page) {
    if (page === 'index') { return Tasks.index() }
    if (page === 'show') { return Tasks.show() }
    if (page === 'new') { return Tasks.new() }
    if (page === 'edit') { return Tasks.edit() }
    if (page === 'run') { return Tasks.run() }
  }

  static shouldPoll(page) {
    if (page === 'index') { return true }
    if (page === 'show') { return true }
    return false
  }

  static index() {
    return SearchBar.init({
      baseUrl: window.InjectedDataByBackend.Tasks.BaseUrl,
    })
  }

  static show() {
    return HistoryPage.init(window.InjectedDataByBackend.Tasks)
  }

  static new() {
    return CreateWizard.init(sectionNames, {
      basics: BasicsComponent.init(window.InjectedDataByBackend.Tasks.Basics),
      target: TargetComponent.init(window.InjectedDataByBackend.Tasks.Target),
      parameters: ParametersComponent.init(window.InjectedDataByBackend.Tasks.Parameters),
      recurrence: RecurrenceComponent.init(window.InjectedDataByBackend.Tasks.Recurrence)
    })
  }

  static edit() {
    return EditWizard.init(sectionNames, {
      basics: BasicsComponent.init(window.InjectedDataByBackend.Tasks.Basics),
      target: TargetComponent.init(window.InjectedDataByBackend.Tasks.Target),
      parameters: ParametersComponent.init(window.InjectedDataByBackend.Tasks.Parameters),
      recurrence: RecurrenceComponent.init(window.InjectedDataByBackend.Tasks.Recurrence)
    })
  }

  static run() {
    return JustRunForm.init({
      referenceType: window.InjectedDataByBackend.Tasks.ReferenceType,
      referenceName: window.InjectedDataByBackend.Tasks.ReferenceName,
      pipelineFile: window.InjectedDataByBackend.Tasks.PipelineFile,
      parameters: window.InjectedDataByBackend.Tasks.Parameters,
    })
  }
}

function handleSearchBar() {
  const searchBars = document.querySelectorAll('input[data-action="filterTasks"]')
  if (!searchBars || searchBars.length === 0) { return; }

  searchBars.forEach((textInput) => {
    textInput.addEventListener('input', (event) => {
      event.preventDefault()
      event.stopPropagation()

      const queryString = event.target.value ? event.target.value.trim() : ''
      const taskDetails = document.querySelectorAll(`details[data-element="taskDetails"]`)

      if (!queryString || queryString.length < 1) {
        taskDetails.forEach((details) => details.classList.remove('dn'))
      } else {
        taskDetails.forEach((details) => {
          const taskName = details.getAttribute('data-label')
          if (taskName.toLowerCase().includes(queryString.toLowerCase())) {
            details.classList.remove('dn')
          } else {
            details.classList.add('dn')
          }
        })
      }
    })
  })
}
