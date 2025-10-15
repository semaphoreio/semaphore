import type { VNode } from "preact";
import { cloneElement } from "preact";
import type * as types from "../../types";

interface Props {
  top: number;
  left: number;
  content?: VNode;
  activeMetric?: types.Chart.Metric;
}

export const Tooltip = ({ top, left, content, activeMetric }: Props) => {
  const adjustedLeft = (left: number) => {
    if (left < 2 * width) {
      left += 30;
    } else {
      left -= (width + 30);
    }

    return left;
  };

  const width = 150;
  left = adjustedLeft(left);

  return (
    <div
      className="tooltip"
      style={{
        "position": `absolute`,
        "top": top,
        "left": left,
        "width": width,
        "z-index": `3`,
      }}
    >
      {cloneElement(content, { activeMetric })}
    </div>
  );
};
