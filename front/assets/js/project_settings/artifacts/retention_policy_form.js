import { RetentionPolicyRules } from "./retention_policy_rules"

export class RetentionPolicyForm {
  constructor(form, data) {
    this.form = form

    this.render()

    let projectContainer = this.form.find("[data-container=project-policies]")
    let workflowContainer = this.form.find("[data-container=workflow-policies]")
    let jobContainer = this.form.find("[data-container=job-policies]")

    this.projectRules = new RetentionPolicyRules("project", projectContainer, data.project, this.isReadOnly())
    this.workflowRules = new RetentionPolicyRules("workflow", workflowContainer, data.workflow, this.isReadOnly())
    this.jobRules = new RetentionPolicyRules("job", jobContainer, data.job, this.isReadOnly())

    this.handleSubmit()
  }

  isReadOnly() {
    return this.form.attr("data-read-only") == "true"
  }

  render() {
    this.form.append(`
      <div class="mb3">
        <h2 class="f3 f3-m mb0">Retention Policy</h2>
          <p>
            Control after how many days are artifacts deleted. <a class="gray" href="https://docs.semaphoreci.com/essentials/artifacts/#artifact-retention-policies" target="_blank">Learn more</a>.
          </p>

          <div class="mt2 bg-washed-gray br3 ba b--black-075">
            <div data-container=project-policies></div>
            <div data-container=workflow-policies></div>
            <div data-container=job-policies></div>
          </div>
        </div>
      </div>

      ${this.renderSubmitButton()}
    `)
  }

  handleSubmit() {
    this.form.submit((e) => {
      let answer = confirm("The new policies will apply to already pushed files as well. Are you sure that you want to delete old files?")

      if (!answer) {
        e.preventDefault()
      }
    })
  }

  renderSubmitButton() {
    if (this.isReadOnly()) {
      return ""
    } else {
      return `<button type=submit class="btn btn-primary mr2" type="submit">Save changes</button>`
    }
  }
}
