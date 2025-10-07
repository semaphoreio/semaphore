import { Asset, MaterializeIcon } from "js/toolbox";
import { VNode } from "preact";
import { JSX } from "preact/jsx-runtime";
import * as types from "../types";
export const Loader = (props: { content?: string }) => {
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

interface StageIconProps extends Partial<JSX.HTMLAttributes<HTMLSpanElement>> {
  stageId: types.StageId;
}
export const StageIcon = (props: StageIconProps) => {
  const { stageId, className, ...rest } = props;
  let iconName = ``;
  switch (stageId) {
    case `provisioning`:
      iconName = `build_circle`;
      break;
    case `deployment`:
      iconName = `rocket_launch`;
      break;
    case `deprovisioning`:
      iconName = `delete_sweep`;
      break;
  }
  if (!iconName.length) {
    return;
  }
  return (
    <MaterializeIcon
      name={iconName}
      className={`${stageColors[stageId]} ${className?.toString()}`}
      {...rest}
    />
  );
};

export const stageColors: Record<types.StageId, string> = {
  provisioning: `blue`,
  deployment: `green`,
  deprovisioning: `orange`,
  "": `gray`,
};

interface EnvironmentSectionIconProps
  extends Partial<JSX.HTMLAttributes<HTMLSpanElement>> {
  sectionId: types.EnvironmentSectionId;
}
export const EnvironmentSectionIcon = (props: EnvironmentSectionIconProps) => {
  const { sectionId, ...rest } = props;
  let iconName = ``;
  switch (sectionId) {
    case `basics`:
      iconName = `info`;
      break;
    case `instances`:
      iconName = `cloud_queue`;
      break;
    case `project_access`:
      iconName = `folder`;
      break;
    case `context`:
      iconName = `code`;
      break;
    case `ttl`:
      iconName = `schedule`;
      break;
    case `pipeline`:
      iconName = `settings_input_component`;
      break;
  }
  if (!iconName.length) {
    return;
  }
  return <MaterializeIcon name={iconName} {...rest}/>;
};
