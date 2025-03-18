import { Fragment, h, VNode } from "preact";
import { useContext, useState } from "preact/hooks";
import * as stores from "../stores";
import * as toolbox from "js/toolbox";

interface ActivityItemProps {
  item: stores.Activity.Item;
  inLobby?: boolean;
}

export const ActivityItem = (props: ActivityItemProps) => {
  const config = useContext(stores.Config.Context);
  const [showStop, setShowStop] = useState(false);
  const item = props.item;
  const [transitionState, setTransitionState] = useState<PipelineState>(`idle`);

  const transitionTo = (state: PipelineState) => {
    setTransitionState(state);
    if (state === `stopping`) {
      void stopActivity();
    }
  };

  const stopActivity = async () => {
    await toolbox.APIRequest.post(config.activityStopUrl, {
      item_type: item.itemType,
      item_id: item.itemId,
    });
  };

  return (
    <Fragment>
      {item.itemType == `Pipeline` && (
        <PipelineActivity
          className="bg-white shadow-1 mv3 ph3 pv2 br3 relative"
          onMouseOver={() => setShowStop(true)}
          onMouseOut={() => setShowStop(false)}
          inLobby={props.inLobby}
          item={item}
        >
          {showStop && (
            <StopPipeline state={transitionState} setState={transitionTo}/>
          )}
        </PipelineActivity>
      )}
      {item.itemType == `Debug Session` && (
        <DebugActivity
          className="bg-white shadow-1 mv3 ph3 pv2 br3 relative"
          onMouseOver={() => setShowStop(true)}
          onMouseOut={() => setShowStop(false)}
          inLobby={props.inLobby}
          item={item}
        >
          {showStop && (
            <StopPipeline state={transitionState} setState={transitionTo}/>
          )}
        </DebugActivity>
      )}
    </Fragment>
  );
};

