
import { useNavigate } from "react-router-dom";
import * as stores from "../stores";
import { useContext } from "preact/hooks";
import * as toolbox from "js/toolbox";

export const ResetTokenButton = () => {
  const navigate = useNavigate();

  const { state, dispatch } = useContext(stores.SelfHostedAgent.Context);
  const config = useContext(stores.Config.Context);

  const tokenExists = state._token != ``;
  const tokenRevealed = state.tokenRevealed;

  if (!tokenExists) {
    if (config.accessProvider.canManageAgents()) {
      return (
        <div>
          <button
            className="btn btn-secondary btn-tiny"
            onClick={() =>
              navigate(`./reset`, {
                state: { targetId: `agents-header` },
                replace: true,
              })
            }
          >
            Reset token
          </button>
        </div>
      );
    } else {
      return (
        <div>
          <toolbox.Tooltip
            content="You do not have permission to reset the token."
            anchor={
              <button className="btn btn-secondary btn-tiny" disabled>
                Reset token
              </button>
            }
          />
        </div>
      );
    }
  }
  if (tokenRevealed) {
    return (
      <div>
        <button
          className="btn btn-secondary btn-tiny"
          onClick={() => dispatch({ type: `HIDE_TOKEN` })}
        >
          Hide token
        </button>
      </div>
    );
  } else {
    return (
      <div>
        <button
          className="btn btn-green btn-tiny"
          onClick={() => dispatch({ type: `REVEAL_TOKEN` })}
        >
          Reveal token
        </button>
      </div>
    );
  }
};
