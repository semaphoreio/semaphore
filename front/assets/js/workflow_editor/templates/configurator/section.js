import _ from "lodash"

function section(options, content) {
  let title = options.title
  let status = options.status
  let errorCount = options.errorCount || 0
  let collapsable = _.get(options, "collapsable", false)
  let helpLink = options.helpLink || null
  let helpTitle = options.helpTitle || null
  let errorSubtitles = options.errorSubtitles || []

  if(collapsable) {
    return collapsableSection(title, errorCount, content, status)
  } else {
    return nonCollapsableSection(title, errorCount, errorSubtitles, helpLink, helpTitle, content)
  }
}

function collapsableSection(title, errorCount, content, status) {
  let klasses = "";

  if(errorCount > 0) {
    klasses = "f5 pointer red"
  } else {
    klasses = "f5 pointer"
  }

  if(errorCount === 1) {
    title = `${title} (1 error)`
  } else if(errorCount > 1) {
    title = `${title} (${errorCount} errors)`
  }

  return `<details class="bb b--lighter-gray pa3">
    <summary class="${klasses}"><span class="b">${title}</span><span class="fr mid-gray">${status ? status : ""}</span></summary>

    <div class="mt1">
      ${content}
    </div>
  </details>`
}

function nonCollapsableSection(title, errorCount, errorSubtitles, helpLink, helpTitle, content) {
  let errors = errorSubtitles
    .map((e) => `<p class="f6 mb0 red">${e}</p>`)
    .join("\n")

  let help = ""
  if(helpLink) {
    help = `<a
      href="${helpLink}"
      target="_blank" rel="noopener"
      class="f6 gray default-tip"
      data-tippy=""
      data-original-title="Help: ${helpTitle} ↗"
      >?</a>`
  }

  return `<div class="bb b--lighter-gray pa3">
    <div class="flex justify-between mb1">
      <label class="db f5 b">${title}</label>

      ${help}
    </div>

    ${errors}

    ${content}
  </div>`
}

export var Section = {
  section: section
};
