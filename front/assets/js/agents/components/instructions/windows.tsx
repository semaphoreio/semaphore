import { Fragment, h, VNode } from "preact";
import * as stores from "../../stores";
import * as components from "../";
import { useContext } from "preact/hooks";

export const name = `Windows`;
export const icon = `images/icn-os-windows.svg`;

export const Component = (): VNode => {
  const hostname = location.hostname;

  const { state } = useContext(stores.SelfHostedAgent.Context);

  return (
    <Fragment>
      <components.InstructionList>
        <ol>
          <li>
            <div className="mb2">Prepare your machine</div>
            <components.PreCopy
              content={`New-Item -ItemType Directory -Path C:\\semaphore-agent
                        Set-Location C:\\semaphore-agent`}
            />
          </li>
          <li>
            <div className="mb2">
              Download the agent. Find the latest release for your platform and
              architecture
            </div>
            <components.PreCopy
              content={`Invoke-WebRequest "https://github.com/semaphoreci/agent/releases/download/v2.2.23/agent_Windows_x86_64.tar.gz" -OutFile agent.tar.gz
                        tar.exe xvf agent.tar.gz`}
            />
          </li>
          <li>
            <div className="mb2">
              Install the agent and follow the prompts
              <components.ResetTokenButton/>
            </div>
            <components.PreCopy
              title={`Prepare machine`}
              content={`$env:SemaphoreEndpoint = "${hostname}"
                        $env:SemaphoreRegistrationToken = "${state.token}"
                        .\\install.ps1`}
            />
          </li>
        </ol>
      </components.InstructionList>
    </Fragment>
  );
};
