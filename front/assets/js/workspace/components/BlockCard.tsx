import { Block } from "../types";
import { shortId } from "../format";
import { JobRow } from "./JobRow";

export const BlockCard = ({ block }: { block: Block, }) => (
  <div className="bg-white shadow-1 pa2 br2 f5" data-node={block.name}>
    <h4 className="normal gray mb2">
      {block.name}
      {block.reused_from && (
        <span
          className="f6 fw5 bg-washed-yellow ph1 ml2"
          title={`Reused from pipeline ${shortId(block.reused_from)} — this block was not re-run`}
        >
          Reused
        </span>
      )}
    </h4>
    {block.jobs.map((job) => (
      <JobRow key={job.id} job={job}/>
    ))}
  </div>
);
