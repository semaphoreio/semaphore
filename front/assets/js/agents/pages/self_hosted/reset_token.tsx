
import { useNavigate } from "react-router-dom";
import { useContext, useState } from "preact/hooks";
import * as stores from "js/agents/stores";

// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
import { Notice } from "js/notice";

export const ResetToken = () => {
  const [disconnectRunningAgents, setDisconnectRunningAgents] = useState(false);
  const navigate = useNavigate();
  const config = useContext(stores.Config.Context);
  const { state, dispatch } = useContext(stores.SelfHostedAgent.Context);

  const resetToken = async () => {
    const agentType = state.type;
    await agentType
      .resetToken(config.selfHostedUrl, disconnectRunningAgents)
      .then((token) => {
        navigate(`..`);
        dispatch({ type: `SET_TOKEN`, value: token });
        dispatch({ type: `JUST_RESET` });
        Notice.notice(`Token reset successfully`);
      })
      .catch(Notice.error);
  };

  return (
    <div className="bg-white shadow-1 br3 pa3 pa4-l mb3">
      <h3 className="f3 f2-m mb1">Reset token for {state.type.name}?</h3>
      <p className="b red mv3">This cannot be undone!</p>
      <div>
        If you continue:
        <ul className="mt2">
          <li>
            You won&apos;t be able to start agents of this type with the old
            registration token anymore
          </li>
          <li>
            The current running agents will remain working. However, you should
            restart them once you update their configuration with the new
            registration token, or you can disable them right now, if you
            prefer.
          </li>
        </ul>
        <div className="mw6">
          <div className="items-center mb3">
            <label className="pointer">
              <input
                checked={disconnectRunningAgents}
                onChange={() =>
                  setDisconnectRunningAgents(!disconnectRunningAgents)
                }
                className="mr2"
                type="checkbox"
              />
              Disconnect all currently running agents
            </label>
          </div>
          <button
            className="btn btn-danger mr2"
            onClick={() => void resetToken()}
          >
            Reset token
          </button>
          <button className="btn btn-secondary" onClick={() => navigate(`..`)}>
            Nevermind
          </button>
        </div>
      </div>
    </div>
  );
};
