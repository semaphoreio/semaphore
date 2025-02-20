export default {
  init(params) {
    return new CredentialsComponent(params.envVars, params.files)
  }
}

const EnvVar = class {
  constructor(json = {}) {
    this.id = json.id || ''
    this.name = json.name || ''
    this.value = json.value || ''
    this.md5 = json.md5 || ''
  }

  isNameValid() { return !!(this.name) }
  isValueValid() { return !!(this.md5 || this.value) }

  isValid() {
    return !this.validate().length
  }

  validate() {
    let validations = []

    if (!this.isNameValid()) {
      validations.push({ field: 'name', message: 'must not be empty' })
    }
    if (!this.isValueValid()) {
      validations.push({ field: 'value', message: 'must not be empty' })
    }

    return validations
  }
}

const File = class {
  constructor(json = {}) {
    this.id = json.id || ''
    this.path = json.path || ''
    this.content = json.content || ''
    this.md5 = json.md5 || ''
  }

  isPathValid() { return !!(this.path) }
  isContentValid() { return !!(this.md5 || this.content) }

  isValid() {
    return !this.validate().length
  }

  validate() {
    let validations = []

    if (!this.isPathValid()) {
      validations.push({ field: 'path', message: 'must not be empty' })
    }
    if (!this.isContentValid()) {
      validations.push({ field: 'content', message: 'must not be empty' })
    }

    return validations
  }
}

class CredentialsComponent {
  constructor(envVars, files) {
    this.envVars = Array.from(envVars).map(json => new EnvVar(json));
    this.files = Array.from(files).map(json => new File(json));

    this.handleAddButtons()
    this.renderEnvVars()
    this.renderFiles()
  }

  isValid() {
    return this.envVars.every(envVar => envVar.isValid()) &&
      this.files.every(file => file.isValid())
  }

  renderValidations() {
    this.renderEnvVarValidations()
    this.renderFileValidations()
  }

  insertEmptyEnvVar() {
    this.envVars.push(new EnvVar)
    this.renderEnvVars()
  }

  updateEnvVarName(index, newName) {
    this.envVars[index].name = newName
    this.renderEnvVarValidations()
  }

  updateEnvVarValue(index, newValue) {
    this.envVars[index].value = newValue
    this.envVars[index].md5 = ''
    this.renderEnvVarValidations()
  }

  pruneEnvVar(index) {
    this.envVars[index].value = ''
    this.envVars[index].md5 = ''
    this.renderEnvVars()
  }

  deleteEnvVar(index) {
    this.envVars.splice(index, 1)
    this.renderEnvVars()
  }

  insertEmptyFile() {
    this.files.push(new File)
    this.renderFiles()
  }

  updateFilePath(index, newPath) {
    this.files[index].path = newPath
    this.renderFileValidations()
  }

  updateFileContent(index, newContent) {
    this.files[index].content = newContent
    this.files[index].md5 = ''
    this.renderFiles()
  }

  pruneFile(index) {
    this.files[index].content = ''
    this.files[index].md5 = ''
    this.renderFiles()
  }

  deleteFile(index) {
    this.files.splice(index, 1)
    this.renderFiles()
  }

  renderEnvVars(showValidations = false) {
    const envVarsContainer = document.querySelector('[data-component="env-vars"]')
    envVarsContainer.innerHTML = ''

    this.envVars.forEach(function (envVar, index) {
      const envVarElementHTML = renderEnvVarElement(envVar, index)
      envVarsContainer.insertAdjacentHTML('beforeend', envVarElementHTML)
    })

    if (showValidations) {
      this.renderEnvVarValidations()
    }

    this.handleEnvVarButtons()
  }

  renderEnvVarValidations() {
    this.envVars.forEach((envVar, index) => renderEnvVarValidation(envVar, index))
  }

  renderFiles(showValidations = false) {
    const filesContainer = document.querySelector('[data-component="files"]')
    filesContainer.innerHTML = ''

    this.files.forEach(function (file, index) {
      const fileElementHTML = renderFileElement(file, index)
      filesContainer.insertAdjacentHTML('beforeend', fileElementHTML)
    })

    if (showValidations) {
      this.renderFileValidations()
    }

    this.handleFileButtons()
  }

  renderFileValidations() {
    this.files.forEach((file, index) => renderFileValidation(file, index))
  }

  handleAddButtons() {
    handleStandaloneButton('env-var-add', 'click',
      asStandaloneCallback(() => {
        this.insertEmptyEnvVar()
      }))

    handleStandaloneButton('file-add', 'click',
      asStandaloneCallback(() => {
        this.insertEmptyFile()
      }))
  }

