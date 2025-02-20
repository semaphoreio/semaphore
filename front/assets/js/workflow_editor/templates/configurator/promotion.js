import { Promotion } from "../../models/promotion"

export class PromotionConfigTemplate {
  static name(promotion) {
    return `
      <div class="bb b--lighter-gray pa3">
        <label for="promotion-name" class="db f5 b mb1">Name of the Promotion</label>
        <input type="text"
               id="promotion-name"
               data-action=changeName
               class="form-control form-control-small w-100"
               placeholder="Enter Name…"
               value="${escapeHtml(promotion.name)}">
      </div>
    `
  }

  static deploymentTargets(promotion) {
    const currentTarget = promotion.deploymentTarget
    const projectName = Promotion.getProjectName()

    const options = Promotion.validDeploymentTargets().map((target) => {
      if (currentTarget === target) {
        return `<option value="${target}" selected>Target: ${target}</option>`
      }

      return `<option value="${target}">Target: ${target}</option>`
    })

    const emptyTargetOption = currentTarget === "" ?
      `<option value="" selected>No target</option>` :
      `<option value="">No target</option>`

    const invalidTargetOption =
      (currentTarget !== "" && !Promotion.validDeploymentTargets().includes(currentTarget)) ?
        `<option value="${currentTarget}" selected disabled>Target: ${currentTarget}</option>` : ""

    const errors = promotion.errors.list("deployment_target").map((e) => {
      return `<p class="f6 mb0 red">${e}</p>`
    }).join("\n")

    const maybeFormControlErrorClass = invalidTargetOption ? "form-control-error" : ""

    return `
      <div class="bb b--lighter-gray pa3">
        <div class="flex justify-between items-start">
          <label for="deployment-target" class="db f5 b mb1">Deployment target</label>
          <a class="btn btn-primary" href="/projects/${escapeHtml(projectName)}/deployments/new">Create New</a>
        </div>
        <p class="f5 mt2 mb3">
        By default, promotions are not linked to any Deployment Target. You can configure promotions to use
        Deployment Targets and utilize their functionalities, like restricting access for users or branches.
          <br />
          <a href="https://docs.semaphoreci.com/essentials/deployment-targets/" target="_blank">Read more about Deployment Targets here</a>.
        </p>

        <select id="promotionDeploymentTarget" data-action=changeDeploymentTarget
                class="form-control form-control-small w-100 ${maybeFormControlErrorClass}">
          ${invalidTargetOption}
          ${emptyTargetOption}
          ${options.join('\n')}
        </select>
        ${errors}
      </div>
    `
  }

  static autoPromote(promotion) {
    return `
      <div class="bb b--lighter-gray pa3">
        <label class="db f5 b">How to Promote?</label>

        <p class="f5 mb3">
          Promotions are manual by default. But you can also set your
          work to promote automatically when it meets certain conditions.
        </p>

        <div class="flex items-start mv2">
          <input
            type="checkbox"
            name="promotion-type"
            id="promotion-auto"
            class="mr1"
            data-action=enableAutoPromotion
            ${promotion.autoPromote.isEnabled() ? "checked" : ""}>

          <div class="flex-auto items-start ml2 nt1">
            <label for="promotion-auto">Enable automatic promotion</label>

            ${promotion.autoPromote.isEnabled()
        ? PromotionConfigTemplate.autoPromoteConditions(promotion)
        : ""}
          </div>
        </div>
      </div>`
  }

  static autoPromoteConditions(promotion) {
    let errors = promotion.autoPromote.errors.list().map((e) => {
      return `<p class="f6 mb0 red">${e}</p>`
    }).join("\n")

    return `
      <div class="pa2 mt2 bg-washed-gray ba b--lighter-gray br3">
        <label for="auto-promotion-conditions" class="f6 db fw5 mb1">When?</label>
        <input type="text"
               id="promotion-condition"
               data-action=changeAutoPromoteCondition
               class="form-control form-control-small w-100 ${promotion.autoPromote.errors.exists() ? "form-control-error" : ""}"
               placeholder="Enter Condition..."
               value="${escapeHtml(promotion.autoPromote.condition)}">

         ${errors}

        <details class="mt2" open="">
          <summary class="db f5 gray hover-dark-gray pointer">Common examples</summary>

           ${PromotionConfigTemplate.autoPromoteExample(
      "Passed on master branch",
      "branch = 'master' AND result = 'passed'"
    )}

           ${PromotionConfigTemplate.autoPromoteExample(
      "Passed on master branch or a tag",
      "(branch = 'master' OR tag =~ '.*') AND result = 'passed'"
    )}

           ${PromotionConfigTemplate.autoPromoteExample(
      "If there are changes in the package.json",
      "change_in('/package.json')"
    )}

           <p class="f6 mt3 mb0">
             See <a href="https://docs.semaphoreci.com/reference/conditions-reference/">Docs: Auto-Promotion conditions</a>
             for more examples and detailed information.
           </p>
        </details>
      </div>`
  }

  static autoPromoteExample(title, example) {
    return `<div class="mt2">
      <label class="db f5 gray mb1">${title}</label>
      <div class="input-button-group">
        <input type="text" class="form-control form-control-small w-100" value="${example}" readonly="">

        <button data-action=useExample class="btn btn-secondary btn-small">Use</button>
      </div>
    </div>`
  }

  static deletePromotion() {
    return `
      <div class="bb b--lighter-gray tc">
        <a data-action=deletePromotion href="#" class="link db red pa3"">Delete Promotion…</a>
      </div>
    `
  }
}
