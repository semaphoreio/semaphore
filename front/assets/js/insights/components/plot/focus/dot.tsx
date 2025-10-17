
import type { FocusInterface } from "./type";

interface Props extends FocusInterface{
  color: string;
}

export default(opts: Props) => {
  const {
    x,
    y,
    color,
  } = opts;

  return (
    <g>
      <circle
        r="3"
        className="circle focus-circle"
        cx={x}
        cy={y}
        style={{
          "fill": color,
        }}
      />
    </g>
  );
};
