export default {
  init(params) {
    return new RecurrenceComponent(params.recurring, params.at)
  }
}

import { parseExpression } from 'cron-parser'
import { Validator, Rule } from './validation'
import { CronParser } from '../../cron_parser'

class RecurrenceComponent {
  constructor(recurring, cron) {
    this.cronValidator = new Validator('cronExpression', { recurring: recurring, cron: cron }, [
      new Rule((n) => n.recurring && !hasFiveParts(n.cron), 'must be a valid cron expression'),
      new Rule((n) => n.recurring && !isValidCron(n.cron), 'must be a valid cron expression')
    ])

    this.handleRecurringChange()
    this.handleCronExpressionChange()
    toggleCronExpressionDisabled(recurring, cron)
  }

  isValid() {
    return this.cronValidator.isValid()
  }

  renderValidations() {
    return this.cronValidator.render()
  }

  handleRecurringChange() {
    const inputElements = document.querySelectorAll('input[data-action="changeRecurring"]')
    if (!inputElements) { return }

    inputElements.forEach((element) => {
      element.addEventListener('change', (event) => {
        const recurring = event.target.value === 'true'
        let newCronValue = toggleCronExpressionDisabled(recurring)
        let newValue = { recurring: recurring, cron: newCronValue }

        this.cronValidator.setValue(newValue)
        this.cronValidator.render()
      })
    })
  }

  handleCronExpressionChange() {
    const inputElement = document.querySelector('input[data-action="changeCronExpression"]')
    if (!inputElement) { return }

    inputElement.addEventListener('input', (event) => {
      const newExpression = event.target.value
      const oldValue = this.cronValidator.getValue()
      const newValue = { recurring: oldValue.recurring, cron: newExpression }

      this.cronValidator.setValue(newValue)
      this.cronValidator.render()

      if (this.cronValidator.isValid()) {
        populateCronWhenExpression(newExpression)
        populateCronNextExpression(newExpression)
      }
    })
  }
}

function hasFiveParts(expression) {
  return expression.split(/\s+/).length === 5
}

function isValidCron(expression) {
  try {
    parseExpression(expression, { tz: 'utc' })
    return true
  }
  catch (err) {
    return false
  }
}

function toggleCronExpressionDisabled(recurring, cron = '0 0 * * *') {
  const cronInputElement = document.querySelector('input[data-element="cronInput"]')
  const cronExpressionContainer = document.querySelector('div[data-validation="cronExpression"]')

  if (cronInputElement && cronExpressionContainer) {
    if (recurring) {
      cronInputElement.value = cron
      cronInputElement.removeAttribute('disabled')
      cronExpressionContainer.classList.remove('dn')
    }
    else {
      cronExpressionContainer.classList.add('dn')
      cronInputElement.setAttribute('disabled', 'disabled')
      cronInputElement.value = ''
    }
  }

  return cronInputElement.value
}

function populateCronWhenExpression(expression) {
  document
    .querySelectorAll('[cron-when]')
    .forEach((element) => {
      element.setAttribute('expression', expression)
      CronParser.when(element)
    })


}

function populateCronNextExpression(expression) {
  document
    .querySelectorAll('[cron-next]')
    .forEach((element) => {
      element.setAttribute('expression', expression)
      CronParser.next(element)
    })

}
