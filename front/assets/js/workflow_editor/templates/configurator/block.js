import { Section } from "./section"
import { AgentConfig } from "./agent"

export class BlockConfigTemplate {
  static deps(block) {
    let deps = ""
    let otherBlocks = block.pipeline.blocks.filter((b) => b.uid !== block.uid)

    if(otherBlocks.length === 0) {
      // when there is only one block in the pipeline, there are no dependencies

      deps = `<p class="f5 gray tc mv3">
        Only one block in the pipeline. You need at least two blocks to define dependencies.
      </p>`
    } else {
      deps = otherBlocks.map((b) => {
        let input = "";
        let label = "";

        if(block.dependencies.includes(b.name)) {
          input = `<input data-action=toggleBlockDependency
                          data-dependency-name="${escapeHtml(b.name)}"
                          type="checkbox"
                          autocomplete="off"
                          name="dependency"
                          id="config-block-deps-${escapeHtml(b.name)}"
                          class="mr1"
                          checked="">`
          label = `<label for="config-block-deps-${escapeHtml(b.name)}" class="">${escapeHtml(b.name)}</label>`
        } else {
          if(block.dependencyIntroducesCycle(b)) {
            input = `<input type="checkbox"
                            name="dependency"
                            autocomplete="off"
                            id="config-block-deps-${escapeHtml(b.name)}"
                            disabled=""
                            class="mr1">`;

            label = `<label title="This dependency would introduce a dependency cycle"
                            for="config-block-deps-${escapeHtml(b.name)}"
                            class="mid-gray">${escapeHtml(b.name)}</label>`
          } else {
            input = `<input data-action=toggleBlockDependency
                            data-dependency-name="${escapeHtml(b.name)}"
                            type="checkbox"
                            autocomplete="off"
                            name="dependency"
                            id="config-block-deps-${escapeHtml(b.name)}"
                            class="mr1">`

            label = `<label for="config-block-deps-${escapeHtml(b.name)}" class="">${escapeHtml(b.name)}</label>`
          }
        }

        return `
          <div>
            ${input}
            ${label}
          </div>`
      }).join("\n")
    }

    let options = {
      title: "Dependencies",
      errorCount: 0,
      helpLink: "https://docs.semaphoreci.com/reference/pipeline-yaml#dependencies-in-blocks",
      helpTitle: "Dependencies in Blocks"
    }

    return Section.section(options, deps)
  }

  static skip(block) {
    let input = "";

    if(block.hasSkipConditions()) {
      input = `<input data-action=changeBlockSkipCondition
        type="text"
        autocomplete="off"
        class="form-control form-control-small w-100"
        placeholder="e.g. branch != 'master'"
        value="${escapeHtml(block.skipCondition)}">`
    } else {
      input = `<input data-action=changeBlockSkipCondition
        type="text"
        autocomplete="off"
        class="form-control
        form-control-small w-100"
        placeholder="e.g. branch != 'master'">`
    }

    let doc_link = "https://github.com/renderedtext/when#skip-block-exection"

    let status = null
    if(block.hasSkipConditions()) {
      status = "has skip condition"
    }

    let options = {
      title: "Skip Conditions",
      status: status,
      collapsable: true
    }

    return Section.section(options, `
      <p class="f5 mb2">
        Skip the block under certain conditions.
        See some of the most common use cases
        <a href="${doc_link}" target="_blank" rel="noopener">here</a>.
      </p>

      ${ input }
    `)
  }

