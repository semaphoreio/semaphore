import { Asset, MaterializeIcon } from "js/toolbox";
import { VNode } from "preact";
import { JSX } from "preact/jsx-runtime";
export const Loader = (props: { content?: string, }) => {
  return (
    <div className="tc pv5">
      <Asset path="images/spinner-2.svg" className="spinner"/>
      {props.content && <p className="mt3 gray">{props.content}</p>}
    </div>
  );
};

interface BadgeProps extends Partial<JSX.HTMLAttributes<HTMLDivElement>> {
  label: string | VNode;
  onDeselect?: () => void;
  icon?: string;
}
export const Badge = (props: BadgeProps) => {
  const { label, className = `bg-blue white`, onDeselect, icon } = props;
  return (
    <span
      className={`w-auto br2 ph1 flex items-center gap-1 ${className.toString()}`}
    >
      {icon && <MaterializeIcon name={icon}/>}
      <span>{label}</span>
      {onDeselect && (
        <MaterializeIcon
          name="close"
          className="pointer"
          onClick={(e) => {
            e.stopPropagation();
            onDeselect();
          }}
        />
      )}
    </span>
  );
};
