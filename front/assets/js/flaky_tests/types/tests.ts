export class FlakyDetail {
  id: string;
  name: string;
  group: string;
  file: string;
  runner: string;
  disruptionCount: number[];
  passRates: number[];
  p95Durations: number[];
  totalCounts: number[];
  labels: string[];
  contexts: string[];
  hashes: string[];
  impacts: number[];
  disruptionHistory: HistoryItem[];
  availableContexts: string[];
  selectedContext: string;

  static fromJSON(json: any): FlakyDetail {
    const detail = new FlakyDetail();
    detail.id = json.id as string;
    detail.name = json.name as string;
    detail.group = json.group as string;
    detail.file = json.file as string;
    detail.runner = json.runner as string;
    detail.disruptionCount = json.disruptions_count as number[];
    detail.passRates = json.pass_rates as number[];
    detail.p95Durations = json.p95_durations as number[];
    detail.totalCounts = json.total_counts as number[];
    detail.impacts = json.impacts as number[];
    detail.labels = json.labels as string[];
    detail.contexts = json.contexts as string[];
    detail.hashes = json.hashes as string[];
    detail.disruptionHistory = json.disruption_history as HistoryItem[];
    detail.availableContexts = json.available_contexts as string[];
    detail.selectedContext = json.selected_context as string;

    return detail;
  }
}

export class DisruptionOccurence {
  context: string;
  hash: string;
  timestamp: Date;
  runId: string;
  requester: string;
  workflowName: string;
  url: string;

  static fromJSON(json: any): DisruptionOccurence {
    const disruptionOccurence = new DisruptionOccurence();

    disruptionOccurence.context = json.context as string;
    disruptionOccurence.hash = json.hash as string;
    disruptionOccurence.timestamp = json.timestamp as Date;
    disruptionOccurence.runId = json.run_id as string;
    disruptionOccurence.requester = json.requester as string;
    disruptionOccurence.workflowName = json.workflow_name as string;
    disruptionOccurence.url = json.url as string;

    return disruptionOccurence;
  }
}

export class HistoryItem {
  day: Date;
  count: number;
}

export class Filter {
  id: string;
  name: string;
  value: string;
  readOnly: boolean;


  static fromJSON(json: any): Filter {
    const filter = new Filter();
    filter.id = json.id as string;
    filter.name = json.name as string;
    filter.value = json.value as string;
    filter.readOnly = false;

    return filter;
  }
}