  static envVars(block) {
    let envs = ""

    if(block.envVars.isEmpty()) {
      envs = `<p class="f5 gray tc mv3">No variables on this block.</p>`
    } else {
      envs = block.envVars.map((e, index) => `
        <div class="flex items-start bg-washed-gray ba b--lighter-gray pa2 br3 mv2">
          <div class="input-group flex-auto">
            <input id="env-var-name"
              data-action=changeBlockEnvVar
              data-env-var-index=${index}
              autocomplete="off"
              type="text"
              class="w-50 form-control form-control-small code"
              placeholder="Name"
              value="${escapeHtml(e.name)}">

            <input id="env-var-value"
              data-action=changeBlockEnvVar
              data-env-var-index=${index}
              autocomplete="off"
              type="text"
              class="w-50 form-control form-control-small code"
              placeholder="Value"
              value="${escapeHtml(e.value)}">
          </div>
          <div data-action=removeBlockEnvVar
               data-env-var-index=${index}
               class="flex-shrink-0 f3 fw3 pl2 pr2 nr2 black-40 hover-black pointer">
              ×
          </div>
        </div>
      `).join("\n")
    }

    let count = block.envVars.count()

    let status = null
    if(count == 1) {
      status = count + " env var"
    } else if(count> 1) {
      status = count + " env vars"
    }

    let options = {
      title: "Environment variables",
      status: status,
      errorCount: 0,
      collapsable: true
    }

    return Section.section(options, `
      ${envs}

      <div>
        <a data-action=addBlockEnvVar
           href="#"
           class="db f6 gray truncate">+ Add env_vars</a>
      </div>
    `)
  }

  static secrets(block) {
    let secretNames = block.secrets.allSecretNames()
    let usedSecretCount = 0

    let checkboxes = "";

    if(secretNames.length === 0) {
      checkboxes = `
        <div class="f6 gray tc mv3">
          No Secrets defined
        </div>`;
    } else {
      checkboxes = secretNames.map((s, index) => {
        let isUsedOnBlock = block.secrets.includes(s)

        if(isUsedOnBlock) {
          usedSecretCount++

          let secret = block.secrets.findByName(s)

          return secret.usedSecretTemplate(index)
        } else {
          return `<div>
            <input autocomplete="off" data-action=toggleBlockSecret data-secret-name="${escapeHtml(s)}" type="checkbox" id="secret-${index}" class="mr1">
            <label data-secret-name="${escapeHtml(s)}" for="secret-${index}">${escapeHtml(s)}</label>
          </div>`;
        }
      }).join("\n")
    }

    let status = null
    if(usedSecretCount == 1) {
      status = usedSecretCount + " secret"
    } else if(usedSecretCount > 1) {
      status = usedSecretCount + " secrets"
    }

    let options = {
      collapsable: true,
      title: "Secrets",
      status: status,
      errorCount: block.secrets.filter((s) => s.errors.exists()).length
    }

    console.log(block.parrent)

    return Section.section(options, `
      <p class="f5 mb2">Define Secrets at project or organization level · <a href="/projects/${window.InjectedDataByBackend.ProjectName}/settings/secrets">Manage Secrets</a></p>

      ${ checkboxes }
    `)
  }

  static deleteBlock() {
    return `
      <div class="bb b--lighter-gray tc">
        <a data-action=deleteBlock
           href="#"
           class="link db red pa3">Delete Block…</a>
      </div>
    `
  }

  static name(block) {
    let options = {
      title: "Name of the Block",
      errorSubtitles: block.errors.list("name")
    }

    return Section.section(options, `
      <input data-action=changeBlockName
             type="text"
             id="block-name"
             class="form-control form-control-small w-100"
             placeholder="Enter Name…"
             autocomplete="off"
             value="${escapeHtml(block.name)}">
    `);
  }

  static agent(block) {
    let status = null
    if(block.overrideGlobalAgent) {
      status = "overrides pipeline's agent"
    }

    let options = {
      title: "Agent",
      status: status,
      collapsable: true
    }

    let overrideCheckedAttr = "";
    let dividerClass = ""

    if(block.overrideGlobalAgent) {
      overrideCheckedAttr = "checked"

      //
      // If the agent block is displayed, we are adding a bottom border
      // to separate it visually.
      //
      dividerClass = "bb b--lighter-gray pb2 mb2"
    }

    return Section.section(options, `
      <div class="mt2">
        <div class="${dividerClass} mt2">
          <input type="checkbox"
                 id="block-agent-switch"
                 autocomplete="off"
                 data-action=toggleAgentOverrideEnabled
                 ${overrideCheckedAttr}>

          <label for="block-agent-switch" class="f5">
            Override global agent definition
          </label>
        </div>

        ${block.overrideGlobalAgent ? AgentConfig.render(block.agent) : ""}
      </div>
    `)
  }
}
