import { render, createContext, Fragment } from "preact";
// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
import { Notice } from "js/notice";
import { useContext, useState } from "preact/hooks";
import * as toolbox from "js/toolbox";
import styled from "styled-components";

export default function ({
  dom,
  config: jsonConfig,
}: {
  dom: Element;
  config: any;
}) {
  const buttonContainer = document.createElement(`div`);

  render(
    <Config.Provider value={ConfigState.fromJSON(jsonConfig as RawConfig)}>
      <Button/>
    </Config.Provider>,
    buttonContainer
  );

  dom.replaceWith(...buttonContainer.childNodes);
}

const Button = () => {

  const config = useContext(Config);
  const [syncing, setSyncing] = useState(false);


  const refreshPeople = () => {
    setSyncing(true);
    config.syncUrl
      .call()
      .then((resp) => {
        Notice.notice(resp.data.message);
      })
      .catch((err) => {
        Notice.error(err.error as string);
      })
      .finally(() => {
        setSyncing(false);
      });
  };


  return (


    <Fragment>
      <toolbox.Tooltip
        anchor={
          <button className="pointer flex items-center btn-secondary btn nowrap" onClick={refreshPeople} disabled={syncing}>
            <Spinner className={`material-symbols-outlined mr1 ${syncing ? `active` : ``}`}>
              sync
            </Spinner>

            <span>Re-sync</span>
          </button>
        }
        content={`Sync user permissions with your Git provider. Checks for updates in organization access based on current Git provider permissions.`}
        placement="top"
      />
    </Fragment>
  );
};


export interface RawConfig {
  config: string;
}
interface ParsedConfig {
  users: {
    sync_url: string;
  };
}

export class ConfigState {
  syncUrl: toolbox.APIRequest.Url<{
    message: string;
  }>;


  static fromJSON(rawJson: RawConfig): ConfigState {
    const config = this.default();
    const json: ParsedConfig = JSON.parse(rawJson.config);

    config.syncUrl = toolbox.APIRequest.Url.fromJSON(json.users.sync_url);

    return config;
  }

  static default(): ConfigState {
    const config = new ConfigState();
    return config;
  }
}

export const Config = createContext<ConfigState>(ConfigState.default());


const Spinner = styled.div`
  @keyframes spin {
    from {
      transform: rotate(0deg);
    }

    to {
      transform: rotate(-360deg);
    }
  }

  animation-duration: 2000ms;
  animation-iteration-count: infinite;
  animation-timing-function: cubic-bezier(0.5, 0, 0.5, 1);

  &.active {
    animation-name: spin;
  }
`;
