import $ from "jquery";
import moment from "moment";
import semver from "semver";

export class AgentPoller {
  constructor(firstPageUrl, agentType, nextPageUrl, latestAgentVersion, canManage) {
    this.firstPageUrl = firstPageUrl
    this.currentUrl = firstPageUrl
    this.nextPageUrl = nextPageUrl
    this.agentType = agentType
    this.canManage = canManage
    this.latestAgentVersion = latestAgentVersion
    this.deleteAgentType = $('#delete-agent-type');
    this.pagination = $('.agent-pagination');
    this.nextPageBtn = $('.agent-pagination .next');
    this.firstPageBtn = $('.agent-pagination .first');
    this.pollTimeoutId = null;

    this.nextPageBtn.on('click', this.handleNextPageClick.bind(this));
    this.firstPageBtn.on('click', this.handleFirstPageClick.bind(this));
  }

  poll() {
    fetch(this.currentUrl)
      .then(r => r.json())
      .then(data => this.takeAction(data))
      .catch(err => this.handleError(err))
  }

  handleNextPageClick() {
    clearTimeout(this.pollTimeoutId)
    this.nextPageBtn.prop('disabled', true)
    this.firstPageBtn.prop('disabled', true)
    this.currentUrl = this.nextPageUrl
    this.poll()
  }

  handleFirstPageClick() {
    clearTimeout(this.pollTimeoutId)
    this.nextPageBtn.prop('disabled', true)
    this.firstPageBtn.prop('disabled', true)
    this.currentUrl = this.firstPageUrl
    this.poll()
  }

  takeAction(data) {
    this.nextPageUrl = data.next_page_url
    this.showAgentList(data.agents)
    this.updateAgentCount(data.total_agents)
    this.updateDeleteButtonState(data.total_agents)
    this.updatePaginationButtons(data)
    this.pollTimeoutId = setTimeout(() => this.poll(), 5000)
  }

  handleError(err) {
    console.error(err)
    this.pollTimeoutId = setTimeout(() => this.poll(), 5000)
  }

  showAgentList(agents) {
    this.renderAgents(agents)
  }

  updateAgentCount(newCount) {
    let html = '';

    if (newCount > 1) {
      html = `<span class="green">${newCount} running agents</span>`
    } else if (newCount === 1) {
      html = `<span class="green">1 running agent</span>`
    } else {
      html = '<span>No running agents</span>'
    }

    document.querySelector('#self-hosted-agents-count').innerHTML = html
  }

  updateDeleteButtonState(newCount) {
    if (newCount > 0) {
      this.deleteAgentType.attr('href', 'javascript: void(0)');
      this.deleteAgentType.addClass('disabled')
      tippy(this.deleteAgentType.get(0), {
        content: function() {
          return 'Only available for agent types with no running agents'
        }
      })
    } else {
      this.deleteAgentType.attr('href', `/self_hosted_agents/${this.agentType}/confirm_delete`);
      this.deleteAgentType.removeClass('disabled')
      this.deleteAgentType.removeAttr('data-tippy-content')
    }
  }

  renderAgents(agents) {
    let html = "";

    agents.forEach((a) => {
      html += this.renderAgent(a)
    })

    document.querySelector("#self-hosted-agents").innerHTML = html;
    tippy('[data-tippy-content]');
  }

  agentVersion(version) {
    if (semver.gte(version, this.latestAgentVersion)) {
      return version;
    } else {
      const warningMessage = `A new version ${this.latestAgentVersion} is available`;
      return `<span class="orange" data-tippy-content="${warningMessage}">⚠️ ${version}</span>`;
    }
  }

  renderAgent(agent) {
    return `
      <div class="shadow-1 bg-white pa3 mv3 br3">
        <div class="pl2-l">
          <div>
            <div class="flex-l items-center justify-between">
              <h3 class="f4 mb1">
                <span class="green select-none">●</span>
                ${agent.name}
              </h3>
              <div class="f5 gray mb0">
                ${this.agentVersion(agent.version)}
                · Connected ${moment.unix(agent.connected_at.seconds).fromNow()}
                · ${this.disconnectButton(agent)}
              </div>
            </div>
            <div class="f5 gray mb0">
              ${agent.os} · ${agent.ip_address} · PID: ${agent.pid}
            </div>
          </div>
        </div>
      </div>
    `
  }

  disconnectButton(agent) {
    if (agent.disabled) {
      return '<span class="gray">Already disconnected</span>'
    } else {
      if (this.canManage == "true") {
        return `<a href="/self_hosted_agents/${this.agentType}/confirm_disable/${agent.name}" class="gray disable-self-hosted-agent">Disconnect</a>`
      } else {
        return ``
      }
    }
  }

  isFirstPage() {
    return this.currentUrl == this.firstPageUrl
  }

  updatePaginationButtons(data) {
    // If there are agents, but the current page is empty, go back to the first page.
    if (!this.isFirstPage() && data.total_agents > 0 && data.agents.length == 0) {
      this.currentUrl = this.firstPageUrl;
      this.handleFirstPageClick();
      return
    }

    // If we are on the first page, and there's no next page,
    // just hide the pagination buttons.
    if (this.isFirstPage() && data.next_page_url == "") {
      this.pagination.hide();
    } else {
      this.pagination.show();
    }

    if (data.next_page_url != "") {
      this.nextPageBtn.prop('disabled', false)
    } else {
      this.nextPageBtn.prop('disabled', true)
    }

    if (this.currentUrl != this.firstPageUrl) {
      this.firstPageBtn.prop('disabled', false)
    } else {
      this.firstPageBtn.prop('disabled', true)
    }
  }

  assetsPath() {
    return document.querySelector("meta[name='assets-path']").content;
  }
}
