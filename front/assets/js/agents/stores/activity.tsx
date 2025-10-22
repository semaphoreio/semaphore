import { createContext } from "preact";

export class Agent {
  name: string;
  waitingCount: number;
  totalCount: number;
  occupiedCount: number;

  static fromJSON(json: any): Agent {
    const agent = new Agent();

    agent.name = json.name as string;
    agent.waitingCount = json.waiting_count as number;
    agent.totalCount = json.total_count as number;
    agent.occupiedCount = json.occupied_count as number;

    return agent;
  }
}

export class JobStat {
  leftCount: number;
  runningCount: number;
  waitingCount: number;
  running: Map<string, number> = new Map();
  waiting: Map<string, number> = new Map();

  static fromJSON(json: any): JobStat {
    const jobStat = new JobStat();

    jobStat.leftCount = json.left as number;
    jobStat.runningCount = json.running.job_count as number;
    jobStat.waitingCount = json.waiting.job_count as number;

    for (const type in json.waiting.machine_types) {
      const amount = json.waiting.machine_types[type] as number;
      jobStat.waiting.set(type, amount);
    }

    for (const type in json.running.machine_types) {
      const amount = json.running.machine_types[type] as number;
      jobStat.running.set(type, amount);
    }

    return jobStat;
  }

  getMachineTypes(): string[] {
    const machineTypes = new Set<string>();

    this.running.forEach((_, machineType) => {
      machineTypes.add(machineType);
    });

    this.waiting.forEach((_, machineType) => {
      machineTypes.add(machineType);
    });

    return Array.from(machineTypes);
  }

  getRunningCount(type: string): number {
    return this.running.get(type) || 0;
  }

  getWaitingCount(type: string): number {
    return this.waiting.get(type) || 0;
  }
}

export class Item {
  itemId: string;
  itemType: string;

  debugType: string;
  debugJobName: string;
  debugJobPath: string;

  userIconPath: string;
  userName: string;
  title: string;
  name: string;
  workflowPath: string;
  workflowName: string;
  pipelinePath: string;
  pipelineName: string;
  projectName: string;
  projectPath: string;
  refType: string;
  refName: string;
  refPath: string;
  priority: string;
  createdAt: string;
  jobStats: JobStat;

  static fromJSON(json: any): Item {
    const item = new Item();

    item.itemId = json.item_id as string;
    item.itemType = json.item_type as string;

    item.debugType = (json.debug_type ?? ``) as string;
    item.debugJobName = (json.debug_job_name ?? ``) as string;
    item.debugJobPath = (json.debug_job_path ?? ``) as string;

    item.userIconPath = json.user_icon_path as string;
    item.userName = json.user_name as string;
    item.title = json.title as string;
    item.name = json.name as string;
    item.workflowPath = json.workflow_path as string;
    item.workflowName = json.workflow_name as string;
    item.pipelinePath = json.pipeline_path as string;
    item.pipelineName = json.pipeline_name as string;
    item.projectName = json.project_name as string;
    item.projectPath = json.project_path as string;
    item.refType = json.ref_type as string;
    item.refName = json.ref_name as string;
    item.refPath = json.ref_path as string;
    item.priority = json.priority as string;
    item.createdAt = json.created_at as string;
    item.jobStats = JobStat.fromJSON(json.job_stats);

    return item;
  }
}

export type Action =
  | { type: `SET_WAITING_ITEMS`, value: Item[] }
  | { type: `SET_RUNNING_ITEMS`, value: Item[] }
  | { type: `SET_LOBBY_ITEMS`, value: Item[] }
  | { type: `SET_HOSTED_AGENTS`, value: Agent[] }
  | { type: `SET_SELF_HOSTED_AGENTS`, value: Agent[] }
  | { type: `DELETE_SELF_HOSTED_AGENT`, value: string }
  | { type: `SET_INVISIBLE_JOBS_COUNT`, value: number };

export interface State {
  hostedAgents: Agent[];
  selfHostedAgents: Agent[];
  waitingItems: Item[];
  runningItems: Item[];
  lobbyItems: Item[];
  invisibleJobsCount: number;
}

export const Reducer = (state: State, action: Action): State => {
  switch (action.type) {
    case `SET_HOSTED_AGENTS`:
      return {
        ...state,
        hostedAgents: action.value,
      };

    case `SET_SELF_HOSTED_AGENTS`:
      return {
        ...state,
        selfHostedAgents: action.value,
      };

    case `DELETE_SELF_HOSTED_AGENT`:
      return {
        ...state,
        selfHostedAgents: state.selfHostedAgents.filter((agent) => agent.name !== action.value),
      };

    case `SET_WAITING_ITEMS`:
      return {
        ...state,
        waitingItems: action.value,
      };

    case `SET_RUNNING_ITEMS`:
      return {
        ...state,
        runningItems: action.value,
      };

    case `SET_LOBBY_ITEMS`:
      return {
        ...state,
        lobbyItems: action.value,
      };

    default:
      return state;
  }
};

export type Dispatcher = (action: Action) => void;

export const EmptyState: State = {
  hostedAgents: [],
  selfHostedAgents: [],
  waitingItems: [],
  runningItems: [],
  lobbyItems: [],
  invisibleJobsCount: 0,
};

export const Context = createContext<{
  state: State;
  dispatch: (a: Action) => void;
}>({ state: EmptyState, dispatch: () => undefined });
