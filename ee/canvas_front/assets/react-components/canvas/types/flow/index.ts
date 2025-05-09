import { Node } from "@xyflow/react";

// Data shape for GitHub Integration node
type LastEvent = { type: string; release: string; timestamp: string };

export type EventSourceNodeData = {
  id: string;
  repoName: string;
  repoUrl: string;
  lastEvent: LastEvent;
}

export type EventSourceNodeType = Node<EventSourceNodeData, 'event_source'>;

export type StageData = {
  label: string;
  labels: string[];
  status?: string;
  timestamp?: string;
  icon?: string;
  queue: string[];
  connections: Connection[];
  conditions: Condition[];
  run_template: RunTemplate;
}

export type RunTemplate = {
  type: RunTemplateType;
  semaphore: SemaphoreRunTemplate;
}

export enum RunTemplateType {
  SEMAPHORE = 'TYPE_SEMAPHORE',
}

export type SemaphoreRunTemplate = {
  project_id: string;
  branch: string;
  pipeline_file: string;
  task_id: string;
  parameters: Array<Record<string, string>>;
}

export type Connection = {
  name: string;
  type: string;
  filters: string[];
  filter_operator: ConnectionFilterOperator;
}

export enum ConnectionFilterOperator {
  AND = 'FILTER_OPERATOR_AND',
  OR = 'FILTER_OPERATOR_OR'
}

export type Condition = {
  type: ConditionType;
  approval: Approval;
  time_window: TimeWindow;
}

export enum ConditionType {
  APPROVAL = 'CONDITION_TYPE_APPROVAL',
  TIME_WINDOW = 'CONDITION_TYPE_TIME_WINDOW'
}

export type Approval = {
  count: number;
}

export type TimeWindow = {
  start: string;
  end: string;
  timezone: string;
  week_days: string[];
}


export type StageNodeType = Node<StageData, 'stage'>;

export type HandleType = 'source' | 'target';

export type HandleProps = {
  type: HandleType;
  conditions?: Condition[];
  connections?: Connection[];
}