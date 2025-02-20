export class PromotionParametersTemplate {
  static render(promotion) {
    return `
      <div class="bb b--lighter-gray pa3">
        <label class="db f4 b">Parameters</label>

        <p class="f5 mb0">
          Pass parameters to the promoted pipeline.
        </p>

        <p class="b mt2 mb0 f6">Environment Variables</p>

        ${promotion.parameters.exists() ? this.list(promotion.parameters) : this.empty()}

        <div>
          <a data-action=addPromotionEnvParameter href="#" class="f6 gray">+ Add Environment Variable</a>
        </div>
      </div>`
  }

  static list(parameters) {
    return `
      <div class="gray mv2">
        ${parameters.map((p, index) => this.envVar(p, index)).join("\n")}
      </div>
    `;
  }

  static envVar(parameter, index) {
    return `
      <div class="relative flex bg-washed-gray ba b--lighter-gray pa2 br3 mv2">
        <div class="flex-auto">
          ${this.name(parameter, index)}
          ${this.description(parameter, index)}
          ${this.options(parameter, index)}

          ${this.required(parameter, index)}
          ${parameter.required ? this.defaultValue(parameter, index) : ""}
        </div>

        <div data-action=deletePromotionEnvParamater data-index="${index}" class="flex-shrink-0 f3 fw3 ml2 nt2 nb2 pt2 pl2 pr2 nr2 black-40 hover-black pointer bl b--lighter-gray">
          ×
        </div>
      </div>
    `;
  }

  static name(parameter, index) {
    return `
        <div>
          <div>
            <label class="f6 gray">Name</label>
          </div>
          <div>
            <input data-action=changePromotionParameterEnvName
                   data-index=${index}
                   autocomplete="off"
                   type="text"
                   class="form-control form-control-small w-100"
                   value="${escapeHtml(parameter.name) || ""}"
                   placeholder="e.g. SERVER_IP">
          </div>
        </div>
    `;
  }

  static description(parameter, index) {
    return `
      <div class="mt2">
        <div>
          <label class="f6 gray">Description</label>
        </div>
        <div>
          <input data-action=changePromotionParameterEnvDescription
                 data-index=${index}
                 autocomplete="off"
                 type="text"
                 value="${escapeHtml(parameter.description) || ""}"
                 class="form-control form-control-small w-100"
                 placeholder="e.g. Server IP where we are deploying.">
        </div>
      </div>
    `;
  }

  static defaultValue(parameter, index) {
    return `
      <div class="mt1">
        <div>
          <label class="f6 gray">Default Value <small class=f7>(used for all auto-promotions)</small></label>
        </div>
        <div>
          <input data-action=changePromotionParameterEnvDefault
                 data-index=${index}
                 autocomplete="off"
                 type="text"
                 value="${escapeHtml(parameter.default_value) || ""}"
                 class="form-control form-control-small w-100"
                 placeholder="e.g. 1.2.3.4">
        </div>
      </div>
    `;
  }

  static options(parameter, index) {
    return `
      <div class="mt2">
        <div>
          <label class="f6 gray">Valid Options <small class=f7>(leave empty to allow all values)</small></label>
        </div>
        <div>
          <textarea data-action=changePromotionParameterEnvOptions
                    data-index=${index}
                    autocomplete="off"
                    style="min-height: 70px"
                    class="form-control form-control-small w-100 f6"
                    placeholder="1.2.3.4\n3.4.5.6\n…" style="height:48px;overflow-y:hidden;"
                    wrap="off">${(parameter.options || []).join("\n") }</textarea>
        </div>
      </div>
    `;
  }

  static required(parameter, index) {
    return `
      <div class="mt2">
        <div>
          <input data-action=changePromotionParameterEnvRequired
                 type="checkbox"
                 data-index=${index}
                 ${parameter.required ? 'checked=true' : ""}>
          <label class="f6 gray">This is a required parameter</label>
        </div>
      </div>
    `;
  }

  static empty() {
    return `
      <div class="gray mv1 f7">
        No parameters defined on this promotion.
      </div>
    `;
  }
}
