import { Promotion } from "../types";
import { shortId } from "../format";
import { statusIconHtml } from "../icons";

export const PromotionCard = ({ promotion }: { promotion: Promotion, }) => (
  <div
    className="bg-white shadow-1 pa2 br2 f5"
    style={{ width: `12rem` }}
    data-node={promotion.name}
  >
    <div className="flex items-center">
      <span className="flex items-center" dangerouslySetInnerHTML={{ __html: statusIconHtml(promotion.status) }}/>
      <span className="dark-gray">{promotion.name}</span>
    </div>
    <div className="f6 code gray mt1">{shortId(promotion.pipeline_id)}</div>
  </div>
);
