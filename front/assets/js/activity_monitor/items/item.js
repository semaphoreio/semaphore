import $ from "jquery"
import _ from "lodash"

export class Item {
  static render(item, state) {
    switch(item.item_type) {
    case "Pipeline":
      return renderPipeline(item, state)
    case "Debug Session":
      return renderDebug(item, state)
    }
  }

  static hidden(nonVisible) {
    if(nonVisible <= 0) return "";

    return `
      <div class="bg-white shadow-1 mv3 ph3 pv2 br3">
        <div class="flex items-center">
          <div class="flex-shrink-0 mr2 dn db-l">
            <img src="${assetsPath()}/images/icn-lock.svg" class="mt1">
          </div>
          <div class="flex-auto f5">
            + ${nonVisible} ${pluralize("job", "jobs", nonVisible)} running in other projects you can’t access
          </div>
        </div>
      </div>
    `
  }

  static stop(item) {
    return `
      <div class="child absolute top-0 right-0 z-5 nt2 mr3">
        <div data-stop="stop" class="shadow-1 bg-white f6 br2 pa1">
          <button data-action="activity-monitor-stop" class="input-reset pv1 ph2 br2 bg-transparent hover-bg-red hover-white bn pointer">Stop…</button>
        </div>

        <div data-stop="are-you-sure-dialog" class="shadow-1 bg-white f6 br2 pa1" style='display: none'>
          <span class="ph2">Are you sure?</span>
          <button data-action="activity-monitor-stop-nevermind" class="input-reset pv1 ph2 br2 bg-gray white bn pointer">Nevermind</button>
          <button data-action="activity-monitor-stop-execute" data-item-type="${item.item_type}" data-item-id="${item.item_id}" data-endpoint="/activity/stop" class="input-reset pv1 ph2 br2 bg-red white bn pointer">Stop</button>
        </div>

        <div data-stop="stopping" class="shadow-1 bg-white f6 br2 pa1" style='display: none'>
          <span class="ph2">Stopping...</span>
        </div>
      </div>
    `
  }

  static jobSummary(item) {
    let left = item.job_stats.left || 0
    let waiting = item.job_stats.waiting.job_count || 0
    let running = item.job_stats.running.job_count || 0

    let renderAsFirst = function(count, name, klass) {
      let jobs = pluralize("Job", "Jobs", count)

      return `<span class="${klass}">${count} ${jobs} ${name}</span>`
    }

    let renderAsAddition = function(count, name, klass) {
      return `<span class="${klass}">+ ${count} ${name}</span>`
    }

    let runningHtml = ""
    let waitingHtml = ""
    let leftHtml = ""

    if(running > 0) {
      runningHtml = renderAsFirst(running, "running", "fw5 bg-green white ph1 br1")
    }

    if(waiting > 0) {
      if(running > 0) {
        waitingHtml = renderAsAddition(waiting, "waiting", "fw5 bg-yellow black-60 ph1 br1")
      } else {
        waitingHtml = renderAsFirst(waiting, "waiting", "fw5 bg-yellow black-60 ph1 br1")
      }
    }

    if(left > 0) {
      if(running > 0 || waiting > 0) {
        leftHtml = renderAsAddition(left, "left", "fw5 bg-mid-gray white ph1 br1")
      } else {
        leftHtml = renderAsFirst(left, "left", "fw5 bg-mid-gray white ph1 br1")
      }
    }

    return `
      <div class="f5 mt1">
       <span class="gray">${runningHtml} ${waitingHtml} ${leftHtml} ${Item.jobSummaryDescription(item)}</span>
      </div>
    `
  }

  static jobSummaryDescription(item) {
    let waiting = item.job_stats.waiting
    let running = item.job_stats.running

    let waitingMachineTypes = _.map(waiting.machine_types, (v, k) => k)
    let runningMachineTypes = _.map(running.machine_types, (v, k) => k)

    let allMachineTypes = _.uniq(_.concat(waitingMachineTypes, runningMachineTypes)).sort()

    if(allMachineTypes.length === 0) {
      // during pipeline/job transitions, this could be a short state
      return ""
    }

    if(allMachineTypes.length === 1) {
      // there is only one machine type, returning just the name
      return `on ${allMachineTypes[0]}`
    }

    return "on " + _.map(allMachineTypes, (machineType) => {
      let waitingCount = waiting.machine_types[machineType] || 0
      let runningCount = running.machine_types[machineType] || 0

      if(waitingCount > 0 && runningCount > 0) {
        return `${machineType} (${runningCount} running, ${waitingCount} waiting)`
      }

      if(waitingCount > 0) {
        return `${machineType} (${waitingCount} waiting)`
      }

      if(runningCount > 0) {
        return `${machineType} (${runningCount} running)`
      }

      return machineType
    }).join(", ")
  }
}

function renderDebug(item, state) {
  switch(item.debug_type) {
    case "Job":
      return renderDebugJob(item, state)
    case "Project":
      return renderDebugProject(item, state)
  }
}

function timeAgo(time) {
  return `<time-ago datetime="${time}"></time-ago>`
}

