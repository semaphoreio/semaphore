import { h, Fragment } from "preact";
import { useContext } from "preact/hooks";
import * as stores from "../stores";
import { useNavigate } from "react-router-dom";
import styled from "styled-components";
import * as toolbox from "js/toolbox";

const SelectableAgent = styled.div`
  &:hover {
    box-shadow: 0 0 0 3px #00359f;
    border-radius: 3px;
  }
`;

export const SelfHostedList = () => {
  const {
    state: { selfHostedAgents },
  } = useContext(stores.Activity.Context);
  const navigate = useNavigate();
  const config = useContext(stores.Config.Context);

  if (config.featureProvider.is(`self_hosted_agents`, `disabled`)) return;

  const ZeroState = () => {
    return (
      <div className="bb b--black-10">
        <h3 className="b mb2">Self-Hosted Agents</h3>
        <div className="mb3">
          <p className="mb0 measure-wide">
            Host your own agents and customize the environment used to run jobs
            in your Semaphore workflows. Read more in{` `}
            <a
              href={`https://${config.docsDomain}/ci-cd-environment/self-hosted-agents-overview`}
              target="_blank"
              rel="noreferrer"
            >
              Docs: Self-Hosted Agents
            </a>
          </p>
        </div>

        <div className="pv3 tc">
          <div className="f00">🗝</div>
          <p className="f6 measure-narrow center mv3">
            Sorry, your organization does not have access to self-hosted agents.
          </p>
        </div>
      </div>
    );
  };

  if (config.featureProvider.is(`self_hosted_agents`, `zero`))
    return <ZeroState/>;
  const EmptyList = () => {
    return (
      <div className="tc pt5 pb6 w-100">
        <toolbox.Asset path="images/profile-bot-mono.svg" class="w3"/>
        <h4 className="f4 mt2 mb1">No agent connected yet</h4>
        <p className="mb0 measure center">
          Connect your first agent to start building on your own machines.
        </p>
        {config.accessProvider.canManageAgents() && (
          <div className="mt3">
            <a
              className="btn btn-primary"
              onClick={() => navigate(`/self_hosted/new`)}
            >
              Add your first self-hosted agent
            </a>
          </div>
        )}
      </div>
    );
  };

  return (
    <div className="bb b--black-10">
      <h3 className="b mb2">Self-Hosted Agents</h3>
      <div className="mb3">
        <p className="mb0">
          Your connected machine resources available for use within this
          Semaphore organization.
        </p>
      </div>
      <div className="flex flex-wrap mb4 nh2">
        {selfHostedAgents.length === 0 && <EmptyList/>}
        {selfHostedAgents.length !== 0 && (
          <Fragment>
            {selfHostedAgents.map((agent, idx) => (
              <SelectableAgent
                key={idx}
                className={`w5-ns pa3 br3 mh2 mb3 hover-border-black bg-white shadow-1 dark-gray pointer`}
                onClick={() => navigate(`/self_hosted/${agent.name}`)}
              >
                <AgentItem item={agent}/>
              </SelectableAgent>
            ))}
            {config.accessProvider.canManageAgents() && (
              <a
                onClick={() => navigate(`/self_hosted/new`)}
                className="w5-ns link shadow-1 pa3 br3 mh2 mb3 flex items-center justify-center btn-primary pointer"
              >
                <span className="material-symbols-outlined mr1 f2 b">add</span>
                <span className="f3 b">Create new</span>
              </a>
            )}
          </Fragment>
        )}
      </div>
    </div>
  );
};

export const HostedList = () => {
  const {
    state: { hostedAgents },
  } = useContext(stores.Activity.Context);

  const config = useContext(stores.Config.Context);
  if (config.featureProvider.is(`expose_cloud_agent_types`, `disabled`)) return;
  return (
    <div className="pt4 bb b--black-10">
      <h3 className="b mb2">Cloud Agents</h3>
      <div className="mb3">
        <p className="mb0">
          Cloud-hosted machine resources available for use within this Semaphore
          organization.
        </p>
      </div>
      <div className="flex flex-wrap mb4 nh2">
        {hostedAgents.map((agent, idx) => (
          <div
            key={idx}
            className={`w5-ns pa3 br3 mh2 mb3 hover-border-black bg-white shadow-1 dark-gray`}
          >
            <AgentItem item={agent}/>
          </div>
        ))}
      </div>
    </div>
  );
};

interface AgentItemProps extends h.JSX.HTMLAttributes {
  item: stores.Activity.Agent;
}

const AgentItem = (props: AgentItemProps) => {
  const agent = props.item;
  let percentage =
    agent.totalCount != 0 ? (agent.occupiedCount / agent.totalCount) * 100 : 0;

  if (percentage > 100) percentage = 100;
  const counterClass = agent.occupiedCount > 0 ? `green` : `mid-gray`;

  return (
    <Fragment>
      <h2 className="f4 mb0 lh-title">{agent.name}</h2>
      <h3 className={`f1 mb1 ${counterClass} flex items-center`}>
        {agent.occupiedCount}/{agent.totalCount}
        {agent.waitingCount > 0 && (
          <span className="f5 fw5 bg-yellow black-60 ph1 br1 ml2">
            + {agent.waitingCount} waiting
          </span>
        )}
      </h3>
      <div className="meter">
        <span style={{ width: `${percentage}%` }}></span>
      </div>
    </Fragment>
  );
};
