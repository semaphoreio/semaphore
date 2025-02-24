
import { Outlet, useNavigate, useParams } from "react-router-dom";
import * as toolbox from "js/toolbox";
import { useContext, useEffect, useReducer, useState } from "preact/hooks";
import * as components from "js/agents/components";
import * as stores from "js/agents/stores";
import * as types from "js/agents/types";

// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
import { Notice } from "js/notice";

export const Layout = () => {
  const navigate = useNavigate();
  const config = useContext(stores.Config.Context);
  const [loading, setLoading] = useState(false);
  const { agent } = useParams();

  const [selfHostedAgent, dispatchSelfHostedAgent] = useReducer(
    stores.SelfHostedAgent.Reducer,
    stores.SelfHostedAgent.EmptyState
  );

  useEffect(() => {
    if (!selfHostedAgent.type && agent) {
      setLoading(true);
      types.SelfHosted.AgentType.get(config.selfHostedUrl, agent)
        .then((agentType) => {
          dispatchSelfHostedAgent({ type: `SET_AGENT_TYPE`, value: agentType });
          dispatchSelfHostedAgent({
            type: `SET_AGENTS`,
            value: agentType.agents,
          });
        })
        .catch(Notice.error)
        .finally(() => {
          setLoading(false);
        });
    }
  }, [selfHostedAgent.type, agent]);

  const setTokenRevealed = (value: boolean) => {
    if (value) {
      dispatchSelfHostedAgent({ type: `REVEAL_TOKEN` });
    } else {
      dispatchSelfHostedAgent({ type: `HIDE_TOKEN` });
    }
  };

  useEffect(() => {
    dispatchSelfHostedAgent({ type: `HIDE_TOKEN` });
  }, [selfHostedAgent._token]);

  return (
    <stores.SelfHostedAgent.Context.Provider
      value={{ state: selfHostedAgent, dispatch: dispatchSelfHostedAgent }}
    >
      <div className="bg-washed-gray mt4 pa3 pa4-l br3 ba b--black-075">
        <p className="mb3 pb1 measure-wide">
          <span
            onClick={() => {
              navigate(`/`);
            }}
            className="pointer gray underline"
          >
            ← Back to All agent types
          </span>
        </p>
        {!selfHostedAgent._typeJustCreated && selfHostedAgent._token != `` && (
          <div className="shadow-1 bg-washed-yellow pa3 mv4 br3">
            <p>
              The registration token was successfully set for{` `}
              <b>{selfHostedAgent.type.name}</b>. For your own security, we’ll
              show you the new token only once. Please, update the running
              agents configuration with the new token. After that, either
              restart all the agents manually or disable them all at once here.
            </p>
            {selfHostedAgent.tokenRevealed && (
              <components.PreCopy
                title={`Your token`}
                content={selfHostedAgent.token}
              />
            )}
            <p className="m0 mt2">
              <button
                className={`self-hosted-agent-access-token-reveal btn btn-small ${
                  selfHostedAgent.tokenRevealed ? `btn-secondary` : `btn-green`
                }`}
                onClick={() => {
                  setTokenRevealed(!selfHostedAgent.tokenRevealed);
                }}
              >
                {selfHostedAgent.tokenRevealed ? `Hide` : `Reveal`}
              </button>
            </p>
          </div>
        )}
        {!loading && <Outlet/>}
        {loading && <toolbox.Asset path="images/spinner.svg"/>}
      </div>
    </stores.SelfHostedAgent.Context.Provider>
  );
};
