
export class FlakyTestItem {
  testId: string;
  testName: string;
  testGroup: string;
  testRunner: string;
  testFile: string;
  testContext: string;
  testSuite: string;
  labels: string[];
  disruptionHistory: HistoryItem[];
  disruptions: number;

  latestDisruptionTimestamp: Date;
  latestDisruptionHash: string;

  latestDisruptionJobUrl: string;

  resolved: boolean;
  scheduled: boolean;
  ticketUrl: string;

  firstDisruptionAt: Date;

  age: number;

  latestDisruptionSha(): string {
    return this.latestDisruptionHash.slice(7);
  }

  daysAge(): string {
    return this.age == 1 ? `${this.age} day old` : `${this.age} days old`;
  }

  static fromJSON(json: any): FlakyTestItem {
    const item = new FlakyTestItem();
    item.testId = json.test_id as string;
    item.testName = json.test_name as string;
    item.testGroup = json.test_group as string;
    item.testRunner = json.test_runner as string;
    item.testContext = json.test_context as string;
    item.testFile = json.test_file as string;
    item.testSuite = json.test_suite as string;
    item.labels = json.labels as string[];
    item.disruptions = json.disruptions_count as number;
    item.disruptionHistory = json.disruption_history as HistoryItem[];
    item.latestDisruptionTimestamp = json.latest_disruption_timestamp as Date;
    item.latestDisruptionHash = json.latest_disruption_hash as string;
    item.latestDisruptionJobUrl = json.latest_disruption_job_url as string;
    item.resolved = json.resolved as boolean;
    item.ticketUrl = json.ticket_url as string;
    item.scheduled = json.scheduled as boolean;
    item.firstDisruptionAt = json.first_disruption_at as Date;
    item.age = json.age as number;
    return item;
  }

}

export interface HistoryItem {
  day: Date;
  count: number;
}
