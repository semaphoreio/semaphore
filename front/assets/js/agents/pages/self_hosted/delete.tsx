
import { useNavigate, useParams } from "react-router-dom";
import { useContext } from "preact/hooks";
import * as stores from "js/agents/stores";

// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
import { Notice } from "js/notice";

export const Delete = () => {
  const { agent } = useParams();
  const navigate = useNavigate();
  const config = useContext(stores.Config.Context);
  const { state } = useContext(stores.SelfHostedAgent.Context);

  const deleteAgent = async () => {
    const agentType = state.type;
    return agentType
      .delete(config.selfHostedUrl)
      .then(() => {
        navigate(`/`);
      })
      .catch(Notice.error);
  };

  return (
    <div className="bg-white shadow-1 br3 pa4 mb3">
      <h3 className="f3 f2-m mb1">Delete {agent}?</h3>
      <p className="b red mv3">This cannot be undone!</p>
      <div>
        If you continue:
        <ul className="mb4 mt2">
          <li>You won&apos;t be able to start agents of this type anymore</li>
          <li>You’ll remove this agent type from Semaphore for everybody</li>
          <li>Pipelines that use this agent type will become invalid</li>
        </ul>
        <div className="mw6">
          <div className="mt3">
            <button
              className="btn btn-danger mr2"
              onClick={() => void deleteAgent()}
            >
              Delete
            </button>
            <a
              className="btn btn-secondary pointer"
              onClick={() => navigate(`..`)}
            >
              Nevermind
            </a>
          </div>
        </div>
      </div>
    </div>
  );
};
