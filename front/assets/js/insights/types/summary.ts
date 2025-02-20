import * as util from "../util";
import * as types from "./index";

class Branch {
  pipelinePerformance: types.PipelinePerformance.Summary;
  pipelineReliability: types.PipelineReliability.Summary;
  projectPerformance: types.ProjectPerformance.Summary;
  pipelineFrequency: types.PipelineFrequency.Summary;

  static fromJSON(json: types.JSONInterface.Summary): Branch {
    const summary = new Branch();
    summary.pipelinePerformance = types.PipelinePerformance.Summary.fromJSON(
      json.performance
    );
    summary.pipelineReliability = types.PipelineReliability.Summary.fromJSON(
      json.reliability
    );
    summary.pipelineFrequency = types.PipelineFrequency.Summary.fromJSON(
      json.frequency
    );
    summary.projectPerformance = types.ProjectPerformance.Summary.fromJSON(
      json.project
    );
    return summary;
  }

  get meanTimeToRecovery(): string {
    return util.Formatter.duration(this.projectPerformance.meanTimeToRecovery);
  }

  get lastSuccessfulRun(): string {
    return util.Formatter.dateDiff(
      this.projectPerformance.lastSuccessfulRunAt,
      new Date()
    );
  }

  get pipelinePerformanceP50(): string {
    return util.Formatter.duration(this.pipelinePerformance.all.mean);
  }

  get pipelinePerformanceStdDev(): string {
    return util.Formatter.duration(this.pipelinePerformance.all.stdDev);
  }

  get pipelineFrequencyDailyCount(): string {
    return util.Formatter.dailyRate(
      this.pipelineFrequency.count,
      this.pipelineFrequency.daysDiff
    );
  }

  get pipelineReliabilityPassRate(): string {
    if (this.pipelineReliability.allCount == 0) {
      return `N/A`;
    }
    return util.Formatter.percentage(this.pipelineReliability.passRate);
  }
}

export class Project {
  defaultBranch: Branch;
  allBranches: Branch;
  cdSummary: Branch;

  static fromJSON(
    defaultBranch: types.JSONInterface.Summary,
    allBranches: types.JSONInterface.Summary,
    cdSummary: types.JSONInterface.Summary
  ): Project {
    const summary = new Project();
    summary.defaultBranch = Branch.fromJSON(defaultBranch);
    summary.allBranches = Branch.fromJSON(allBranches);
    summary.cdSummary = Branch.fromJSON(cdSummary);
    return summary;
  }
}
