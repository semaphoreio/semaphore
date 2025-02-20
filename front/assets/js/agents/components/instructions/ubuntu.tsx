import { Fragment, h, VNode } from "preact";
import * as stores from "../../stores";
import * as components from "../";
import { useContext } from "preact/hooks";

export const name = `Ubuntu/Debian`;
export const icon = `images/icn-os-ubuntu.svg`;

export const Component = (): VNode => {
  const hostname = location.hostname;

  const { state } = useContext(stores.SelfHostedAgent.Context);

  return (
    <Fragment>
      <components.InstructionList>
        <ol>
          <li>
            <div className="mb2">
              Create a user with sudo permissions to run the agent service, e.g.
              <components.Code content="semaphore"/>
            </div>
            <components.PreCopy
              content={`sudo adduser semaphore
                        sudo adduser semaphore sudo`}
            />
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
              content={`
              sudo mkdir -p /opt/semaphore/agent
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
              for your platform and architecture
            </div>
            <components.PreCopy
              title={`Download agent package`}
              content={`
                curl -L https://github.com/semaphoreci/agent/releases/download/v2.2.23/agent_Linux_x86_64.tar.gz -o agent.tar.gz
                tar -xf agent.tar.gz
              `}
            />
          </li>
          <li>
            <div className="mb2">
              Install the agent and follow the prompts. Type the organization
              name, the registration token and the name of the local service
              user, e.g. <components.Code content="semaphore"/>.
              <components.ResetTokenButton/>
            </div>
            <components.PreCopy
              title="Install agent"
              content={`$ sudo ./install.sh
                        Enter organization: ${hostname.split(`.`)[0]}
                        Enter registration token: ${state.token}
                        Enter user [root]: <local-service-user>
                        Downloading toolbox from https://github.com/semaphoreci/toolbox/releases/latest/download/self-hosted-linux.tar...
                        [sudo] password for semaphore:
                        Creating agent config file at /opt/semaphore/agent/config.yaml...
                        Creating /etc/systemd/system/semaphore-agent.service...
                        Starting semaphore-agent service...`}
            />
          </li>

          <li>
            <div className="mb2">Restart the agent service</div>
            <components.PreCopy
              title="Restart agent service"
              content={`sudo systemctl restart semaphore-agent`}
            />
          </li>
          <li>
            <div className="mb2">
              Check that the agent is working and is connected
            </div>
            <components.PreCopy
              title="Checking self-hosted agent status"
              content={`$ sudo systemctl status semaphore-agent
                        ● semaphore-agent.service - Semaphore agent
                            Loaded: loaded (/etc/systemd/system/semaphore-agent.service; disabled; preset: enabled)
                            Active: active (running) since Fri 2024-07-12 14:09:28 UTC; 10s ago
                        Main PID: 5154 (agent)
                            Tasks: 11 (limit: 509)
                            Memory: 13.0M (peak: 13.8M)
                                CPU: 77ms
                            CGroup: /system.slice/semaphore-agent.service
                                    ├─5154 /opt/semaphore/agent/agent start --config-file /opt/semaphore/agent/config.yaml
                                    └─5157 /opt/semaphore/agent/agent start --config-file /opt/semaphore/agent/config.yaml

                        Jul 12 14:09:28 selfhosted agent[5157]: Jul 12 14:09:28.345 sywinVS8IgIkZzgIgk2D : Starting to poll for jobs
                        Jul 12 14:09:28 selfhosted agent[5157]: Jul 12 14:09:28.345 sywinVS8IgIkZzgIgk2D : SYNC request (state: waiting-for-jobs)
                        Jul 12 14:09:28 selfhosted agent[5157]: Jul 12 14:09:28.442 sywinVS8IgIkZzgIgk2D : SYNC response (action: continue)
                        Jul 12 14:09:28 selfhosted agent[5157]: Jul 12 14:09:28.442 sywinVS8IgIkZzgIgk2D : Waiting 4.888s for next sync...
                        Jul 12 14:09:33 selfhosted agent[5157]: Jul 12 14:09:33.331 sywinVS8IgIkZzgIgk2D : SYNC request (state: waiting-for-jobs)`}
            />
          </li>
        </ol>
      </components.InstructionList>

      <components.GitProviders/>
    </Fragment>
  );
};
