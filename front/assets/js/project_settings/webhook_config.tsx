import { render } from "preact";
import * as toolbox from "js/toolbox";
import { useState } from "preact/hooks";
// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
import { Notice } from "js/notice";

export function WebhookConfig({ config, dom }: { dom: HTMLElement, config: DOMStringMap, }) {
  render(<App config={parseConfig(config)}/>, dom);
  dom.removeAttribute(`data-config`);
}

const parseConfig = (config: DOMStringMap): Config => {
  const parsedConfig = JSON.parse(config.config);
  return {
    connected: parsedConfig.connected,
    regenerateUrl: parsedConfig.regenerate_url,
    message: parsedConfig.message,
    hookUrl: parsedConfig.hook_url,
  };
};

interface Config {
  connected: boolean;
  regenerateUrl: string;
  message: string;
  hookUrl: string;
}

const App = (props: { config: Config, }) => {
  const webhook = props.config;
  const [secret, setSecret] = useState(``);
  const [hookUrl, setHookUrl] = useState(webhook.hookUrl);

  const withProblem = webhook.message.length > 0;
  const canRegenerate = webhook.regenerateUrl != ``;

  const regenerate = () => {
    const confirmed = confirm(`Are you sure? This will regenerate a Deployment Key on Repository.`);
    if (confirmed) {
      const url = new toolbox.APIRequest.Url<{ secret: string, message: string,endpoint: string, }>( `post`, webhook.regenerateUrl);
      void url.call()
        .then((resp) => {
          Notice.notice(resp.data.message);
          setSecret(resp.data.secret);
          setHookUrl(resp.data.endpoint);
        }).catch((e) => {
          Notice.error(e);
        });
    }
  };

  return (
    <>
      <div className="mb1 flex justify-between items-center">
        <div>
          <label className="b mr1">Webhook</label>
          {withProblem && <toolbox.Asset path="images/icn-failed.svg" className="v-mid"/>}
          {!withProblem && <toolbox.Asset path="images/icn-passed.svg" className="v-mid"/>}
          {canRegenerate && <span className="f5 fw5">
            <span className="mh1">·</span>
            <a className="pointer underline" onClick={regenerate}>Regenerate</a>
          </span>
          }
        </div>

        <div>
          <toolbox.Popover
            content={
              <div className="f6">
                Webhooks allow your server to receive real-time updates. Ensure the webhook URL is correctly configured to handle incoming events and validate their signatures for security.
                <br/>
                Lost your signing secret? No problem! You can generate a new one by clicking <a className="pointer blue underline" onClick={regenerate}>here</a>.
              </div>
            }
            anchor={<toolbox.Asset className="pointer" path="images/icn-info-15.svg"/>}
          />
        </div>
      </div>

      <input id="webhook" type="text" className="form-control w-100 mr2" value={hookUrl} readOnly disabled/>
      <p className="f6 measure-wide mb3">{webhook.message}</p>
      {secret.length > 0 && <toolbox.PreCopy title="Your webhook signing secret" content={secret}/> }
    </>
  );
};
