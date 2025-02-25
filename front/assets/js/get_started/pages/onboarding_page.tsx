import { createRef, Fragment } from "preact";
import { useContext, useEffect, useState } from "preact/hooks";
import * as stores from "../stores";
import * as types from "../types";
import { useNavigate, useParams } from "react-router-dom";
import { createPortal } from "preact/compat";
import * as toolbox from "js/toolbox";
import styled from "styled-components";

export const OnboardingPage = () => {
  const { state, dispatch } = useContext(stores.Onboarding.Context);
  const config = useContext(stores.Config.Context);
  const task = state.currentTask;

  const { taskId } = useParams();

  const navigate = useNavigate();

  const sections = state.learn.sections;

  const expandedSectionIds = sections
    .filter((section) => {
      if (section.hasTask(taskId)) {
        return true;
      }
      if (section.isCompleted()) {
        return false;
      }

      return true;
    })
    .slice(0, 2)
    .map((section) => section.id);

  let highlightedTaskIds: string[] = [];

  if (!taskId) {
    highlightedTaskIds = sections
      .filter((section) => {
        return section.getDefaultTask();
      })
      .slice(0, 1)
      .map((section) => section.getDefaultTask().id);
  }

  const signal = async (eventId: string, follow?: boolean) => {
    const url = new URL(config.signalUrl, location.origin);

    await toolbox.APIRequest.post(url, {
      event_id: eventId,
    }).then(({ data }) => {
      const learn = types.Onboarding.Learn.fromJSON((data as any).learn);

      dispatch({
        type: `SET_LEARN`,
        value: learn,
      });

      if (follow) {
        const task = learn.sections
          .flatMap((section) => section.getDefaultTask())
          .find((task) => task);

        if (task) {
          navigate(`/${task.id}`);
        } else {
          navigate(`/`);
        }
      }

      return learn;
    });
  };

  useEffect(() => {
    dispatch({ type: `SELECT_TASK`, value: taskId });
  }, [taskId]);

  return (
    <Fragment>
      <div
        className="bg-washed-gray pa3 br3 ba b--black-075"
        style="gap: 1rem;"
      >
        <div className="mw9 center flex">
          <div className="w-50 flex flex-column ma3" style="gap: 1rem;">
            {sections.map((section, idx) => (
              <Section
                key={idx}
                idx={idx}
                section={section}
                initiallyExpanded={expandedSectionIds.includes(section.id)}
                highlightedTaskIds={highlightedTaskIds}
              />
            ))}
          </div>
          <div
            className="w-50 ma3 self-start"
            style={{
              position: `sticky`,
              top: `60px`,
            }}
          >
            {task && <Details signal={signal}/>}
            {!task && <DetailsZeroState signal={signal}/>}
          </div>
        </div>
      </div>
    </Fragment>
  );
};

const Bullet = styled.div<{ $completed?: boolean, }>`
  text-align: center;
  position: relative;
  color: gray;
  & .point::before {
    width: 40px;
    height: 40px;
    content: ${(props) =>
    (props.$completed && `"check_circle"`) || `"radio_button_unchecked"`};
    font-family: "Material Symbols Outlined";
    font-size: 40px;
    line-height: 40px;
    margin: 0 auto 5px auto;
    display: block;
    color: ${(props) => (props.$completed && `#19a974`) || `#777`};
    background: white;
    position: relative;
    z-index: 2;
    font-variation-settings: ${(props) =>
    (props.$completed && `"FILL" 1`) || `"FILL" 0`};
  }
  &::after {
    display: flex;
    content: "";
    width: 100%;
    left: 50%;
    height: 2px;
    background-color: ${(props) => (props.$completed && `#19a974`) || `#777`};
    position: absolute;
    top: 20px;
    z-index: 1;
  }

  &:last-child::after {
    display: none;
  }
