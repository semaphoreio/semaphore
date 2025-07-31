import $ from "jquery";

import { CommitDialogTemplate } from "../templates/commit/dialog"
import { Features } from "../../features";

function newDialogDiv() {
  return $("<div style='display=none'>")[0]
}

export class CommitPanel {
  constructor(parent, workflow, options) {
    this.parent = parent
    this.workflow = workflow

    this.paths = options.paths
    this.commiterAvatar = options.commiterAvatar
    this.initialBranch = options.initialBranch
    this.pushBranch = options.pushBranch

    this.registerDismissHandler()
    this.registerToggleCommitPanel()
    this.registerCommitHandler()

    this.dialog = newDialogDiv()

    this.tippyInstance = null
  }

  registerDismissHandler() {
    this.on("click", "[data-action=editorDismiss]", () => {
      window.location = this.paths.dismiss
    })
  }

  registerToggleCommitPanel() {
    this.on("click", "[data-action=toggleCommitDialog]", () => {
      if(this.tippyInstance) {
        this._hideTippy()
      } else {
        this._showTippy()
      }
    })
  }

  _showTippy() {
    let selector = "#workflow-editor-nav [data-action=toggleCommitDialog]"

    this.tippyInstance = tippy(selector, {
      content: this.dialog,
      allowHTML: true,
      trigger: 'click',
      theme: 'dropdown',
      interactive: true,
      placement: 'bottom-end',
      duration: 0,
      maxWidth: '720px',
      onHidden: () => {
        this.tippyInstance.destroy()
        this.tippyInstance = null
      }
    })[0]

    this.tippyInstance.show()
    $("#workflow-editor-commit-dialog-summary").focus().select()
  }

  _hideTippy() {
    this.tippyInstance.hide()
  }

  registerCommitHandler() {
    this.on("keydown", "#workflow-editor-commit-dialog-summary, #workflow-editor-commit-dialog-branch", (e) => {
      if((e.metaKey || e.ctrlKey) && e.keyCode == 13) {
        this._commit(e)
      }
    })

    this.on("click", "[data-action=editorCommit]", $.proxy(this._commit, this))
  }

  _commit(e) {
    let branch = null;
    let commitMessage = null;

    var url = this.paths.commit;

    this.parent.disableOnLeaveConfirm()

    $("[data-action=editorCommit]").addClass("btn-working");
    $("[data-action=editorCommit]").disabled = true;

    var message = 'We are committing the changes to your git repository. ';
    message = message + 'This can take up to a few minutes.';
    $("#workflow-editor-commit-dialog-note").text(message);
    $("#workflow-editor-commit-dialog-note").addClass("dark-indigo");

    let csrf = $("meta[name='csrf-token']").attr("content")

    branch = $("#workflow-editor-commit-dialog-branch").val()
    commitMessage = $("#workflow-editor-commit-dialog-summary").val()

    var body = new FormData();
    body.append("_csrf_token", csrf)
    body.append("branch", branch)
    body.append("commit_message", commitMessage)
    body.append("initial_branch", this.initialBranch)

    // if this is part of project onboarding, we need to also make sure 
    // that the project onboarding finished signal is sent
    if($("#workflow-editor-project-onboarding").length > 0) {
      body.append("project_onboarding_finished", "true")
    }


    this.workflow.pipelines.forEach((p) => {
      let content = new Blob([p.toYaml()], {
        type: 'text/yaml',

        // Preserve the line endings. Don't overwrite them native OS format.
        endings: "transparent"
      })

      body.append("modified_files[]", content, p.filePath)
    })

    this.workflow.deletedPipelineFilePaths().forEach((path) => {
      let content = new Blob([""], {type: 'text/yaml'})

      body.append("deleted_files[]", content, path)
    })

    fetch(url, {
      method: 'POST',
      body: body
    })
    .then((res) => {
      var contentType = res.headers.get("content-type");

      if(contentType && contentType.includes("application/json")) {
        return res.json();
      } else {
        throw new Error(res.statusText);
      }
    })
    .then((res) => {
      if(res.error) {
        throw new Error(res.error);
      } else {
        return res;
      }
    })
    .then((data) => {
      console.log(data)

      if (data.wait)
        if(Features.isEnabled("useCommitJob"))          
          this.commitJobHandler(branch, data.job_id);
        else {
          this.afterCommitHandler(branch, data.commit_sha);
        }
      else {
        this.dialog.innerHTML = CommitDialogTemplate.renderCommited(this.paths.dismiss);
      }
    })
    .catch(function(reason) {
      console.log(reason)

      this.resetButtonAndShowErrorMessage();
    })
  }

  resetButtonAndShowErrorMessage() {
    $("[data-action=editorCommit]").removeClass("btn-working");
    $("[data-action=editorCommit]").disabled = false;

    var message = "There was an issue with committing the changes to your git repository. "
    message = message + 'Please try again and contact support if the issue persists.';
    $("#workflow-editor-commit-dialog-note").text(message);
    $("#workflow-editor-commit-dialog-note").removeClass("dark-indigo");
    $("#workflow-editor-commit-dialog-note").addClass("red");
  }

  commitJobHandler(branch, job_id) {
    var url   = this.paths.checkCommitJob + `?job_id=${job_id}` 

    console.log(`Checking commit job ${url}`)

    fetch(url)
    .then((res) => {
      var contentType = res.headers.get("content-type");

      if(contentType && contentType.includes("application/json")) {
        return res.json();
      } else {
        throw new Error(res.statusText);
      }
    })
    .then((res) => {
      if(res.error) {
        throw new Error(res.error);
      } else {
        return res;
      }
    })
    .then((data) => {
      if(data.commit_sha === "") {
        setTimeout(this.commitJobHandler.bind(this, branch, job_id), 1000)
      } else {
        var message = 'The changes have been successfully committed. ';
        message = message + 'We will soon navigate you to the new workflow.';
        $("#workflow-editor-commit-dialog-note").text(message);

        this.afterCommitHandler(branch, data.commit_sha);
      }
    })
    .catch(
      (reason) => { 
        console.log(reason); 

        this.resetButtonAndShowErrorMessage();
      }
    )
  }

  afterCommitHandler(branch, commitSha) {
    var query = [`branch=${encodeURIComponent(branch)}`, `commit_sha=${encodeURIComponent(commitSha)}`].join("&")
    var url   = this.paths.checkWorkflow + "?" + query

    console.log(`Checking workflows ${url}`)

    fetch(url)
    .then((res) => {
      var contentType = res.headers.get("content-type");

      if(contentType && contentType.includes("application/json")) {
        return res.json();
      } else {
        throw new Error(res.statusText);
      }
    })
    .then((data) => {
      if(data.workflow_url == null) {
        setTimeout(this.afterCommitHandler.bind(this, branch, commitSha), 1000)
      } else {
        window.location = data.workflow_url;
      }
    })
    .catch(
      (reason) => { console.log(reason); }
    )
  }

  on(event, selector, callback) {
    this.parent.on(event, selector, callback)
  }

  update() {
    if(this.tippyInstance) {
      this.tippyInstance.destroy()
      this.tippyInstance = null
    }

    this.dialog.innerHTML = CommitDialogTemplate.render(
      this.workflow,
      this.commiterAvatar,
      this.initialBranch,
      this.pushBranch
    )
  }

}
