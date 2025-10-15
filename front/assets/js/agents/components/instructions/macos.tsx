import type { h, VNode } from "preact";
import { Fragment } from "preact";
import * as stores from "../../stores";
import * as components from "../";
import { useContext, useState } from "preact/hooks";
import styled from "styled-components";

export const name = `macOS`;
export const icon = `images/icn-os-mac.svg`;

export const Component = (): VNode => {
  const [selectedOs, setSelectedOs] = useState<`macos` | `homebrew`>(
    `homebrew`
  );

  interface SubOsProps extends h.JSX.HTMLAttributes {
    name: string;
    active: boolean;
  }
  const SubOS = (
    props: SubOsProps
  ) => {
    const ButtonEl = styled.button`
      &:hover,
      &.active {
        box-shadow: 0 0 0 3px #00359f !important;
      }
    `;
    return (
      <ButtonEl
        onClick={props.onClick}
        className={`btn btn-secondary flex items-center mr3 bw1 br3 wf-insights-hover ${
          props.active ? `active` : ``
        }`}
      >
        {props.children}
        <span className="ml2">{props.name}</span>
      </ButtonEl>
    );
  };

  return (
    <Fragment>
      <div className="flex ph3-l mb4">
        <SubOS
          name="Homebrew"
          onClick={() => setSelectedOs(`homebrew`)}
          active={selectedOs == `homebrew`}
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            fill="#000000"
            width="16px"
            viewBox="0 0 305 305"
            xmlSpace="preserve"
          >
            <g id="XMLID_228_">
              <path
                id="XMLID_229_"
                d="M40.738,112.119c-25.785,44.745-9.393,112.648,19.121,153.82C74.092,286.523,88.502,305,108.239,305   c0.372,0,0.745-0.007,1.127-0.022c9.273-0.37,15.974-3.225,22.453-5.984c7.274-3.1,14.797-6.305,26.597-6.305   c11.226,0,18.39,3.101,25.318,6.099c6.828,2.954,13.861,6.01,24.253,5.815c22.232-0.414,35.882-20.352,47.925-37.941   c12.567-18.365,18.871-36.196,20.998-43.01l0.086-0.271c0.405-1.211-0.167-2.533-1.328-3.066c-0.032-0.015-0.15-0.064-0.183-0.078   c-3.915-1.601-38.257-16.836-38.618-58.36c-0.335-33.736,25.763-51.601,30.997-54.839l0.244-0.152   c0.567-0.365,0.962-0.944,1.096-1.606c0.134-0.661-0.006-1.349-0.386-1.905c-18.014-26.362-45.624-30.335-56.74-30.813   c-1.613-0.161-3.278-0.242-4.95-0.242c-13.056,0-25.563,4.931-35.611,8.893c-6.936,2.735-12.927,5.097-17.059,5.097   c-4.643,0-10.668-2.391-17.645-5.159c-9.33-3.703-19.905-7.899-31.1-7.899c-0.267,0-0.53,0.003-0.789,0.008   C78.894,73.643,54.298,88.535,40.738,112.119z"
              />
              <path
                id="XMLID_230_"
                d="M212.101,0.002c-15.763,0.642-34.672,10.345-45.974,23.583c-9.605,11.127-18.988,29.679-16.516,48.379   c0.155,1.17,1.107,2.073,2.284,2.164c1.064,0.083,2.15,0.125,3.232,0.126c15.413,0,32.04-8.527,43.395-22.257   c11.951-14.498,17.994-33.104,16.166-49.77C214.544,0.921,213.395-0.049,212.101,0.002z"
              />
            </g>
          </svg>
        </SubOS>
        <SubOS
          name="MacOS"
          onClick={() => setSelectedOs(`macos`)}
          active={selectedOs == `macos`}
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            fill="#000000"
            width="16px"
            viewBox="0 0 305 305"
            xmlSpace="preserve"
          >
            <g id="XMLID_228_">
              <path
                id="XMLID_229_"
                d="M40.738,112.119c-25.785,44.745-9.393,112.648,19.121,153.82C74.092,286.523,88.502,305,108.239,305   c0.372,0,0.745-0.007,1.127-0.022c9.273-0.37,15.974-3.225,22.453-5.984c7.274-3.1,14.797-6.305,26.597-6.305   c11.226,0,18.39,3.101,25.318,6.099c6.828,2.954,13.861,6.01,24.253,5.815c22.232-0.414,35.882-20.352,47.925-37.941   c12.567-18.365,18.871-36.196,20.998-43.01l0.086-0.271c0.405-1.211-0.167-2.533-1.328-3.066c-0.032-0.015-0.15-0.064-0.183-0.078   c-3.915-1.601-38.257-16.836-38.618-58.36c-0.335-33.736,25.763-51.601,30.997-54.839l0.244-0.152   c0.567-0.365,0.962-0.944,1.096-1.606c0.134-0.661-0.006-1.349-0.386-1.905c-18.014-26.362-45.624-30.335-56.74-30.813   c-1.613-0.161-3.278-0.242-4.95-0.242c-13.056,0-25.563,4.931-35.611,8.893c-6.936,2.735-12.927,5.097-17.059,5.097   c-4.643,0-10.668-2.391-17.645-5.159c-9.33-3.703-19.905-7.899-31.1-7.899c-0.267,0-0.53,0.003-0.789,0.008   C78.894,73.643,54.298,88.535,40.738,112.119z"
              />
              <path
                id="XMLID_230_"
                d="M212.101,0.002c-15.763,0.642-34.672,10.345-45.974,23.583c-9.605,11.127-18.988,29.679-16.516,48.379   c0.155,1.17,1.107,2.073,2.284,2.164c1.064,0.083,2.15,0.125,3.232,0.126c15.413,0,32.04-8.527,43.395-22.257   c11.951-14.498,17.994-33.104,16.166-49.77C214.544,0.921,213.395-0.049,212.101,0.002z"
              />
            </g>
          </svg>
        </SubOS>
      </div>
      {selectedOs == `macos` && <MacOSInstructions/>}
      {selectedOs == `homebrew` && <HomebrewInstructions/>}
    </Fragment>
  );
};

