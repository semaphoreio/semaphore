export default {
  init(prefixId) {
    return new CommandsComponent(prefixId)
  }
}

class CommandsComponent {
  constructor(prefixId) {
    this.prefixId = prefixId
    this.handleCommandsInput();
  }

  handleCommandsInput() {
    const elements = {
      textarea: document.getElementById(`${this.prefixId}_commands`),
      submit: document.getElementById(`${this.prefixId}_submit`)
    }

    toggleSubmitButton(elements, elements.textarea.value !== "")

    elements.textarea.addEventListener("input", (e) => {
      const enabled = e.target.value !== ""
      toggleSubmitButton(elements, enabled)
      toggleTextareaBackground(elements, enabled)
    })
  }
}

function toggleTextareaBackground(elements, enabled) {
  if (enabled) {
    elements.textarea.classList.remove('bg-lightest-red')
  } else {
    elements.textarea.classList.add('bg-lightest-red')
  }
}

function toggleSubmitButton(elements, enabled) {
  if (enabled) {
    elements.submit.removeAttribute('disabled')
  } else {
    elements.submit.setAttribute('disabled', 'disabled')
  }
}