function renderPipeline(item, state) {
  return `
    <div class="bg-white shadow-1 mv3 ph3 pv2 br3 relative hide-child">
      ${Item.stop(item)}

      <div class="flex items-center bb b--black-10 pb2 mb2">
        <img src="${refTypeIconPath(item.ref_type)}" width="16" class="flex-shrink-0 mr2 dn db-l">
        <div>
          <a href="${item.ref_path}" class="link dark-gray word-wrap underline-hover b">${escapeHtml(item.ref_name)}</a>
          <span>from project</span>
          <a href="${item.project_path}">${escapeHtml(item.project_name)}</a>
        </div>
      </div>

      <div class="flex-l pv1">
        <div class="w-75-l pr4-l mb2 mb1-l">
          <div class="flex">
            <div class="flex-shrink-0 mr2 dn db-l">
              <img src="${assetsPath()}/images/icn-commit.svg" width="16" class="mt1">
            </div>
            <div class="flex-auto">
              <div>
                <a href="${item.workflow_path}" class="word-wrap">${escapeHtml(item.title)}</a>
              </div>
              ${state === "lobby" ? queuing() : Item.jobSummary(item)}
            </div>
          </div>
        </div>
        <div class="w-25-l">
          <div class="flex flex-row-reverse-l items-center">
            <img src="${item.user_icon_path}" class="db br-100 ba b--black-50" width="32" height="32">
            <div class="f5 gray ml2 ml3-m ml0-l mr3-l tr-l">${timeAgo(item.created_at)} <br> by ${escapeHtml(item.user_name)}</div>
          </div>
        </div>
      </div>
    </div>
  `
}

function renderDebugJob(item, state) {
  return `
    <div class="pv2 bt b--lighter-gray hover-bg-row-highlight relative hide-child">

      ${Item.stop(item)}

      <div class="flex-l pv1">
        <div class="w-75-l pr4-l mb2 mb1-l">
          <div class="flex">
            <div class="flex-shrink-0 mr2 dn db-l">
              <img src="${assetsPath()}/images/icn-console.svg" class="mt1">
            </div>
            <div class="flex-auto">
              <div>
                Debugging <a href="${item.debug_job_path}" class="word-wrap">${escapeHtml(item.debug_job_name)}</a> from <a href="${item.workflow_path}" class="word-wrap">${escapeHtml(item.workflow_name)}</a> / <a href="${item.pipeline_path}" class="word-wrap">${escapeHtml(item.pipeline_name)}</a>
              </div>
              <div class="f5 mt1">
                <a href="${item.ref_path}" class="link dark-gray word-wrap underline-hover">${escapeHtml(item.ref_name)}</a>
                <span class="gray">from</span>
                <a href="${item.project_path}" class="link dark-gray word-wrap underline-hover">${item.project_name}</a>
              </div>

              ${state === "lobby" ? queuing() : Item.jobSummary(item)}
            </div>
          </div>
        </div>
        <div class="w-25-l">
          <div class="flex flex-row-reverse-l items-center">
            <img src="${item.user_icon_path}" class="db br-100 ba b--black-50" width="32" height="32">
            <div class="f5 gray ml2 ml3-m ml0-l mr3-l tr-l">${timeAgo(item.created_at)} <br> by ${item.user_name}</div>
          </div>
        </div>
      </div>
    </div>
  `
}

function renderDebugProject(item, state) {
  return `
    <div class="pv2 bt b--lighter-gray hover-bg-row-highlight relative hide-child">

      ${Item.stop(item)}

      <div class="flex-l pv1">
        <div class="w-75-l pr4-l mb2 mb1-l">
          <div class="flex">
            <div class="flex-shrink-0 mr2 dn db-l">
              <img src="${assetsPath()}/images/icn-console.svg" class="mt1">
            </div>
            <div class="flex-auto">
              <div>
                Debugging <a href="${item.project_path}" class="link dark-gray word-wrap underline-hover">${escapeHtml(item.project_name)}</a>
              </div>

              ${state === "lobby" ? queuing() : Item.jobSummary(item)}
            </div>
          </div>
        </div>
        <div class="w-25-l">
          <div class="flex flex-row-reverse-l items-center">
            <img src="${item.user_icon_path}" class="db br-100 ba b--black-50" width="32" height="32">
            <div class="f5 gray ml2 ml3-m ml0-l mr3-l tr-l">${timeAgo(item.created_at)} <br> by ${escapeHtml(item.user_name)}</div>
          </div>
        </div>
      </div>
    </div>
  `
}

function queuing() {
  return `
    <div class="f5 mt1">
      <span class="fw5 bg-mid-gray white ph1 br1">In the lobby</span>
    </div>
  `
}

function assetsPath() {
  return $("meta[name='assets-path']").attr("content")
}

function refTypeIconPath(ref_type) {
    let path

    switch(ref_type) {
      case 'Branch':
        path = `${assetsPath()}/images/icn-branch.svg`
        break;
      case 'Pull request':
        path = `${assetsPath()}/images/icn-pullrequest.svg`
        break;
      case 'Tag':
        path = `${assetsPath()}/images/icn-tag.svg`
        break
    }

    return `${path}`
}

function pluralize(single, multiple, count) {
  if(count === 1) {
    return single
  } else {
    return multiple
  }
}