export const MacOSInstructions = () => {
  const hostname = location.hostname;

  const { state } = useContext(stores.SelfHostedAgent.Context);
  return (
    <Fragment>
      <components.InstructionList>
        <ol>
          <li>
            <div className="mb2">
              Create a user to run the agent service with sudo permissions, e.g.
              <components.Code content="semaphore"/>
            </div>
          </li>
          <li>
            <div className="mb2">
              Log in or switch to the agent service user
            </div>
            <components.PreCopy content={`su - semaphore`}/>
          </li>
          <li>
            <div className="mb2">Prepare the machine</div>
            <components.PreCopy
              title="Prepare machine"
              content={`sudo mkdir -p /opt/semaphore/agent
                        sudo chown $USER:$USER /opt/semaphore/agent/
                        cd /opt/semaphore/agent`}
            />
          </li>
          <li>
            <div className="mb2">
              Download the agent package. Find the{` `}
              <a
                href="https://github.com/semaphoreci/agent/releases/"
                target="_blank"
                rel="noreferrer"
              >
                latest release
              </a>
              {` `}
              for your platform and architecture (x86_64 or arm64)
            </div>
            <components.PreCopy
              title={`Download agent package`}
              content={`curl -L https://github.com/semaphoreci/agent/releases/download/v2.2.23/agent_Darwin_arm64.tar.gz -o agent.tar.gz
                        tar -xf agent.tar.gz`}
            />
          </li>
          <li>
            <div className="mb2">
              Install the agent and follow the prompts.
              <components.ResetTokenButton/>
            </div>
            <components.PreCopy
              title="Install agent"
              content={`$ sudo ./install.sh
                        Enter organization: ${hostname}
                        Enter registration token: ${state.token}
                        Enter user [root]: <local-service-user>
                        Downloading toolbox from https://github.com/semaphoreci/toolbox/releases/latest/download/darwin.tar...
                        [sudo] password for semaphore:
                        Creating agent config file at /opt/semaphore/agent/config.yaml...
                        Creating /etc/systemd/system/semaphore-agent.service...
                        Starting semaphore-agent service...`}
            />
          </li>
        </ol>
      </components.InstructionList>

      <components.GitProviders/>
    </Fragment>
  );
};

export const HomebrewInstructions = () => {
  const hostname = location.hostname;

  const { state } = useContext(stores.SelfHostedAgent.Context);

  return (
    <Fragment>
      <components.InstructionList>
        <ol>
          <li>
            <div className="mb2">
              Install{` `}
              <a
                href="https://brew.sh/"
                target="_blank"
                rel="noreferrer"
              >
                Homebrew
              </a>
            </div>
          </li>
          <li>
            <div className="mb2">Install the Semaphore self-hosted agent</div>
            <components.PreCopy
              content={`brew install semaphoreci/tap/agent`}
            />
          </li>
          <li>
            <div className="mb2">
              Download and install the{` `}
              <a
                href="https://github.com/semaphoreci/agent/releases/"
                target="_blank"
                rel="noreferrer"
              >
                Semaphore toolbox
              </a>
              . Select the correct platform and architecture
            </div>
            <components.PreCopy
              title="Install Semaphore toolbox"
              content={`curl -L "https://github.com/semaphoreci/toolbox/releases/download/v1.21.19/darwin-arm.tar" -o toolbox.tar
                        tar -xf toolbox.tar
                        mv toolbox ~/.toolbox
                        bash ~/.toolbox/install-toolbox
                        source ~/.toolbox/toolbox
                        echo "source ~/.toolbox/toolbox" >> ~/.bash_profile`}
            />
          </li>
          <li>
            <div className="mb2">
              Start the agent.
              <components.ResetTokenButton/>
            </div>
            <components.PreCopy
              title={`Download agent package`}
              content={`agent start --endpoint ${hostname} --token ${state.token}`}
            />
          </li>
        </ol>
      </components.InstructionList>

      <components.GitProviders/>
    </Fragment>
  );
};
