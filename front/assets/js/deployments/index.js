import CreateDeploymentTargetWizard from './create_wizard'
import EditDeploymentTargetWizard from './edit_wizard'
import HistoryPage from './history_page'

import BasicsComponent from './components/basics'
import CredentialsComponent from './components/credentials'
import SubjectsComponent from './components/subjects'
import ObjectsComponent from './components/objects'

export class DeploymentTargets {
  static index() {
    handleChangeIndexLayout()
    handleRerunButtonsClicked()
    handleStopButtonsClicked()
  }

  static show() {
    const params = window.InjectedDataByBackend.Deployments

    handleRerunButtonsClicked()
    handleStopButtonsClicked()

    return HistoryPage.init({
      baseUrl: params.BaseUrl,
      filters: params.Filters
    })
  }

  static new() {
    const params = window.InjectedDataByBackend.Deployments

    return CreateDeploymentTargetWizard.init({
      basics: BasicsComponent.init(params.Basics),
      credentials: CredentialsComponent.init(params.Credentials),
      subjects: SubjectsComponent.init(params.Subjects),
      objects: ObjectsComponent.init(params.Objects)
    })
  }

  static edit() {
    const params = window.InjectedDataByBackend.Deployments

    return EditDeploymentTargetWizard.init({
      basics: BasicsComponent.init(params.Basics),
      credentials: CredentialsComponent.init(params.Credentials),
      subjects: SubjectsComponent.init(params.Subjects),
      objects: ObjectsComponent.init(params.Objects)
    })
  }
}

function handleChangeIndexLayout() {
  const deploymentsContainer = document.getElementById('deployments-container')
  const gridViewLink = document.querySelector('a[aria-controls="deployments-container"][aria-label="grid-view"]')
  const listViewLink = document.querySelector('a[aria-controls="deployments-container"][aria-label="list-view"]')

  if (gridViewLink && listViewLink) {
    const gridViewIcon = gridViewLink.querySelector('span')
    const listViewIcon = listViewLink.querySelector('span')

    gridViewLink.addEventListener('click', (event) => {
      event.preventDefault()

      listViewIcon.classList.remove('fill')
      gridViewIcon.classList.add('fill')
      deploymentsContainer.setAttribute('aria-label', 'grid-view')
    })

    listViewLink.addEventListener('click', (event) => {
      event.preventDefault()

      gridViewIcon.classList.remove('fill')
      listViewIcon.classList.add('fill')
      deploymentsContainer.setAttribute('aria-label', 'list-view')
    })
  }
}

function handleRerunButtonsClicked() {
  const rerunButtons = document.querySelectorAll('button[data-action="rerun-deployment"]')
  if (!rerunButtons || rerunButtons.length === 0) { return; }

  rerunButtons.forEach((button) => {
    button.addEventListener('click', (event) => {
      event.preventDefault()

      if (rerunConfirmed()) {
        submitForm(button.form)
      }
    })
  })
}

function handleStopButtonsClicked() {
  const rerunButtons = document.querySelectorAll('button[data-action="stop-deployment"]')
  if (!rerunButtons || rerunButtons.length === 0) { return; }

  rerunButtons.forEach((button) => {
    button.addEventListener('click', (event) => {
      event.preventDefault()

      if (stopConfirmed()) {
        submitForm(button.form)
      }
    })
  })
}

function stopConfirmed() {
  return confirm('Are you sure you want to stop deployment?')
}

function rerunConfirmed() {
  return confirm('Are you sure you want to rerun deployment?')
}

async function submitForm(form) {
  const formData = new URLSearchParams(new FormData(form))
  await fetch(form.action, { method: 'POST', body: formData })
  window.location.reload()
}