  handleEnvVarButtons() {
    handleItemButtons('env-vars', 'update-name', 'input',
      asItemCallback((event, dataIndex) => {
        this.updateEnvVarName(dataIndex, event.target.value)
      }))
    handleItemButtons('env-vars', 'update-value', 'input',
      asItemCallback((event, dataIndex) => {
        this.updateEnvVarValue(dataIndex, event.target.value)
      }))
    handleItemButtons('env-vars', 'prune', 'click',
      asItemCallback((_event, dataIndex) => {
        this.pruneEnvVar(dataIndex)
      }))
    handleItemButtons('env-vars', 'delete', 'click',
      asItemCallback((_event, dataIndex) => {
        this.deleteEnvVar(dataIndex)
      }))
  }

  handleFileButtons() {
    handleItemButtons('files', 'browse', 'click',
      asItemCallback((_event, dataIndex) => {
        browseSystemFiles(dataIndex)
      }))
    handleItemButtons('files', 'update-path', 'input',
      asItemCallback((event, dataIndex) => {
        this.updateFilePath(dataIndex, event.target.value)
      }))
    handleItemButtons('files', 'upload', 'change',
      asItemCallback((_event, dataIndex) => {
        readFile(dataIndex, (content) => {
          this.updateFileContent(dataIndex, content)
        })
      }))
    handleItemButtons('files', 'prune', 'click',
      asItemCallback((_event, dataIndex) => {
        this.pruneFile(dataIndex)
      }))
    handleItemButtons('files', 'delete', 'click',
      asItemCallback((_event, dataIndex) => {
        this.deleteFile(dataIndex)
      }))
  }
}

function asStandaloneCallback(callbackFn) {
  return (event) => {
    event.preventDefault()
    event.stopPropagation()

    callbackFn(event)
  }
}

function handleStandaloneButton(dataAction, eventName, callback) {
  document
    .querySelector(`[data-action="${dataAction}"]`)
    .addEventListener(eventName, callback)
}

function asItemCallback(callbackFn) {
  return (event) => {
    event.preventDefault()
    event.stopPropagation()

    const dataIndex = parseInt(event.target.getAttribute('data-index'))
    callbackFn(event, dataIndex)
  }
}

function handleItemButtons(component, dataAction, eventName, callback) {
  document
    .querySelector(`[data-component="${component}"]`)
    .querySelectorAll(`[data-action="${dataAction}"]`)
    .forEach((button) => {
      button.addEventListener(eventName, callback)
    })
}

function browseSystemFiles(index) {
  document.getElementById(`target_files_${index}_upload`).click()
}

function readFile(index, callback) {
  const element = document
    .querySelector(`[data-action="upload"][data-index="${index}"]`)
  let reader = new FileReader();

  reader.onload = function (event) {
    const readFile = event.target.result
    const encodedFile = window.btoa(readFile)
    callback(encodedFile)
  }

  reader.readAsBinaryString(element.files[0])
  element.value = null
}

function renderEnvVarElement(envVar, index) {
  const prefixId = `$target_env_vars_${index}`
  const prefixName = `target[env_vars][${index}]`

  return `
    <div id="${prefixId}" class="mb2" data-validation="env-var" data-index="${index}">
      <div data-component="env_var" data-index="${index}" class="flex items-center mb2" >
        <input id="${prefixId}_id" name="${prefixName}[id]" value="${escapeHtml(envVar.id)}" type="hidden">
        <input id="${prefixId}_md5" name="${prefixName}[md5]" value="${envVar.md5}" type="hidden">
        <input id="${prefixId}_name" name="${prefixName}[name]" value="${escapeHtml(envVar.name)}" type="text"
              data-validation-input="name" data-action="update-name" data-index="${index}" class="form-control w5 mr2">
        <input id="${prefixId}_value" name="${prefixName}[value]" data-action="update-value" data-index="${index}" class="form-control w5 mr2"
              data-validation-input="value" type="text" value="${escapeHtml(envVar.value)}" style="${envVar.md5 ? 'display: none' : ''}">
        <div class="flex items-center ba b--light-gray ph2 h2 br2 bg-washed-gray w5 mr2"
            style="${envVar.md5 ? '' : 'display: none'}">
          <div class="flex-auto f5 code overflow-x-scroll">MD5:&nbsp;${envVar.md5}</div>
          <div class="flex-shrink-0 pl2">
            <a href="#" data-action="prune" data-index="${index}"
              class="link f3 gray hover-dark-gray">×</a>
          </div>
        </div>
        <span data-action="delete" data-index="${index}"
              class="material-symbols-outlined gray pointer">
            delete
        </span>
      </div>
      <div class="f5 b mv1 red dn" data-validation-message="env-var"></div>
    </div>
  `
}

