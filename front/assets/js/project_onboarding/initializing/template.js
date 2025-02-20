import $ from "jquery"

export class Template {
  static render(state) {
    return `
      <div>

        <ul style="list-style: none; padding: 0;">
        ${this.spinnerMessage(
          "Forking Repository",
          state.deps.forkingRepository
        )}

        ${this.spinnerMessage(
          "Setting up a post-commit hook and deploy key",
          state.deps.connectedToRepository
        )}

        ${this.spinnerMessage(
          "Attaching a dedicated cache store",
          state.deps.connectedToCache
        )}
        ${this.spinnerMessage(
          "Creating an artifact archive",
          state.deps.connectedToArtifacts
        )}
        ${this.spinnerMessage(
          "Analyzing repository structure",
          state.deps.repoAnalyzed
        )}
        ${this.spinnerMessage(
          "Setting up permissions",
          state.deps.permissionsSetup
        )}

        ${this.spinnerMessage(
          "Starting first workflow",
          state.deps.firstWorkflow
        )}
        </ul>

        ${state.waitedTooLong() ? state.waitingMessage : "" }
      </div>`
  }

  static renderDeps(deps) {
    return deps.map(dep => this.renderDep(dep)).join("")
  }

  static renderDep(dep) {
    return this.spinnerMessage(dep.description, dep.ready)
  }

  static spinnerMessage(msg, isDone) {
    if(isDone == null) { return `` }

    let assetsPath = $("meta[name='assets-path']").attr("content")
    let style = "vertical-align: bottom;"

    let sign = ""
    if(isDone == "error") {
      sign = `<span class="red" style="${style}; padding-right: 12px; padding-left: 3px;">✗</span>`
    } else if(isDone) {
      sign = `<span class="green" style="${style}; padding-right: 12px; padding-left: 3px;">✓</span>`
    } else {
      sign = `<img style="${style}; padding-right: 9px;" src="${assetsPath}/images/spinner-2.svg">`
    }

    return `<li>${sign}<span>${msg}</span></li>`
  }
}
