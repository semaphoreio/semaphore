import * as toolbox from "js/toolbox";
import type { VNode, h } from "preact";
interface OsBoxProps extends h.JSX.HTMLAttributes {
  name: string;
  icon?: string;
  iconElement?: VNode;
  active?: boolean;
}

export const OsBox = (props: OsBoxProps) => {
  const { name, active } = props;

  return (
    <div
      className={`mr3 ba bw1 tc ph3 pt3 pb2 br3 pointer hover-b--dark-gray ${
        active ? `` : `b--black-10`
      }`}
      style="width: 8em"
      onClick={props.onClick}
    >
      {props.icon && (
        <toolbox.Asset
          path={props.icon}
          width="64"
          height="64"
          class="db center"
        />
      )}
      {props.iconElement}
      <p className="f7 mt2 mb0">{name}</p>
    </div>
  );
};
