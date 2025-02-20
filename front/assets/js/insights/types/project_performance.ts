import * as types from "./index";

export class Summary {
  meanTimeToRecovery: number;
  lastSuccessfulRunAt: Date;

  static fromJSON(json: types.JSONInterface.ProjectPerformance): Summary {
    const summary = new Summary();
    summary.meanTimeToRecovery = json.mean_time_to_recovery;
    summary.lastSuccessfulRunAt = new Date(json.last_successful_run_at);
    return summary;
  }
}
