import { Formatter } from "../../insights/util";

class Stats {
  allRuns: number;
  passedRuns: number;
  avgSeconds: number;
  avgSecondsSuccessful: number;
  queueTimeSeconds: number;
  queueTimeSecondsSuccessful: number;
}

export class ProjectHealth {
  url: string;
  projectId: string;
  name: string;
  private meanTimeToRecovery: number;
  private parallelism: number;
  private deployments: number;
  private last_run: Date;

  private defaultBranch: Stats;
  private allBranches: Stats;

  private displayDefaultBranchStats = false;
  private greenBuildsOnly = false;

  displayDefaultBranch(){
    this.displayDefaultBranchStats = true;
  }

  displayAllBranches(){
    this.displayDefaultBranchStats = false;
  }

  displayGreenBuilds(){
    this.greenBuildsOnly = true;
  }

  displayAllBuilds(){
    this.greenBuildsOnly = false;
  }


  static fromJSON(json: any): ProjectHealth {
    const health = new ProjectHealth();

    health.projectId = json.project_id;
    health.url = json.url;
    health.name = json.project_name;
    health.meanTimeToRecovery = json.mean_time_to_recovery_seconds;
    health.deployments = json.deployments;
    health.parallelism = json.parallelism;
    // eslint-disable-next-line @typescript-eslint/no-unsafe-argument
    health.last_run = new Date(json.last_successful_run_at);

    health.defaultBranch = new Stats();
    health.defaultBranch.allRuns = json.default_branch.all_count;
    health.defaultBranch.passedRuns = json.default_branch.passed_count;
    health.defaultBranch.avgSeconds = json.default_branch.avg_seconds;
    health.defaultBranch.avgSecondsSuccessful = json.default_branch.avg_seconds_successful;
    health.defaultBranch.queueTimeSeconds = json.default_branch.queue_time_seconds;
    health.defaultBranch.queueTimeSecondsSuccessful = json.default_branch.queue_time_seconds_successful;

    health.allBranches = new Stats();
    health.allBranches.allRuns = json.all_branches.all_count;
    health.allBranches.passedRuns = json.all_branches.passed_count;
    health.allBranches.avgSeconds = json.all_branches.avg_seconds;
    health.allBranches.avgSecondsSuccessful = json.all_branches.avg_seconds_successful;
    health.allBranches.queueTimeSeconds = json.all_branches.queue_time_seconds;
    health.allBranches.queueTimeSecondsSuccessful = json.all_branches.queue_time_seconds_successful;


    return health;
  }

  get performance(): string {
    const branch = this.displayDefaultBranchStats ? this.defaultBranch : this.allBranches;
    const avgSeconds = this.greenBuildsOnly ? branch.avgSecondsSuccessful : branch.avgSeconds;

    return Formatter.duration(avgSeconds);
  }

  get rawPerformance(): number {
    const branch = this.displayDefaultBranchStats ? this.defaultBranch : this.allBranches;
    return this.greenBuildsOnly ? branch.avgSecondsSuccessful : branch.avgSeconds;
  }

  frequency(periodInDays = 30): string {
    const branch = this.displayDefaultBranchStats ? this.defaultBranch : this.allBranches;
    const runs = this.greenBuildsOnly ? branch.passedRuns : branch.allRuns;

    return Formatter.dailyRate(runs, periodInDays);
  }

  get rawFrequency(): number {
    const branch = this.displayDefaultBranchStats ? this.defaultBranch : this.allBranches;
    return this.greenBuildsOnly ? branch.passedRuns : branch.allRuns;
  }

  get reliability(): string {
    const branch = this.displayDefaultBranchStats ? this.defaultBranch : this.allBranches;

    if (branch.allRuns == 0) {
      return `N/A`;
    }

    if (this.greenBuildsOnly) {
      return Formatter.percentage(100);
    }

    const percentage = Math.round((branch.passedRuns / branch.allRuns) * 100);
    return Formatter.percentage(percentage);
  }

  get rawReliability(): number {
    const branch = this.displayDefaultBranchStats ? this.defaultBranch : this.allBranches;

    if (branch.allRuns == 0) {
      return 0;
    }

    if (this.greenBuildsOnly) {
      return 100;
    }

    return (branch.passedRuns / branch.allRuns) * 100;
  }

  get lastRun(): string {

    if (this.last_run === null || this.last_run.getFullYear() < 2000) {
      return `N/A`;
    }

    return Formatter.dateDiff(this.last_run, new Date());
  }

  get rawLastRunAt(): Date {
    return this.last_run;
  }
}