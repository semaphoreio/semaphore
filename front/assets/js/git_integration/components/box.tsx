import { JSX, VNode } from "preact";

interface BoxProps {
  boxIcon: JSX.Element;
  boxTitle: string;
  children: VNode[] | VNode;
}

export const Box = (props: BoxProps) => {
  return (
    <div className="bb b--black-075 w-100-l mb4 br3 shadow-3 bg-white">
      <div className="flex items-center justify-between pa3 bb bw1 b--black-075 br3 br--top ">
        <div>
          <div className="flex items-center">
            {props.boxIcon}
            <div className="b">{props.boxTitle}</div>
          </div>
        </div>
      </div>

      {/* Items */}
      {props.children}
    </div>
  );
};
