export interface Commit {
  sha: string;
  message: string;
  author: string;
}

export interface Workflow {
  id: string;
  name: string;
  branch: string;
  commit: Commit;
}

export interface Attempt {
  pipeline_id: string;
  index: number;
  result: string;
  failed_blocks: string[];
  duration_ms: number;
  executed_job_count: number;
}

export interface Job {
  id: string;
  name: string;
  result: string;
  duration_ms: number;
  original_job_id: string | null;
  executed_in_attempt: number;
}

export interface Block {
  name: string;
  result: string;
  reused_from: string | null;
  deps: string[];
  jobs: Job[];
}

export interface Promotion {
  name: string;
  status: string;
  pipeline_id: string;
}

export interface CurrentPipeline {
  pipeline_id: string;
  blocks: Block[];
  promotions: Promotion[];
}

export interface WorkspaceData {
  workflow: Workflow;
  attempts: Attempt[];
  current: CurrentPipeline;
}
