import { useState } from "preact/hooks";
import { define } from "preactement";
import { InteractivePipelineTree } from "./interactive_pipeline_tree";
import {
  getJobVisibility,
  JobCounts,
  JobVisibility,
  setJobVisibility,
} from "./job_visibility";

interface JobFilterProps {
  pipelineId: string;
  counts: JobCounts;
}

export const JobFilter = ({ pipelineId, counts }: JobFilterProps) => {
  const [visibility, setVisibility] = useState(() => getJobVisibility(pipelineId));

  if (counts.reused === 0) return null;

  const select = (next: JobVisibility) => {
    if (next === visibility) return;
    setJobVisibility(pipelineId, next);
    setVisibility(next);
    InteractivePipelineTree.redrawDiagrams(pipelineId);
    InteractivePipelineTree.adjustSuccessorsTopMargins();
  };

  return (
    <div className="mb3">
      <div role="group" aria-label="Job visibility" className="flex flex-wrap">
        <button
          type="button"
          className={`btn btn-small job-visibility-button mr2 mb2 ${visibility === `all` ? `btn-primary` : `btn-secondary`}`}
          aria-pressed={visibility === `all`}
          onClick={() => select(`all`)}
        >
          All jobs ({counts.currentRun + counts.reused + counts.skipped})
        </button>
        <button
          type="button"
          className={`btn btn-small job-visibility-button mb2 ${visibility === `current` ? `btn-primary` : `btn-secondary`}`}
          aria-pressed={visibility === `current`}
          onClick={() => select(`current`)}
        >
          This run ({counts.currentRun})
        </button>
      </div>
      <p role="status" aria-atomic="true" className="f6 gray mt0 mb0">
        {counts.reused} reused {counts.reused === 1 ? `job` : `jobs`} {visibility === `current` ? `hidden` : `shown`}
      </p>
    </div>
  );
};

export function defineJobFilter(): void {
  define(`sem-pipeline-job-filter`, () => JobFilter);
}