`;

const Progress = () => {
  const { state } = useContext(stores.Onboarding.Context);
  const steps = state.learn.steps;

  return (
    <div className="bb bw1 b--black-075 br--top br3 pa3">
      <div className="mt3 flex items-start justify-around ">
        {steps.map((step, idx) => (
          <Bullet
            $completed={step.completed}
            key={idx}
            className="flex items-center flex-column w-100"
          >
            <div className="point"></div>
            <span className={step.completed ? `green` : ``}>{step.title}</span>
            <div className="f6">{step.subtitle}</div>
          </Bullet>
        ))}
      </div>
    </div>
  );
};

interface DetailsZeroStateProps {
  signal: (eventId: string, follow?: boolean) => Promise<void>;
}

const DetailsZeroState = (props: DetailsZeroStateProps) => {
  const { state } = useContext(stores.Onboarding.Context);

  const ZeroStateCompleted = () => {
    return (
      <Fragment>
        <toolbox.Asset path="images/ill-guy-path-success.svg"/>
        <h4 className="f3 mt4 mb1">You did it! 🎉</h4>
        <p className="f5 mb2 measure center">
          You&apos;ve completed all tasks and mastered the essentials.
          We&apos;ll notify you when new features are available.
        </p>

        {!state.learn.isGuideFinished && !state.learn.isGuideSkipped && (
          <a
            href=""
            onClick={() => void props.signal(`onboarding.finished`)}
            className="dark-gray"
          >
            Complete guide
          </a>
        )}
      </Fragment>
    );
  };

  const ZeroState = () => {
    const skipGuide = async () => {
      const result = confirm(
        `Are you sure? The guide will be moved to the main menu`
      );
      if (result) {
        await props.signal(`onboarding.skipped`).then(() => {
          window.location.href = `/`;
        });
      }
    };

    return (
      <Fragment>
        <toolbox.Asset path="images/ill-tour-greeting.svg"/>
        <h4 className="f3 mt3 mb1">Let&apos;s get started! 👋</h4>
        <p className="f5 mb2 measure center">
          Complete each task to set up your organization and learn
          Semaphore&apos;s key features.
        </p>

        {!state.learn.isGuideSkipped && (
          <toolbox.Tooltip
            placement="top"
            content={
              <span>
                You can return to this guide anytime from the organization menu.
              </span>
            }
            anchor={
              <a onClick={() => void skipGuide()} className="btn btn-primary center">
                Skip guide
              </a>
            }
          />
        )}
      </Fragment>
    );
  };

  return (
    <div className="bg-white shadow-1 br3">
      <Progress/>
      <div className="pa3">
        <div className="tc pa5">
          {state.learn.isGuideCompleted ? (
            <ZeroStateCompleted/>
          ) : (
            <ZeroState/>
          )}
        </div>
      </div>
    </div>
  );
};
interface DetailsProps {
  signal: (eventId: string, follow?: boolean) => Promise<void>;
}

const Details = ({ signal }: DetailsProps) => {
  const { state } = useContext(stores.Onboarding.Context);
  const taskDescriptionRef = createRef();
  const [actionButton, setActionButton] = useState(null);
  const task = state.currentTask;

  const navigate = useNavigate();
  const closeTask = () => {
    navigate(`/`);
  };

  const Complete = () => {
    if (task.completed) {
      return (
        <div className="flex flex-column items-center">
          <span className="material-symbols-outlined f1 green">
            editor_choice
          </span>
          <span className="gray f6">Completed</span>
          <span className="gray f6">
            {toolbox.Formatter.dateFull(task.completedAt)}
          </span>
        </div>
      );
    }

    return (
      <a
        onClick={() => void signal(task.eventId, true)}
        className="btn btn-primary"
      >
        Complete
      </a>
    );
  };

  useEffect(() => {
    if (!taskDescriptionRef.current) return;

    const actionRef = document.getElementById(`complete-action`);
    if (!actionRef) return;

    setActionButton(createPortal(<Complete/>, actionRef));
  }, [task]);

  return (
    <div className="bg-white shadow-1 br3 relative">
      <Progress/>
      <div className="fr ma3 pr2 flex hover-black gray pointer ">
        <toolbox.Tooltip
          placement="top"
          content={<span>Close task details</span>}
          anchor={
            <span onClick={closeTask} className="material-symbols-outlined f3">
              close
            </span>
          }
        />
      </div>
      <div
        ref={taskDescriptionRef}
        className="pa3"
        dangerouslySetInnerHTML={{
          __html: task.description,
        }}
      ></div>
      {actionButton}
    </div>
  );
};

interface SectionProps {
  section: types.Onboarding.Section;
  idx: number;
  initiallyExpanded: boolean;
  highlightedTaskIds: string[];
}
const Section = ({
  section,
  idx,
  initiallyExpanded,
  highlightedTaskIds,
}: SectionProps) => {
  const [expanded, setExpanded] = useState(initiallyExpanded);

  useEffect(() => {
    if (initiallyExpanded) {
      setExpanded(true);
    }
  }, [initiallyExpanded]);

  const toggleExpanded = (e: Event) => {
    e.preventDefault();
    e.stopPropagation();
    setExpanded(!expanded);
  };

  const order = idx + 1;

  const SectionDetails = () => {
    return (
      <Fragment>
        <div className="ph3 pv2 bt bw1 b--black-075 gray">
          {section.description}
        </div>
        {section.tasks.map((task, idx) => (
          <Task
            key={idx}
            task={task}
            highlighted={highlightedTaskIds.includes(task.id)}
          />
        ))}
      </Fragment>
    );
  };

  const StatusIcon = () => {
    if (section.isCompleted()) {
      return (
        <span
          className="material-symbols-outlined pr2 green"
          style={`font-variation-settings: 'FILL' 1;`}
        >
          verified
        </span>
      );
    }

    return (
      <Fragment>
        <span className="gray f5 pr2">{section.duration}</span>
        <span
          className="material-symbols-outlined pr2 gray"
          style={`font-variation-settings: 'FILL' 1;`}
        >
          pace
        </span>
      </Fragment>
    );
  };

  return (
    <div className="bg-white shadow-1 br3">
      <div
        className="flex items-center justify-between br3 br--top pa3 pointer"
        onClick={toggleExpanded}
      >
        <div className="flex items-center">
          <span className="material-symbols-outlined pr2">counter_{order}</span>
          <div className="b">{section.name}</div>
        </div>
        <div className="flex items-center">
          <StatusIcon/>
          <span className="material-symbols-outlined pr2 toggle-icon">
            {expanded ? `keyboard_arrow_up` : `keyboard_arrow_down`}
          </span>
        </div>
      </div>
      {expanded && <SectionDetails/>}
    </div>
  );
};

interface TaskProps {
  task: types.Onboarding.Task;
  highlighted: boolean;
}
const Task = ({ task, highlighted }: TaskProps) => {
  const { taskId } = useParams();
  const currentTask = task.id == taskId;
  const navigate = useNavigate();

  const nav = (id: string) => {
    if (task.isSelectable()) {
      return () => navigate(`/${id}`);
    }
  };

  const taskClasses = (): string => {
    if (task.isCompleted()) {
      `bg-green`;
    }
    if (currentTask) {
      return `bg-lightest-gray`;
    }

    return `hover-bg-lightest-gray`;
  };

  const Icon = () => {
    let icon = `radio_button_unchecked`;
    let color = `gray`;

    if (task.isCompleted()) {
      icon = `task_alt`;
    } else if (task.isLocked()) {
      icon = `lock`;
    } else if (currentTask) {
      icon = `sticky_note_2`;
    }

    if (task.isCompleted()) {
      color = `green`;
    }

    return (
      <span className={`material-symbols-outlined ${color} f4 b`}>{icon}</span>
    );
  };

  let classes = ``;

  if (task.isCompleted()) {
    classes += `strike gray`;
  }

  let style = ``;
  if (highlighted && !currentTask) {
    style = `box-shadow: 0 0 0 3px #00359f !important;`;
  }

  const anchor = (
    <div
      className={`flex items-center pointer ph3 pv1 mv1 mh2 br3 ${taskClasses()}`}
      style={style}
      onClick={nav(task.id)}
    >
      <Icon></Icon>
      <div
        className={`ml2 ${classes}`}
        dangerouslySetInnerHTML={{ __html: task.name }}
      ></div>
    </div>
  );

  if (task.isLocked()) {
    return (
      <toolbox.Tooltip
        placement="top"
        content={<span>Complete previous chapter to unlock</span>}
        anchor={anchor}
      />
    );
  }

  return anchor;
};
