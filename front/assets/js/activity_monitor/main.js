import $ from "jquery"
import { Gauges } from "./gauges"
import { Items } from "./items"

export class ActivityMonitor {
  //
  // Main entry-point for the activity monitor. Initiatied in the backend
  // controller on the first render.
  //
  static start(data, refreshDataURL) {
    return new ActivityMonitor(data, refreshDataURL)
  }

  //
  // The activity monitor is an observer of an organization.
  //
  // On every N seconds, we fetch a fresh state from the backend via the
  // <refreshDataURL> endpoint.
  //
  // Based on the answer from the backend:
  //  - we update the Agent Guages that display the occupancy levels of the quota
  //  - we display Items(pipelines and debug sessions) active in the organization
  //
  constructor(data, refreshDataURL) {
    // In order to reuse already existing Gauges class for max-parallelization,
    // we need to construct a list with one "agent_stats", but those agent stats
    // will contain data for max paralelization
    const maxParallelism = this.constructMaxParellelismData(data)
    this.maxParallelismGauge = new Gauges("#activity-monitor-max-parallelization", maxParallelism, false)
    this.gauges = new Gauges("#activity-monitor-gauges", data.agent_stats, false)
    this.selfHostedGauges = new Gauges("#activity-monitor-self-hosted-gauges", data.agent_stats, true)
    this.items = new Items("#activity-monitor-items", data.items)

    this.refreshDataURL = refreshDataURL

    this.update(data)
    this.poll()
  }

  constructMaxParellelismData(data) {
    let global = {
      agent_types: [
        {
          name: "Max parallelism",
          occupied_count: data.agent_stats.agent_types.reduce(
            (partialSum, agent_stats) => partialSum + agent_stats.occupied_count, 0
          ),
          total_count: data.agent_stats.max_parallelism
        }
      ]
    }

    if (data.agent_stats.max_agents > 0) {
      global.agent_types.push({
        name: "Max self-hosted agents",
        occupied_count: data.agent_stats.self_hosted_agent_types.reduce(
          (partialSum, agent_stats) => partialSum + agent_stats.total_count, 0
        ),
        total_count: data.agent_stats.max_agents
      })
    }

    return global
  }

  poll() {
    fetch(this.refreshDataURL)
    .then((response) => { return response.json() })
    .then((data) => { this.update(data) })
    .finally(() => { setTimeout(() => this.poll(), 3000) })
  }

  update(newData) {
    const maxParallelism = this.constructMaxParellelismData(newData)
    this.maxParallelismGauge.update(maxParallelism)
    this.gauges.update(newData.agent_stats)
    this.items.update(newData.items)
    this.selfHostedGauges.update(newData.agent_stats)
  }
}
