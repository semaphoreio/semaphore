import $ from "jquery"
import _ from "lodash"

//
// Main entry point for agent gauges.
//
// This component manages multiple gauges, and creates a dedicated component
// for each agent type.
//
// On each update of this component:
//  - we try to update existing gauges
//  - if the gauge is not yet present, we create one, and update it
//
export class Gauges {
  constructor(selector, agentStats, selfHosted) {
    this.el = $(selector)
    this.gauges = []
    this.selfHosted = selfHosted

    this.update(agentStats)
  }

  update(agentStats) {
    this.agentStats = agentStats

    if (this.selfHosted && this.agentStats.self_hosted_agent_types.length > 0) {
      $("#activity-monitor-self-hosted-gauges-title").show();
      this.agentStats.self_hosted_agent_types.forEach(as => {
        let g = this.gauges.find(g => g.name === as.name) || this._newGauge(as)

        g.update(as)
      })
      return
    }

    if (this.selfHosted && this.agentStats.self_hosted_agent_types.length == 0) {
      $("#activity-monitor-self-hosted-gauges-title").hide();
      this.gauges = []
      this.el.children().each(function(_i, c) {
        c.remove()
      });

      return
    }

    this.agentStats.agent_types.forEach(as => {
      let g = this.gauges.find(g => g.name === as.name) || this._newGauge(as)

      g.update(as)
    })
  }

  // private

  _newGauge(data) {
    let g = new Gauge(data)

    this.gauges.push(g)
    this.el.append(g.el)

    return g
  }
}

//
// A gauge is responsible for displaying the state of one agent type.
//
// It manages the following:
//  - the color of the gauge: "green" if user, "mid-gray" if not
//  - the values in the gauge.
//
// Example gauge for e1-standard-2:
//  - name: e1-standard-2
//  - color: green
//  - percent: 10/32
//
// Updates to the gauge are animated.
//
class Gauge {
  constructor(data) {
    this.data = {}
    this.name = data.name

    this.el = this.render()
    this.update(data)
  }

  update(data) {
    if(_.isEqual(data, this.data)) return;
    this.data = data

    let waiting = ""
    if(this.data.waiting_count > 0) {
      waiting = `<span class="f5 fw5 bg-yellow black-60 ph1 br1 ml2">+ ${this.data.waiting_count} waiting</span>`
    }

    this.el.find("[data-usage]").html(`${this.data.occupied_count}/${this.data.total_count}${waiting}`)
    this.el.find("[data-usage]").attr("class", `f1 mb1 ${this.color()}`)
    this.el.find("[data-meter]").css("width", this.percent() + "%")
  }

  id() {
    return this.data.name
  }

  percent() {
    return this.data.total_count > 0 ? (this.data.occupied_count / this.data.total_count) * 100 : 0
  }

  color() {
    return this.data.occupied_count > 0 ? "green" : "mid-gray"
  }

  render() {
    return $(`
      <div class="w-100 w-auto-ns ph2 mb3">
        <div id="${this.id()}" class="w5-ns bg-white shadow-1 pa3 br3">
          <h2 class="f4 mb0 lh-title">${escapeHtml(this.name)}</h2>
          <h3 data-usage></h3>
          <div class="meter"><span data-meter style="width: 0%"></span></div>
        </div>
      </div>
    `)
  }
}
