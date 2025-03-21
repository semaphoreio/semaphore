import $ from "jquery"
import * as Diff from "diff"
import { escapeHtml } from "../../../escape_html"

function assetsPath() {
  return $("meta[name='assets-path']").attr("content")
}

function renderNothing() {
  return `<div class="pa6 tc">
    <img src="${assetsPath()}/images/icn-sparkles.svg" alt="sparkles">
    <p class="measure-narrow mt2 mb0">
      Everything clean, nothing to commit!
      <br>
      When you make changes you’ll be able to review them here before the commit.
    </p>
  </div>`
}

function renderCommited(path) {
  let backButton = `<div class="mb3">
    <a href="${path}" class="btn btn-primary" data-action=editorCommit>
    ← Back to the project
    </a>
  </div>`

  return `<div class="pa6 tc">
  <img src="${assetsPath()}/images/icn-sparkles.svg" alt="sparkles">
  <p class="measure-narrow mt2 mb0">
    Your workflow has been committed!
    <br>
    New builds will use updated workflow.
    ${backButton}
  </p>
</div>`
}

function renderDiffLines(initialYAML, newYAML) {
  let options = {
    ignoreWhitespace: false,
    newlineIsToken: false
  }

  let diff = Diff.diffLines(initialYAML, newYAML, options)

  let diffLines = []
  let plusCount = 0
  let minusCount = 0
  let addedLinesCount = 0
  let removedLinesCount = 0

  diff.forEach(function(part) {
    let lines = part.value.replace(/\n$/g, '').split("\n")

    lines.forEach(function(line) {
      if(part.added) {
        plusCount += 1
        addedLinesCount += 1

        diffLines.push(`<tr class=line-added>`)
        diffLines.push(`  <td></td>`)
        diffLines.push(`  <td>${plusCount}</td>`)
        diffLines.push(`  <td>${escapeHtml(line)}</td>`)
        diffLines.push(`</tr>`)
      } else if(part.removed) {
        minusCount += 1
        removedLinesCount += 1

        diffLines.push(`<tr class=line-removed>`)
        diffLines.push(`  <td>${minusCount}</td>`)
        diffLines.push(`  <td></td>`)
        diffLines.push(`  <td>${escapeHtml(line)}</td>`)
        diffLines.push(`</tr>`)
      } else {
        plusCount += 1
        minusCount += 1

        diffLines.push(`<tr>`)
        diffLines.push(`  <td>${minusCount}</td>`)
        diffLines.push(`  <td>${plusCount}</td>`)
        diffLines.push(`  <td>${escapeHtml(line)}</td>`)
        diffLines.push(`</tr>`)
      }
    })
  })

  return {
    addedLinesCount: addedLinesCount,
    removedLinesCount: removedLinesCount,
    lines: diffLines.join("\n")
  }
}

function renderYamlDiff(path, oldYaml, newYaml) {
  let diffLines         = renderDiffLines(oldYaml, newYaml)
  let addedLinesCount   = diffLines.addedLinesCount
  let removedLinesCount = diffLines.removedLinesCount
  let lines             = diffLines.lines

  // note: path is a html element

  return `
    <details class="wf-edit-commit-file">
      <summary class="f5 pointer">
        ${path}
        <span class="green">+${addedLinesCount}</span>
        <span class="red">-${removedLinesCount}</span>
      </summary>

      <div class="wf-edit-commit-table-container">
        <table class="wf-edit-commit-table">
          <tbody>
            ${lines}
          </tbody>
        </table>
      </div>
    </details>
  `
}

function renderDiffSummary(pipelines) {
  let changed = 0
  let added   = 0
  let deleted = 0

  pipelines.forEach(p => {
    if(p.createdInEditor) {
      added += 1
    } else {
      changed += 1
    }
  })

  let summary = []

  if(changed > 0) {
    summary.push(`${changed} changed file${changed > 1 ? "s": ""}`)
  }

  if(added > 0) {
    summary.push(`${added} added file${added > 1 ? "s": ""}`)
  }

  if(deleted > 0) {
    summary.push(`${deleted} deleted file${deleted > 1 ? "s": ""}`)
  }

  return summary.join(", ")
}

