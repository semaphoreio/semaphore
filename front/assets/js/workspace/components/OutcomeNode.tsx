import { OUTCOME_NODE } from "../graph/wires";
import { shortId } from "../format";
import { statusIconHtml } from "../icons";

interface OutcomeNodeProps {
  result: string;
  attemptIndex?: number;
  pipelineId: string;
}

export const OutcomeNode = ({ result, attemptIndex, pipelineId }: OutcomeNodeProps) => (
  <div
    data-node={OUTCOME_NODE}
    className="bg-white shadow-1 pa2 br2 f5"
    style={{ width: `11rem` }}
  >
    <div className="flex items-center">
      <span className="flex items-center" dangerouslySetInnerHTML={{ __html: statusIconHtml(result) }}/>
      <span className="b dark-gray">Pipeline {result}</span>
    </div>
    {attemptIndex !== undefined && <div className="f6 gray mt1">attempt #{attemptIndex}</div>}
    <div className="f6 code gray mt1">{shortId(pipelineId)}</div>
  </div>
);
