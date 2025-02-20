import { Fragment, h } from "preact";
import { Outlet, useLocation, useNavigate } from "react-router-dom";
import * as toolbox from "js/toolbox";
import { useContext, useEffect, useState } from "preact/hooks";
import * as components from "js/agents/components";
import * as stores from "js/agents/stores";
import * as types from "js/agents/types";
import moment from "moment";

// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
import { Notice } from "js/notice";

export const Agent = () => {
  const { state, dispatch: dispatchSelfHostedAgent } = useContext(
    stores.SelfHostedAgent.Context
  );
  const navigate = useNavigate();
  const selfHostedAgent = state.type;
  const [showGuide, setShowGuide] = useState(false);
  const config = useContext(stores.Config.Context);

  const refreshPeriod = config.refreshPeriod || 5000;

  const [refreshing, setRefreshing] = useState(false);

  const toggleInstructions = () => setShowGuide(!showGuide);

  if (!selfHostedAgent) return;

  const { state: locationState } = useLocation();
  const targetId = locationState?.targetId as string;

  useEffect(() => {
    if (state.type && state.type.totalAgentCount === 0) {
      setShowGuide(true);
    }
  }, [state.type.totalAgentCount]);

  useEffect(() => {
    const el = document.getElementById(targetId);
    if (el) {
      el.scrollIntoView();
    }
  }, [targetId]);

  const refreshActivity = async () => {
    setRefreshing(true);
    try {
      await types.SelfHosted.AgentType.get(
        config.selfHostedUrl,
        state.type.name
      )
        .then((agentType) => {
          dispatchSelfHostedAgent({
            type: `SET_AGENT_TYPE`,
            value: agentType,
          });
          dispatchSelfHostedAgent({
            type: `SET_AGENTS`,
            value: agentType.agents,
          });
        })
        .catch(Notice.error);
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error(e);
    } finally {
      setRefreshing(false);
    }
  };

  useEffect(() => {
    const interval = setInterval(() => {
      if (refreshing) {
        return;
      } else {
        void refreshActivity();
      }
    }, refreshPeriod);
    return () => clearInterval(interval);
  }, [refreshing]);

  const EmptyList = () => {
    return (
      <div className="bg-white shadow-1 br3 pa3 pa4-l mb3">
        <p className="f5 gray mv0">
          No agents are currently connected to this agent type.
        </p>
      </div>
    );
  };

  return (
    <Fragment>
      <div className="flex items-center justify-between mb2" id="agents-header">
        <div className="flex items-center">
          <toolbox.Asset path="images/icn-self-hosted.svg" className="db mr2"/>
          <h1 className="f3 f2-m mb0">{selfHostedAgent.name}</h1>
        </div>
        {config.accessProvider.canManageAgents() && (
          <div>
            <button
              onClick={() => navigate(`settings`)}
              className="btn btn-secondary mr2"
            >
              Settings
            </button>
            <button
              onClick={() => navigate(`reset`)}
              className="btn btn-secondary mr2"
            >
              Reset token
            </button>
            <button
              onClick={() => navigate(`disable_all`)}
              className="btn btn-secondary mr2"
            >
              Disable all
            </button>
            <button
              onClick={() => navigate(`delete`)}
              className="btn btn-danger"
            >
              Delete
            </button>
          </div>
        )}
        {!config.accessProvider.canManageAgents() && (
          <div>
            <toolbox.Tooltip
              content="You do not have permission to manage agents"
              anchor={
                <button className="btn btn-secondary mr2" disabled>
                  Edit
                </button>
              }
            />
            <toolbox.Tooltip
              content="You do not have permission to manage agents"
              anchor={
                <button className="btn btn-secondary mr2" disabled>
                  Reset token
                </button>
              }
            />

            <toolbox.Tooltip
              content="You do not have permission to manage agents"
              anchor={
                <button className="btn btn-secondary mr2" disabled>
                  Disable all
                </button>
              }
            />
            <toolbox.Tooltip
              content="You do not have permission to manage agents"
              anchor={
                <button className="btn btn-danger" disabled>
                  Delete
                </button>
              }
            />
          </div>
        )}
      </div>
      <div>
        <Outlet/>
      </div>
      <h2 className="f4 normal gray mb3">
        <span id="self-hosted-agents-count">
          <span className="green">
            {toolbox.Pluralize(
              selfHostedAgent.totalAgentCount,
              `connected agent`,
              `connected agents`
            )}
          </span>
        </span>
        <span className="mh1">&middot;</span>
        <span className="pointer link underline" onClick={toggleInstructions}>
          How to start an agent?
        </span>
      </h2>
      {showGuide && <components.SelfHosted.InstallationInstructions/>}
      <div>
        {selfHostedAgent.agents.length === 0 && <EmptyList/>}
        {selfHostedAgent.agents.map((agent, idx) => (
          <ConnectedAgent key={idx} agent={agent}/>
        ))}
      </div>
    </Fragment>
  );
};

interface ConnectAgentProps {
  agent: types.SelfHosted.Agent;
}
const ConnectedAgent = (props: ConnectAgentProps) => {
  const config = useContext(stores.Config.Context);
  const { state: selfHostedState } = useContext(stores.SelfHostedAgent.Context);
  const [showStop, setShowStop] = useState(false);
  const [transitionState, setTransitionState] = useState<AgentState>(`running`);

  const transitionTo = (state: AgentState) => {
    setTransitionState(state);
    if (state === `stopping`) {
      void disableAgent();
    }
  };
  const disableAgent = async () => {
    await toolbox.APIRequest.post(
      `${config.selfHostedUrl}/${selfHostedState.type.name}/agents/${agent.name}/disable?format=json`
    );
  };

  const agent = props.agent;

  return (
    <div
      className="shadow-1 bg-white pa3 mv3 br3 relative"
      onMouseOver={() => setShowStop(true)}
      onMouseOut={() => setShowStop(false)}
    >
      {showStop && (
        <StopAgent state={transitionState} setState={transitionTo}/>
      )}
      <div className="pl2-l">
        <div className="flex-l items-center justify-between">
          <h3 className="f4 mb1">
            <span className="green mr1">●</span>
            {agent.name}
          </h3>
          <div className="f5 gray mb0">
            <span className="ml1">{agent.version} ·</span>
            <span className="ml1" title={agent.connectedAt.toString()}>
              Connected {moment(agent.connectedAt).fromNow()} ·
            </span>
          </div>
        </div>
        <div className="f5 gray mb0">
          {agent.os} · {agent.ipAddress} · PID: {agent.pid}
        </div>
      </div>
    </div>
  );
};

type AgentState = `running` | `confirm` | `stopping`;

interface StopAgentProps {
  state: AgentState;
  setState: (state: AgentState) => void;
}
const StopAgent = (props: StopAgentProps) => {
  const content = () => {
    switch (props.state) {
      case `running`:
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
              onClick={() => props.setState(`running`)}
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
