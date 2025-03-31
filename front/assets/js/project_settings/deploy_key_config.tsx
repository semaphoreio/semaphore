import { render } from "preact";
import * as toolbox from "js/toolbox";

export function DeployKeyConfig({ config, dom }: { dom: HTMLElement, config: DOMStringMap, }) {
  const appWrapper = document.createElement(`div`);
  render(<App config={parseConfig(config)}/>, appWrapper);
  dom.replaceWith(...appWrapper.childNodes);
}

const parseConfig = (config: DOMStringMap): Config => {
  const parsedConfig = JSON.parse(config.config);
  return {
    publicKey: parsedConfig.public_key,
    title: parsedConfig.title,
    fingerprint: parsedConfig.fingerprint,
    createdAt: parsedConfig.created_at,
    message: parsedConfig.message,
    regenerateUrl: parsedConfig.regenerate_url
  };
};

interface Config {
  publicKey: string;
  title: string;
  fingerprint: string;
  createdAt: string;
  message: string;
  regenerateUrl: string;
}

const App = (props: { config: Config, }) => {
  const deployKey = props.config;
  const withProblem = deployKey.message.length > 0;
  const canRegenerate = deployKey.regenerateUrl != ``;

  const regenerate = () => {
    const confirmed = confirm(`Are you sure? This will regenerate a Deployment Key on Repository.`);
    if (confirmed) {
      const url = new toolbox.APIRequest.Url( `post`, deployKey.regenerateUrl);
      void url.call().then(() => {
        window.location.reload();
      });
    }
  };

  return (
    <>
      <div className="mb1 flex justify-between items-center">
        <div>
          <label className="b mr1">Deploy Key</label>
          {withProblem && <toolbox.Asset path="images/icn-failed.svg" className="v-mid"/>}
          {!withProblem && <toolbox.Asset path="images/icn-passed.svg" className="v-mid"/>}
          {canRegenerate && <span className="f5 fw5">
            <span className="mh1">·</span>
            <a className="pointer underline" onClick={regenerate}>Regenerate</a>
          </span>
          }
        </div>

        <div>
          <toolbox.Tooltip
            content={
              <div className="f6">
                Semaphore uses this SSH key to securely access your repository. Ensure it is kept private and only regenerate it if necessary.
              </div>
            }
            anchor={<toolbox.Asset className="pointer" path="images/icn-info-15.svg"/>}
          />
        </div>
      </div>
      <p className="f6 measure-wide mb3">{deployKey.message}</p>
      <toolbox.PreCopy title="Your public SSH key" content={deployKey.publicKey}/>
      <div className="f6 gray mt1 tr">Added on {deployKey.createdAt}</div>
    </>
  );
};
