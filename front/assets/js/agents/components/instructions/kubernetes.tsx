import { Fragment, h, VNode } from "preact";
import * as stores from "../../stores";
import * as components from "../";
import { useContext } from "preact/hooks";

export const name = `Kubernetes`;
export const icon = `images/icn-k8s.svg`;

export const Component = (): VNode => {
  const hostname = location.hostname;

  const { state } = useContext(stores.SelfHostedAgent.Context);

  return (
    <Fragment>
      <components.InstructionList>
        <ol>
          <li>
            <div className="mb2">
              Install{` `}
              <a href="https://helm.sh/" target="_blank" rel="noreferrer">
                helm
              </a>
            </div>
          </li>
          <li>
            <div className="mb2">Add the Semaphore Helm chart</div>
            <components.PreCopy
              title={`Add Helm repository`}
              content={`helm repo add renderedtext https://renderedtext.github.io/helm-charts`}
            />
          </li>
          <li>
            <div className="mb2">
              Install the{` `}
              <a
                href="https://github.com/renderedtext/agent-k8s-controller"
                target="_blank"
                rel="noreferrer"
              >
                agent-k8s-controller
              </a>
              {` `}
              with Helm
              <components.ResetTokenButton/>
            </div>
            <components.PreCopy
              title={`Install agent-k8s-controller`}
              content={`
              helm upgrade --install semaphore-controller renderedtext/controller \\
                --namespace semaphore \\
                --create-namespace \\
                --set endpoint=${hostname} \\
                --set apiToken=${state.token}`}
            />
          </li>
          <li>
            <div className="mb2">
              Create a secret to register the agent type in the Kubernetes
              cluster. Create a new YAML resource file.
            </div>
            <components.PreCopy
              title={`semaphore-secret.yml`}
              content={`
              apiVersion: v1
              kind: Secret
              metadata:
                  name: my-semaphore-agent-type
                  namespace: semaphore
                  labels:
                      semaphoreci.com/resource-type: agent-type-configuration
              stringData:
                  agentTypeName: ${state.type.name}
                  registrationToken: <BASE64_ENCODED_TOKEN>`}
            />
            <div className="mt2">
              The custom controllers looks for the label shown below to know
              what secret is relevant to this connection
            </div>
          </li>
          <li>
            <div className="mb2">Create the secret in kubernetes</div>
            <components.PreCopy
              content={`kubectl apply -f semaphore-secret.yml`}
            />
          </li>
        </ol>
      </components.InstructionList>
      <div className="mb2">
        The Helm chart provides a few additional configuration options so you
        can tweak your installation to best suit your needs. Run{` `}
        <components.Code content={`helm show values renderedtext/controller`}/>
        {` `}
        to view all available settings. See the Helm chart repo to learn more.
      </div>
      <div className="mb2">
        See the{` `}
        <a
          href="https://github.com/renderedtext/helm-charts/tree/main/charts/controller"
          target="_blank"
          rel="noreferrer"
        >
          Helm chart repo
        </a>
        {` `}
        to learn more.
      </div>
    </Fragment>
  );
};
