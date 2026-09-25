import { Attempt } from "../types";
import { formatDuration } from "../format";

interface AttemptRailProps {
  attempts: Attempt[];
  currentPipelineId: string;
}

const chipDot = (result: string) => (
  <span
    className={`dib br-100 mr1 ${result === `passed` ? `bg-green` : `bg-red`}`}
    style={{ width: `8px`, height: `8px` }}
  />
);

export const AttemptRail = ({ attempts, currentPipelineId }: AttemptRailProps) => (
  <div className="flex items-center flex-wrap mb4">
    <span className="f7 gray ttu tracked mr2">Attempts</span>
    {attempts.map((attempt) => {
      const current = attempt.pipeline_id === currentPipelineId;

      return (
        <span
          key={attempt.pipeline_id}
          className={`inline-flex items-center br-pill ba ph2 pv1 mr2 mv1 f6 ${
            current ? `b--green bg-washed-green` : `b--black-20 bg-white`
          }`}
          title={`${attempt.executed_job_count} jobs executed${
            attempt.failed_blocks.length > 0 ? ` · failed at ${attempt.failed_blocks.join(`, `)}` : ``
          }`}
        >
          {chipDot(attempt.result)}
          <span className="fw6 dark-gray mr1">#{attempt.index}</span>
          {attempt.failed_blocks.length > 0 ? (
            <span className="gray mr1 truncate" style={{ maxWidth: `9rem` }}>
              {attempt.failed_blocks[0]}
            </span>
          ) : (
            current && <span className="green mr1">current</span>
          )}
          <span className="code gray f7">{formatDuration(attempt.duration_ms)}</span>
        </span>
      );
    })}
  </div>
);
