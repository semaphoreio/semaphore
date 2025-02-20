import { h, JSX } from "preact";
import * as types from "../types";
import { NavLink } from "react-router-dom";
import { IntegrationStarter } from "./integration_starter";
import { getProviderIcon } from "../../project_onboarding/new/utils/provider";
import * as toolbox from "js/toolbox";

interface CardProps {
  title: string;
  cardIcon?: JSX.Element;
  description: string;
  integrationType?: types.Integration.IntegrationType;
  connectionStatus?: types.Integration.IntegrationStatus;
  editPath?: string;
  time?: string;
  connectButtonUrl?: string;
  connectPayload?: object;
  reConnectButtonUrl?: string;
  lastItem: boolean;
  internalSetup?: boolean;
}

export const Card = (props: CardProps) => {
  return (
    <div className={`ph3 pv2 mv2 ${props.lastItem ? `` : `bb b--black-075`}`}>
      <div className="flex items-center justify-between mb2">
        <div className="flex items-center">
          {props.cardIcon || iconFromType(props.integrationType)}
          <span className="b f5">{props.title}</span>
        </div>

        {/* for integrations only */}
        {props.connectionStatus && (
          <div>
            <span className="f6 normal ml1 ph1 br2 bg-green white pointer">
              {props.connectionStatus}
            </span>

            <NavLink
              className="material-symbols-outlined f5 b btn pointer pa1 btn-secondary ml3"
              data-tippy-content="Edit this integration"
              to={`/` + props.integrationType}
            >
              edit
            </NavLink>
          </div>
        )}
      </div>
      {/* end of integrations only */}

      <div className="f6 gray flex items-center mb3">{props.description}</div>

      {/* for new connections only */}
      {(props.reConnectButtonUrl || props.connectButtonUrl || props.internalSetup) && (
        <div className="flex items-center justify-between">
          <div className="flex items-center">
            <span className="material-symbols-outlined mr1 f4">pace</span>
            <div className="f6 gray">{props.time} min setup time</div>
          </div>
          <div className="flex items-center justify-end">
            {props.reConnectButtonUrl && (
              <button className="btn btn-secondary btn-small mr2">
                Re-connect existing app
              </button>
            )}
            {props.connectButtonUrl && !props.internalSetup && (
              <IntegrationStarter connectButtonUrl={props.connectButtonUrl}/>
            )}
            {props.internalSetup && (
              // this goes to integration page
              <NavLink
                className="btn btn-primary btn-small"
                data-tippy-content="Connect this integration"
                to={`/` + props.integrationType}
              >
                Connect
              </NavLink>
            )}
          </div>
        </div>
      )}
      {/* end of new connections only */}
    </div>
  );
};

const iconFromType = (type: types.Integration.IntegrationType) => {
  return <toolbox.Asset path={getProviderIcon(type)} className="mr2"/>;
};
