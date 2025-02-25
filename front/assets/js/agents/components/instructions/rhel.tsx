import { Fragment, VNode } from "preact";
import * as stores from "../../stores";
import * as components from "../";
import { useContext } from "preact/hooks";

export const name = `Rhel`;
export const icon = `images/icn-os-redhat.svg`;

export const Component = (): VNode => {
  const hostname = location.hostname;

  const { state } = useContext(stores.SelfHostedAgent.Context);

  return (
    <Fragment>
      <components.InstructionList>
        <ol>
          <li>
            <div className="mb2">Verify the host has FIPS mode enabled</div>
            <components.PreCopy content={`sudo fips-mode-setup --check`}/>
          </li>
          <li>
            <div className="mb2">
              Install the{` `}
              <a
                href="https://developers.redhat.com/blog/2019/06/24/go-and-fips-140-2-on-red-hat-enterprise-linux#using_go_toolset"
                target="_blank"
                rel="noreferrer"
              >
                go-toolset
              </a>
            </div>
            <components.PreCopy content={`sudo yum install go-toolset`}/>
          </li>
          <li>
            <div className="mb2">
              Create a user for the Semaphore service with{` `}
              <components.Code content="sudo"/> permissions
            </div>
            <components.PreCopy
              content={`adduser semaphore
                        passwd semaphore
                        usermod -aG wheel semaphore
                        su - semaphore`}
            />
          </li>
          <li>
            <div className="mb2">
              Download the source and compile it. Find the{` `}
              <a
                href="https://github.com/semaphoreci/agent/releases/"
                target="_blank"
                rel="noreferrer"
              >
                latest release
              </a>
              {` `}
              and download the source package
            </div>
            <components.PreCopy
              title={`Create config file`}
              content={`curl -L https://github.com/semaphoreci/agent/archive/refs/tags/v2.2.23.tar.gz -o agent.tar.gz
                        tar -xf agent.tar.gz
                        cd agent-2.2.23
                        make build`}
            />
          </li>
          <li>
            <div className="mb2">Verify that the binary is FIPS compatible</div>
            <components.PreCopy
              content={`go tool nm ./build/agent | grep FIPS`}
            />
          </li>

          <li>
            <div className="mb2">
              Install and follow the prompts
              <components.ResetTokenButton/>
            </div>

            <components.PreCopy
              content={`make install
                        $ sudo ./install
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
        </ol>
      </components.InstructionList>

      <components.GitProviders/>
    </Fragment>
  );
};
