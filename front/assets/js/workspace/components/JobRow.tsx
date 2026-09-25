import { Job } from "../types";
import { formatDuration, resultTextColor } from "../format";
import { statusIconHtml } from "../icons";

export const JobRow = ({ job }: { job: Job, }) => {
  const reused = Boolean(job.original_job_id);

  return (
    <div
      style={{ fontWeight: `normal` }}
      className={`link dark-gray flex items-center justify-between pv1 nh2 ph2 bt b--black-15 hover-bg-washed-gray${reused ? ` job-reused` : ``}`}
      title={reused ? `This job passed in a previous run and was reused here — it was not re-executed.` : undefined}
    >
      <div className="flex items-center pr3">
        <span className="flex items-center" dangerouslySetInnerHTML={{ __html: statusIconHtml(job.result) }}/>
        {job.name}
      </div>
      {reused ? (
        <span className="f6 gray">reused</span>
      ) : (
        <span className={`f5 code ${resultTextColor(job.result)}`}>{formatDuration(job.duration_ms)}</span>
      )}
    </div>
  );
};
