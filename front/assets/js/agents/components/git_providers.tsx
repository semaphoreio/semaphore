import { h } from "preact";
import * as components from ".";
import { useState } from "preact/compat";
import styled from "styled-components";
import * as toolbox from "js/toolbox";

export const GitProviders = (props: h.JSX.HTMLAttributes<HTMLDivElement>) => {
  type provider = `github` | `bitbucket`;
  const [selectedProvider, setSelectedProvider] = useState<provider>(`github`);

  interface ProviderProps extends h.JSX.HTMLAttributes {
    name: string;
    active: boolean;
  }
  const Provider = (props: ProviderProps) => {
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
    <div
      className={`bt b--black-10 ${(props.className ?? ``).toString()}`}
      {...props}
    >
      <div className="mv3">
        <div className="flex items-center mb3">
          <div className="flex-shrink-0 f6 br2 lh-copy w3 tc white ba bg-gray mr1">
            Optional
          </div>
          <span className="f3 b">Configure Git Providers</span>
        </div>
        <div className="gray measure-wide">
          Configure SSH access to securely connect your agent with your Git
          provider. Follow the steps below based on your selected provider.
        </div>
      </div>

      <div className="flex mb4">
        <Provider
          name="GitHub"
          active={selectedProvider === `github`}
          onClick={() => setSelectedProvider(`github`)}
        >
          <toolbox.Asset
            path="images/icn-github.svg"
            width="16"
            height="16"
            class="db"
          />
        </Provider>
        <Provider
          name="Bitbucket"
          active={selectedProvider === `bitbucket`}
          onClick={() => setSelectedProvider(`bitbucket`)}
        >
          <toolbox.Asset
            path="images/icn-bitbucket.svg"
            width="16"
            height="16"
            class="db"
          />
        </Provider>
      </div>
      <components.InstructionList>
        {selectedProvider === `github` && <GitHubInstructions/>}
        {selectedProvider === `bitbucket` && <BitbucketInstructions/>}
      </components.InstructionList>
    </div>
  );
};

const GitHubInstructions = () => {
  return (
    <ol>
      <li>
        <div className="mb2">Add GitHub SSH fingerprints</div>
        <components.PreCopy
          content={`sudo mkdir -p /home/$USER/.ssh
                    sudo chown -R $USER:$USER /home/$USER/.ssh

                    curl -sL https://api.github.com/meta | jq -r ".ssh_keys[]" | sed 's/^/github.com /' | tee -a /home/$USER/.ssh/known_hosts

                    chmod 700 /home/$USER/.ssh
                    chmod 600 /home/$USER/.ssh/known_hosts`}
        />
      </li>
      <li>
        <div className="mb2">
          Add your SSH private keys into the{` `}
          <components.Code content="~/.ssh/"/>
          folder
        </div>
      </li>
      <li>
        <div className="mb2">Test SSH connection to GitHub</div>
        <components.PreCopy
          title={`Testing SSH connection`}
          content={`ssh -T git@github.com`}
        />
      </li>
      <li>
        <div className="mb2">Restart the agent service</div>
        <components.PreCopy
          title={`Restart agent service`}
          content={`sudo systemctl restart semaphore-agent`}
        />
      </li>
    </ol>
  );
};

const BitbucketInstructions = () => {
  return (
    <ol>
      <li>
        <div className="mb2">Add BitBucket SSH fingerprints</div>
        <components.PreCopy
          content={`sudo mkdir -p /home/$USER/.ssh
                    sudo chown -R $USER:$USER /home/$USER/.ssh

                    curl -sL https://bitbucket.org/site/ssh | tee -a /home/$USER/.ssh/known_hosts

                    chmod 700 /home/$USER/.ssh
                    chmod 600 /home/$USER/.ssh/known_hosts`}
        />
      </li>
      <li>
        <div className="mb2">
          Add your SSH private keys into the{` `}
          <components.Code content="~/.ssh/"/>
          folder
        </div>
      </li>
      <li>
        <div className="mb2">Test SSH connection to BitBucket</div>
        <components.PreCopy
          title={`Testing SSH connection`}
          content={`ssh -T git@bitbucket.org`}
        />
      </li>
      <li>
        <div className="mb2">Restart the agent service</div>
        <components.PreCopy
          title={`Restart agent service`}
          content={`sudo systemctl restart semaphore-agent`}
        />
      </li>
    </ol>
  );
};
