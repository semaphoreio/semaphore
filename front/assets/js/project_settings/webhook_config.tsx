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
  };
};


interface Config {
  connected: boolean;
  regenerateUrl: string;
  message: string;
}

const App = (props: { config: Config, }) => {
  const webhook = props.config;
  const [secret, setSecret] = useState(``);

  const withProblem = webhook.message.length > 0;
  const canRegenerate = webhook.regenerateUrl != ``;

  const regenerate = () => {
    const confirmed = confirm(`Are you sure? This will regenerate a Deployment Key on Repository.`);
    if (confirmed) {
      const url = new toolbox.APIRequest.Url<{ secret: string, message: string, }>( `post`, webhook.regenerateUrl);
      void url.call()
        .then((resp) => {
          Notice.notice(resp.data.message);
          setSecret(resp.data.secret);
        }).catch((e) => {
          Notice.error(e);
        });
    }
  };

  return (
    <>
      <div className="mb1 flex justify-between items-center">
        <div>
          <label className="b mr1">Webhook signing secret</label>
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
                Your <b>post-receive</b> script is using this value to sign incoming webhooks. This way semaphore knows that the incoming hooks are comming from you.
                Once you regenerate this value - you must update the <b>post-receive</b> script on your git server.
              </div>
            }
            anchor={<toolbox.Asset className="pointer" path="images/icn-info-15.svg"/>}
          />
        </div>
      </div>

      <p className="f6 measure-wide mb3">{webhook.message}</p>
      {secret.length > 0 &&
        <>
          <div className="f6 mb1 red">
            This is the only time we&apos;ll display you this value. Make sure to update your <b>post-receive</b> script.
          </div>
          <toolbox.PreCopy title="Your webhook signing secret" content={secret}/>
        </>
      }

    </>
  );
};