function renderEnvVarValidation(envVar, index) {
  const validationContext = document.querySelector(`[data-validation="env-var"][data-index="${index}"]`)
  const validationInputs = {
    name: validationContext.querySelector(`[data-validation-input="name"]`),
    value: validationContext.querySelector(`[data-validation-input="value"]`)
  }
  const validationMessage = validationContext.querySelector(`[data-validation-message="env-var"]`)
  let messages = []

  Object.values(validationInputs).forEach(input => {
    input.classList.remove('bg-washed-red', 'red')
  })

  envVar.validate().forEach(validation => {
    validationInputs[validation.field].classList.add('bg-washed-red')
    validationInputs[validation.field].classList.add('red')
    messages.push(`${validation.field} ${validation.message}`)
  })

  validationMessage.innerHTML = messages.join(', ')
  validationMessage.classList.remove('dn')
}

function renderFileElement(file, index) {
  const assetsPath = window.InjectedDataByBackend.Deployments.AssetsPath
  const imageIconSrc = assetsPath + "/images/icn-file.svg"
  const hasContent = file.md5 || file.content

  const prefixId = `target_files_${index}`
  const prefixName = `target[files][${index}]`

  return `
    <div id="${prefixId}" class="mb2" data-validation="file" data-index="${index}">
      <div data-component="file" data-index="${index}" class="flex items-center" >
        <input id="${prefixId}_id" name="${prefixName}[id]" value="${escapeHtml(file.id)}" type="hidden">
        <input id="${prefixId}_md5" name="${prefixName}[md5]" value="${file.md5}" type="hidden">
        <input id="${prefixId}_path" name="${prefixName}[path]" type="text" value="${escapeHtml(file.path)}"
                data-validation-input="path" data-action="update-path" data-index="${index}"class="form-control w5 mr2">
        <div class="form-control w5 mr2">
          <div class="f5 gray tr" style="${hasContent ? "display: none" : ""}">
            <input id="${prefixId}_upload" name="${prefixName}[upload]" type="file"
                    data-action="upload" data-index="${index}" style="display: none">
            <a href="#" data-action="browse" data-validation-input="content" data-index="${index}" class="gray">Upload File</a>
          </div>

          <div class="flex items-center ba b--light-gray ph2 h2 br2 bg-washed-gray"
                style="${hasContent ? '' : 'display: none'}">
            <div class="flex-auto f5 code overflow-x-scroll">
              <span style="${file.md5 ? '' : "display: none"}">MD5:&nbsp;${file.md5}</span>
              <span class="db mr2" style="${file.content ? '' : 'display: none'}">
                <img src="${imageIconSrc}" alt="File icon" class="mr2" >
                <span>Size: ${humanSize(file)}</span>
              </span>
              <input id="${prefixId}_content" name="${prefixName}[content]" value="${file.content}" type="hidden">
            </div>

            <div class="flex-shrink-0 pl2">
              <a href="#" data-action="prune" data-index="${index}"
                class="link f3 gray hover-dark-gray">×</a>
            </div>
          </div>
        </div>
        <span data-action="delete" data-index="${index}" class="material-symbols-outlined gray pointer">
            delete
        </span>
      </div>
      <div class="f5 b mv1 red dn" data-validation-message="file"></div>
    </div>
  `
}

function renderFileValidation(file, index) {
  const validationContext = document.querySelector(`[data-validation="file"][data-index="${index}"]`)
  const validationInputs = {
    path: validationContext.querySelector(`[data-validation-input="path"]`),
    content: validationContext.querySelector(`[data-validation-input="content"]`)
  }
  const validationMessage = validationContext.querySelector(`[data-validation-message="file"]`)
  let messages = []

  Object.values(validationInputs).forEach(input => {
    input.classList.remove('bg-washed-red', 'red')
  })

  file.validate().forEach(validation => {
    validationInputs[validation.field].classList.add('bg-washed-red', 'red')
    messages.push(`${validation.field} ${validation.message}`)
  })

  validationMessage.innerHTML = messages.join(', ')
  validationMessage.classList.remove('dn')
}

function humanSize(file) {
  const byteSize = new Blob([file.content]).size
  const megabyte = 1024 * 1024
  const kilobyte = 1024

  if (byteSize > megabyte) {
    return `${Math.round(byteSize * 100 / megabyte) / 100} MB`
  }
  if (byteSize > 1024) {
    return `${Math.round(byteSize * 100 / kilobyte) / 100} kB`
  }
  return `${byteSize} bytes`
}
