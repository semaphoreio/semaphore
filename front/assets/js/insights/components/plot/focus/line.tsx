import { h } from "preact";
import { FocusInterface } from "./type";

interface Props extends FocusInterface{
  color: string;
}

export default(opts: Props) => {
  const {
    x,
    focusLock,
    topMargin,
    bottomMargin,
    color,
  } = opts;

  return (
    <g>
      <line
        className="focus-line"
        x1={x}
        y1={topMargin}
        x2={x}
        y2={bottomMargin}
        style={{
          "stroke": color,
          "stroke-dasharray": `${focusLock ? `` : `2, 2`}`,
        }}
      />
    </g>
  );
};
