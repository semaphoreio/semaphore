
import * as toolbox from "js/toolbox";
import { useNavigate } from "react-router-dom";
import { useContext } from "preact/hooks";
import * as stores from "../stores";
import * as types from "../types";
import { getProviderNameWithBadge, getProviderIcon, getProviderDescription } from '../utils/provider';
import Tippy from "@tippyjs/react";

export interface CardProps {
  type: types.Provider.IntegrationType;
  status: types.Provider.ProviderStatus | null;
  setupIntegrationUrl: string;
}

type CardContentsProps = Omit<CardProps, `setupIntegrationUrl`>;

export const Card = ({ type, status, setupIntegrationUrl }: CardProps) => {
  const navigate = useNavigate();
  const { setProvider } = useContext(stores.Create.Provider.Context);

  const handleClick = () => {
    if (status === types.Provider.ProviderStatus.NotConnected) return;

    setProvider({ type });
    navigate(`/${type}`);
  };

  return (
    <div className="mv3">
      {status === types.Provider.ProviderStatus.NotConnected ? (
        <a
          className="db btn btn-secondary"
          href={setupIntegrationUrl}
        >
          <Tippy
            content={<div>You will be taken to git integration setup page</div>}
            placement="top"
            trigger="mouseenter"
          >
            <div>
              <CardContents type={type} status={status}/>
            </div>
          </Tippy>
        </a>
      ) : (
        <a
          href="#"
          className="db btn btn-secondary"
          onClick={(e) => {
            e.preventDefault();
            handleClick();
          }}
        >
          <CardContents type={type} status={status}/>
        </a>
      )}
    </div>
  );
};

const CardContents = ({ type, status }: CardContentsProps) => {
  return (
    <div className="pv4-m flex items-start">
      <toolbox.Asset
        path={getProviderIcon(type)}
        width="48"
        height="48"
        className="ml2"
        alt={type.toLowerCase()}
      />
      <div className="ml3 tl">
        <div className="f3 b">
          {getProviderNameWithBadge(type)}
          {status && status === `connected` && (
            <span className="f6 normal ml2 ph1 br2 bg-green white pointer">
              connected
            </span>
          )}
        </div>
        <p className="f4 measure mb0">
          {getProviderDescription(type, status)}
        </p>
      </div>
    </div>
  );
};