interface ActivityProps extends h.JSX.HTMLAttributes {
  item: stores.Activity.Item;
  inLobby?: boolean;
}
const PipelineActivity = (props: ActivityProps) => {
  const item = props.item;
  return (
    <div className="bg-white shadow-1 mv3 ph3 pv2 br3 relative">
      <div className="flex items-center bb b--black-10 pb2 mb2">
        <RefTypeIcon
          refType={item.refType}
          width="16"
          height="16"
          className="flex-shrink-0 mr2 dn db-l"
        />
        <div>
          <a
            href={item.refPath}
            className="link dark-gray word-wrap underline-hover b"
          >
            {item.refName}
          </a>
          <span className="f5"> from project </span>
          <a className="f5" href={item.projectPath}>
            {item.projectName}
          </a>
        </div>
      </div>
      <div className="flex-l pv1">
        <div className="w-75-l pr4-l mb2 mb1-l">
          <div className="flex">
            <div className="flex-shrink-0 mr2 dn db-l">
              <toolbox.Asset
                path="images/icn-commit.svg"
                className="mt1"
                width="16"
              />
            </div>
            <div className="flex-auto">
              <div>
                <a href={item.workflowPath} className="word-wrap">
                  {item.title}
                </a>
              </div>
              {props.inLobby ? <LobbySummary/> : <JobSummary item={item}/>}
            </div>
          </div>
        </div>
        <div className="w-25-l">
          <div className="flex flex-row-reverse-l items-center">
            <img
              src={item.userIconPath}
              className="db br-100 ba b--black-50"
              width="32"
              height="32"
            />
            <div className="f5 gray ml2 ml3-m ml0-l mr3-l tr-l">
              <time-ago datetime={item.createdAt}/>
              <br/> by {item.userName}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export const DebugActivity = (props: ActivityProps) => {
  const JobDebugInfo = () => {
    return (
      <Fragment>
        <div>
          <span>Debugging </span>
          <a
            href={props.item.debugJobPath}
            target="_blank"
            className="word-wrap"
            rel="noreferrer"
          >
            {props.item.debugJobName}
          </a>
          <span> from </span>
          <a
            href={props.item.workflowPath}
            target="_blank"
            className="word-wrap"
            rel="noreferrer"
          >
            {props.item.workflowName}
          </a>
          <span> / </span>
          <a
            href={props.item.pipelinePath}
            target="_blank"
            className="word-wrap"
            rel="noreferrer"
          >
            {props.item.pipelineName}
          </a>
        </div>
        <div className="f5 mt1">
          <a
            href={props.item.refPath}
            className="link dark-gray word-wrap underline-hover"
          >
            {props.item.refName}
          </a>
          <span className="gray"> from </span>
          <a
            href={props.item.projectPath}
            className="link dark-gray word-wrap underline-hover"
          >
            {props.item.projectName}
          </a>
        </div>
      </Fragment>
    );
  };

  const ProjectDebugInfo = () => {
    return (
      <Fragment>
        <div>
          <span>Debugging</span>
          <a
            href={props.item.projectPath}
            className="link dark-gray word-wrap underline-hover"
          >
            {props.item.projectName}
          </a>
        </div>
      </Fragment>
    );
  };

  return (
    <div
      className={`${String(props.className)}pv2 bt b--lighter-gray hover-bg-row-highlight relative`}
      onMouseOver={props.onMouseOver}
      onMouseOut={props.onMouseOut}
    >
      {props.children}

      <div className="flex-l pv1">
        <div className="w-75-l pr4-l mb2 mb1-l">
          <div className="flex">
            <div className="flex-shrink-0 mr2 dn db-l">
              <toolbox.Asset path="images/icn-console.svg" className="mt1"/>
            </div>
            <div className="flex-auto">
              {props.item.debugType == `Job` && <JobDebugInfo/>}
              {props.item.debugType == `Project` && <ProjectDebugInfo/>}

              {props.inLobby && <LobbySummary/>}
              {!props.inLobby && <JobSummary item={props.item}/>}
            </div>
          </div>
        </div>
        <div className="w-25-l">
          <div className="flex flex-row-reverse-l items-center">
            <img
              src={props.item.userIconPath}
              className="db br-100 ba b--black-50"
              width="32"
              height="32"
            />
            <div className="f5 gray ml2 ml3-m ml0-l mr3-l tr-l">
              <time-ago datetime={props.item.createdAt}/>
              <br/> by {props.item.userName}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

const LobbySummary = () => {
  return (
    <div className="f5 mt1">
      <span className="fw5 bg-mid-gray white ph1 br1">In the lobby</span>
    </div>
  );
};

interface JobSummaryProps {
  item: stores.Activity.Item;
}

const JobSummary = (props: JobSummaryProps) => {
  const item = props.item;
  const jobPlural = (count: number) => toolbox.Pluralize(count, `job`, `jobs`);

  const WorkflowStats = () => {
    const runningCount = item.jobStats.runningCount;
    const waitingCount = item.jobStats.waitingCount;
    const leftCount = item.jobStats.leftCount;

    const labels: VNode[] = [];

    if (runningCount > 0) {
      labels.push(
        <span className="fw5 bg-green white ph1 br1 mr1">
          {jobPlural(runningCount)} running
        </span>
      );
    }

    if (waitingCount > 0) {
      const showLabel = runningCount == 0;
      labels.push(
        <span className="fw5 bg-yellow black-60 ph1 br1 mr1">
          {showLabel ? jobPlural(waitingCount) : waitingCount} waiting
        </span>
      );
    }

    if (leftCount > 0) {
      const showLabel = runningCount == 0 && waitingCount == 0;
      labels.push(
        <span className="fw5 bg-mid-gray white ph1 br1 mr1">
          {showLabel ? jobPlural(leftCount) : leftCount} left
        </span>
      );
    }

    return <Fragment>{labels}</Fragment>;
  };

  let description = ``;

  if (item.jobStats.getMachineTypes().length == 1) {
    description = `on ${item.jobStats.getMachineTypes()[0]}`;
  } else if (item.jobStats.getMachineTypes().length > 1) {
    const descriptionItems = [];
    for (const type of item.jobStats.getMachineTypes()) {
      const waitingCount = item.jobStats.getWaitingCount(type);
      const runningCount = item.jobStats.getRunningCount(type);

      if (waitingCount > 0 && runningCount > 0) {
        descriptionItems.push(
          `${type} (${runningCount} running, ${waitingCount} waiting)`
        );
        continue;
      }

      if (waitingCount > 0) {
        descriptionItems.push(`${type} (${waitingCount} waiting)`);
        continue;
      }

      if (runningCount > 0) {
        descriptionItems.push(`${type} (${runningCount} running)`);
        continue;
      }
    }

    description = `on ${descriptionItems.join(`, `)}`;
  }

  return (
    <div className="f5 mt1">
      <span className="gray">
        <WorkflowStats/>
        {description}
      </span>
    </div>
  );
};

type PipelineState = `idle` | `confirm` | `stopping`;

interface StopPipelineProps {
  state: PipelineState;
  setState: (state: PipelineState) => void;
}
const StopPipeline = (props: StopPipelineProps) => {
  const content = () => {
    switch (props.state) {
      case `idle`:
        return (
          <div className="shadow-1 bg-white f6 br2 pa1">
            <button
              onClick={() => props.setState(`confirm`)}
              className="input-reset pv1 ph2 br2 bg-transparent hover-bg-red hover-white bn pointer"
            >
              Stop…
            </button>
          </div>
        );
      case `confirm`:
        return (
          <div className="shadow-1 bg-white f6 br2 pa1">
            <span className="ph1">Are you sure?</span>
            <button
              onClick={() => props.setState(`idle`)}
              className="input-reset pv1 ph2 br2 bg-gray white bn pointer mh1"
            >
              Nevermind
            </button>
            <button
              onClick={() => props.setState(`stopping`)}
              className="input-reset pv1 ph2 br2 bg-red white bn pointer"
            >
              Stop
            </button>
          </div>
        );
      case `stopping`:
        return (
          <div className="shadow-1 bg-white f6 br2 pa1">
            <span className="ph2">Stopping...</span>
          </div>
        );
    }
  };

  return (
    <div className="child absolute top-0 right-0 z-5 nt2 mr3">{content()}</div>
  );
};

interface RefTypeIconProps extends h.JSX.ImgHTMLAttributes {
  refType: string;
}

const RefTypeIcon = ({
  refType,
  ...props
}: RefTypeIconProps) => {
  switch (refType) {
    case `Pull request`:
      return <toolbox.Asset path="images/icn-pull-request.svg" {...props}/>;
    case `Tag`:
      return <toolbox.Asset path="images/icn-tag.svg" {...props}/>;
    default:
    case `Branch`:
      return <toolbox.Asset path="images/icn-branch.svg" {...props}/>;
  }
};