function renderChanges(workflow) {
  let pipelines = workflow.pipelines.filter(p => p.hasCommitableChanges())

  let diffs = pipelines.map(p => {
    let initial = p.createdInEditor ? "" : p.initialYaml
    let path = ""

    if(!p.createdInEditor && p.isPathChangedFromInitial() && !p.workflow.pipelineWithPathExists(p.initialFilePath)) {
      path = `<span style="text-decoration: line-through;">${p.initialFilePath}</span> &rarr; <span>${p.filePath}</span>`
    } else {
      path = `<span>${p.filePath}</span>`
    }

    return renderYamlDiff(path, initial, p.toYaml())
  }).join("\n")

  diffs += workflow.deletedPipelines.filter((p) => {
    return !p.workflow.pipelineWithPathExists(p.filePath)
  }).map(p => {
    let path = `<span>${p.filePath}</span>`

    return renderYamlDiff(path, p.initialYaml, "")
  }).join("\n")

  return `
    <div class="f5 bb b--lighter-gray mb3">
      <div class="f5 gray mb2 nt1">
        ${renderDiffSummary(pipelines)}
      </div>

      ${diffs}
    </div>
  `
}

function renderCommitPanel(workflow, commiterAvatar, initialBranch, pushBranch) {
  let avatar = `
    <div class="flex-shrink-0 pr3">
      <img src="${commiterAvatar}" class="br-100" width="32">
    </div>
  `

  let commitSummary = `<div class="mb2">
    <div class="f5 gray mb1">Commit summary</div>
    <input id=workflow-editor-commit-dialog-summary
           type="text"
           class="form-control w-100 w-two-thirds-m"
           value="Update Semaphore configuration"
           placeholder="Enter message…">
  </div>`

  let branchNote = ""
  if(initialBranch != pushBranch) {
    branchNote = `
      <p class="f6 measure mt1 red">
        <strong>Note:</strong> The push branch differs from the origin branch. The workflow starts from a tag or forked repository. In that cases, we can't push to the origin source.
      </p>
    `
  }

  let branchInput = `
    <div class="mb3">
      <div class="f5 gray mb1">Branch</div>
      <div class="relative">
        <input id=workflow-editor-commit-dialog-branch
               type="text"
               class="form-control w-100 w-two-thirds-m"
               value="${escapeHtml(pushBranch)}"
               placeholder="e.g. master"
               style="padding-left: 28px">
         <img src="${assetsPath()}/images/icn-branch.svg"
              class="z-999 absolute"
              style="left: 7px; top: 7px;">
         ${branchNote}
      </div>
    </div>
  `

  let commitButton = `<div class="mb3">
    <a href="#" class="btn btn-primary" data-action=editorCommit>
      Looks good, Start →
    </a>
  </div>`

  let commitNote = `<p class="f6 w-100 w-two-thirds-m mb1" id=workflow-editor-commit-dialog-note>
    This will commit and push the configuration to repository and trigger the run on Semaphore.
  </p>`

  return `
    <div id=workflow-editor-commit-dialog class="pa3">
      <div class="flex">
        ${avatar}
        <div class="flex-auto bl b--lighter-gray pl3">
          ${renderChanges(workflow)}
          ${commitSummary}
          ${branchInput}
          ${commitButton}
          ${commitNote}
        </div>
      </div>
    </div>
  `
}

function render(workflow, commiterAvatar, initialBranch, pushBranch) {
  if(workflow.hasCommitableChanges()) {
    return renderCommitPanel(workflow, commiterAvatar, initialBranch, pushBranch)
  } else {
    return renderNothing()
  }
}

export var CommitDialogTemplate = {
  render: render,
  renderDiffLines: renderDiffLines,
  renderCommited: renderCommited
}
