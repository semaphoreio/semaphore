import type { VNode } from "preact";
import { Fragment } from "preact";
import * as stores from "../../stores";
import * as components from "../";
import { useContext } from "preact/hooks";

export const name = `Linux`;
export const icon = `images/icn-os-linux.svg`;

export const Component = (): VNode => {
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
            <div>
              <div className="mb2">
                Log in or switch to the agent service user
              </div>
              <components.PreCopy content={`su - semaphore`}/>
            </div>
          </li>
          <li>
            <div className="mb2">Prepare the machine</div>
            <components.PreCopy
              title={`Prepare machine`}
              content={`sudo mkdir -p /opt/semaphore/agent
                        sudo chown $USER:$USER /opt/semaphore/agent/
                        cd /opt/semaphore/agent`}
            />
          </li>
          <li>
            <div className="mb2">
              Create the configuration file for the agent.
              <components.ResetTokenButton/>
            </div>
            <components.PreCopy
              title={`Create config file`}
              content={`cat > config.yaml <<EOF
              endpoint: ${hostname}
              token: "${state.token}"
              EOF`}
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
              content={`curl -L "https://github.com/semaphoreci/toolbox/releases/latest/download/self-hosted-linux.tar" -o toolbox.tar
                        tar -xf toolbox.tar
                        mv toolbox ~/.toolbox
                        bash ~/.toolbox/install-toolbox
                        source ~/.toolbox/toolbox
                        echo "source ~/.toolbox/toolbox" >> ~/.bash_profile`}
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
              for your platform and architecture
            </div>
            <components.PreCopy
              title="Download agent package"
              content={`curl -L https://github.com/semaphoreci/agent/releases/download/v2.2.23/agent_Linux_x86_64.tar.gz -o agent.tar.gz
                        tar -xf agent.tar.gz`}
            />
          </li>
          <li>
            <div className="mb2">
              Check that the agent is working and is connected
            </div>
            <components.PreCopy
              title="Start the agent"
              content={`agent start --config-file config.yaml`}
            />
          </li>
        </ol>
      </components.InstructionList>

      <components.GitProviders/>
    </Fragment>
  );
};
