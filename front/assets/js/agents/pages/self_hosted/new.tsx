import { Fragment, h } from "preact";
import { useNavigate } from "react-router-dom";
import * as toolbox from "js/toolbox";
import { useContext, useState } from "preact/hooks";
import * as stores from "js/agents/stores";
import * as types from "js/agents/types";

// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
import { Notice } from "js/notice";

export const New = () => {
  const navigate = useNavigate();
  const [agentName, setAgentName] = useState(``);
  const [loading, setLoading] = useState(false);
  const config = useContext(stores.Config.Context);
  const { dispatch: dispatchSelfHostedAgent } = useContext(
    stores.SelfHostedAgent.Context
  );

  const createAgent = () => {
    setLoading(true);

    return new types.SelfHosted.AgentType(agentName)
      .create(config.selfHostedUrl)
      .then((agentType) => {
        dispatchSelfHostedAgent({ type: `SET_AGENT_TYPE`, value: agentType });
        dispatchSelfHostedAgent({ type: `SET_TOKEN`, value: agentType.token });

        dispatchSelfHostedAgent({ type: `JUST_CREATED` });
        navigate(`/self_hosted/${agentType.name}`);
      })
      .catch(Notice.error)
      .finally(() => {
        setLoading(false);
      });
  };

  const updateAgentName = (e: Event) => {
    const target = e.currentTarget as HTMLInputElement;
    const name = target.value;

    setAgentName(name.replace(/[^a-z0-9-_]/gi, `-`));
  };

  return (
    <Fragment>
      <div className="mb4">
        <h1 className="f3 mb0">New Self-Hosted Agent Type</h1>
        <p className="mb0">
          Register and run multiple instances in this agent type
        </p>
      </div>
      <div className="bg-white shadow-1 br3">
        <div className="pa3 pa4-l">
          <div className="flex">
            <div className="mr4">
              <toolbox.Asset
                path="images/icn-self-hosted.svg"
                className="db mb2 w2 h2"
              />
            </div>
            <div className="flex-auto">
              <div className="flex items-center mb2">
                <div className="bg-white pl2 pr1 pv1 bl bt bb br3 br--left b--light-gray">
                  s1-
                </div>
                <input
                  className="form-control br--right"
                  placeholder="e.g. one-fine-agent-type"
                  size={40}
                  value={agentName}
                  onInput={(e) => updateAgentName(e)}
                />
              </div>
              <p className="f6 mb3">
                No spaces, please. Will be registered as:{` `}
                <strong>s1-{agentName}</strong>
              </p>

              <button
                onClick={() => void createAgent()}
                className="btn btn-primary"
                disabled={loading || !agentName}
              >
                Looks Good, Register
                {loading && (
                  <toolbox.Asset path="images/spinner.svg" className="ml1"/>
                )}
              </button>

              <button
                onClick={() => navigate(`/`)}
                className="btn btn-secondary ml2"
              >
                Cancel
              </button>

              <p className="measure mb0 mt3">
                Next, you’ll get the instructions on how to set up and run an
                agent on your own infrastructure.
              </p>
            </div>
          </div>
        </div>
      </div>
    </Fragment>
  );
};

export const NewAgentPage = () => {
  const navigate = useNavigate();
  const [agentName, setAgentName] = useState(``);
  const [loading, setLoading] = useState(false);
  const config = useContext(stores.Config.Context);
  const { dispatch: dispatchSelfHostedAgent } = useContext(
    stores.SelfHostedAgent.Context
  );

  const createAgent = () => {
    setLoading(true);

    return new types.SelfHosted.AgentType(agentName)
      .create(config.selfHostedUrl)
      .then((agentType) => {
        dispatchSelfHostedAgent({ type: `SET_AGENT_TYPE`, value: agentType });
        dispatchSelfHostedAgent({ type: `SET_TOKEN`, value: agentType.token });

        dispatchSelfHostedAgent({ type: `JUST_CREATED` });
        navigate(`/self_hosted/${agentType.name}`);
      })
      .catch(Notice.error)
      .finally(() => {
        setLoading(false);
      });
  };

  const updateAgentName = (e: Event) => {
    const target = e.currentTarget as HTMLInputElement;
    const name = target.value;

    setAgentName(name.replace(/[^a-z0-9-_]/gi, `-`));
  };

  return (
    <Fragment>
      <div className="mb4">
        <h1 className="f3 mb0">New Self-Hosted Agent Type</h1>
        <p className="mb0">
          Register and run multiple instances in this agent type
        </p>
      </div>
      <div className="bg-white shadow-1 br3">
        <div className="pa3 pa4-l">
          <div className="flex">
            <div className="mr4">
              <toolbox.Asset
                path="images/icn-self-hosted.svg"
                className="db mb2 w2 h2"
              />
            </div>
            <div className="flex-auto">
              <div className="flex items-center mb2">
                <div className="bg-white pl2 pr1 pv1 bl bt bb br3 br--left b--light-gray">
                  s1-
                </div>
                <input
                  className="form-control br--right"
                  placeholder="e.g. one-fine-agent-type"
                  size={40}
                  value={agentName}
                  onInput={(e) => updateAgentName(e)}
                />
              </div>
              <p className="f6 mb3">
                No spaces, please. Will be registered as:{` `}
                <strong>s1-{agentName}</strong>
              </p>

              <button
                onClick={() => void createAgent()}
                className="btn btn-primary"
                disabled={loading || !agentName}
              >
                Looks Good, Register
                {loading && (
                  <toolbox.Asset path="images/spinner.svg" className="ml1"/>
                )}
              </button>

              <button
                onClick={() => navigate(`/`)}
                className="btn btn-secondary ml2"
              >
                Cancel
              </button>

              <p className="measure mb0 mt3">
                Next, you’ll get the instructions on how to set up and run an
                agent on your own infrastructure.
              </p>
            </div>
          </div>
        </div>
      </div>
    </Fragment>
  );
};
