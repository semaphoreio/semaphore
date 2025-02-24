
import { useNavigate } from "react-router-dom";
import { useContext, useState } from "preact/hooks";
import * as stores from "js/agents/stores";

// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
import { Notice } from "js/notice";
import { TargetedEvent } from "preact/compat";

export const DisableAll = () => {
  const navigate = useNavigate();

  const { state } = useContext(stores.SelfHostedAgent.Context);
  const config = useContext(stores.Config.Context);
  const [onlyIdleAgents, setOnlyIdleAgents] = useState(true);

  const disableAgents = () => {
    state.type
      .disableAllAgents(config.selfHostedUrl, onlyIdleAgents)
      .then((message) => {
        Notice.notice(message);
        Notice.setTimoutForNotice();
        navigate(`..`);
      })
      .catch(Notice.error);
  };

  const onIdleAgentsChange = (e: TargetedEvent) => {
    const target = e.currentTarget as HTMLInputElement;
    const value = target.value === `true`;
    setOnlyIdleAgents(value);
  };

  return (
    <div className="bg-white shadow-1 br3 pa3 pa4-l mb3">
      <h3 className="f3 f2-m mb1">Disable agents for {state.type.name}?</h3>
      <p className="red mt2 mb3">Proceed carefully, this cannot be undone!</p>
      <div className="mw6">
        <div className="mt3">
          <div className="flex items-center">
            <label className="ml2">
              <input
                onChange={(e) => {
                  onIdleAgentsChange(e);
                }}
                name="onlyIdleAgents"
                type="radio"
                value="true"
                className="mr1"
                checked={onlyIdleAgents}
              />
              Disable all idle agents
            </label>
          </div>
          <div className="flex items-center">
            <label className="ml2">
              <input
                onChange={(e) => {
                  onIdleAgentsChange(e);
                }}
                name="onlyIdleAgents"
                type="radio"
                value="false"
                className="mr1"
                checked={!onlyIdleAgents}
              />
              Disable all{` `}
              <span className="gray">(some of them might be running jobs)</span>
            </label>
          </div>
          <div className="mw6 mt3">
            <button className="btn btn-danger mr2" onClick={disableAgents}>
              Disable agents
            </button>
            <button
              className="btn btn-secondary"
              onClick={() => navigate(`..`)}
            >
              Nevermind
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
