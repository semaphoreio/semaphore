import { Fragment } from "preact";
import { useState, useEffect, useContext } from "preact/hooks";
import * as toolbox from "js/toolbox";
import * as stores from "../stores";
// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
import { Notice } from "js/notice";

interface ProjectStatusProps {
  isCreatingProject: boolean;
  showZeroState: boolean;
  steps: Array<{
    id: string;
    label: string;
    completed: boolean;
  }>;
  isComplete: boolean;
  error?: string;
  waitingMessage?: string;
  errorMessage?: string;
  nextScreenUrl?: string;
  repoConnectionUrl?: string;
  csrfToken: string;
}

interface ConnectionData {
  hook_regenerate_url: string;
  hook_message: string;
  hook?: {
    url: string;
  };
  deploy_key_regenerate_url: string;
  deploy_key_message: string;
  deploy_key?: {
    title: string;
    fingerprint: string;
    created_at: string;
  };
}

const spinnerMessage = (msg: string, isDone: boolean | `error` | null) => {
  if (isDone == null) return ``;

  if (isDone === `error`) {
    return <Fragment>
      <li><span className="red" style="vertical-align: bottom; padding-right: 12px; padding-left: 3px;">✗</span><span>{msg}</span></li>
    </Fragment>;
  } else if (isDone === true) {
    return <Fragment><li>
      <span className="green" style="vertical-align: bottom; padding-right: 12px; padding-left: 3px;">✓</span><span>{msg}</span></li></Fragment>;
  }
  else {
    return <Fragment>
      <li><toolbox.Asset path="images/spinner-2.svg" style="vertical-align: bottom; padding-right: 9px;"/><span>{msg}</span></li>
    </Fragment>;
  }
};

export const ProjectStatus = ({
  isCreatingProject,
  showZeroState,
  steps,
  isComplete,
  error,
  waitingMessage,
  errorMessage,
  nextScreenUrl,
  repoConnectionUrl,
  csrfToken,
}: ProjectStatusProps) => {
  const [connectionData, setConnectionData] = useState<ConnectionData | null>(null);
  const { state } = useContext(stores.Create.Repository.Context);

  const fetchConnectionData = async () => {
    if (isComplete && repoConnectionUrl) {
      try {
        const response = await fetch(repoConnectionUrl, {
          headers: {
            'X-CSRF-Token': csrfToken || ``,
          }
        });

        if (!response.ok) {
          throw new Error(`Failed to fetch connection data`);
        }

        const data: ConnectionData = await response.json();
        setConnectionData(data);
      } catch (err) {
        Notice.error(`Error fetching connection data: ${err instanceof Error ? err.message : String(err)}`);
      }
    }
  };

  useEffect(() => {
    void fetchConnectionData();
  }, [isComplete, repoConnectionUrl]);

  if (!showZeroState) {
    return (
      <ZeroState/>
    );
  }

  if (!isCreatingProject) {
    return <Fragment></Fragment>;
  }

  return (
    <Fragment>
      {(error || errorMessage || waitingMessage || !steps.every(step => !step.completed) || isComplete) && (
        <div className="mt2 bg-white br3 pa3 shadow-1">
          {waitingMessage && (
            <h3
              className="f4 fw4 black-70 mt0 mb3"
              dangerouslySetInnerHTML={{ __html: waitingMessage }}
            />
          )}
          <div>
            <ul style="list-style: none; padding: 0;">
              {(() => {
                if (isComplete) {
                  return steps.map(step => spinnerMessage(step.label, true));
                }

                const firstUnfinishedStep = steps.find(step => !step.completed);
                if (firstUnfinishedStep) {
                  return (
                    <Fragment>
                      {steps.map(step => {
                        return spinnerMessage(step.label, step.completed);
                      })}
                    </Fragment>
                  );
                }
                return steps.map(step => spinnerMessage(step.label, step.completed));
              })()}
            </ul>
          </div>

          {isComplete && connectionData && (
            <ProjectConnection
              data={connectionData}
              onReload={fetchConnectionData}
              projectName={state.projectName}
              csrfToken={csrfToken}
            />
          )}

          {(error || errorMessage) && (
            <div className="mt3 red f6">
              <span className="red" style="${style}; padding-right: 12px; padding-left: 3px;">✗</span>
              <span>{errorMessage}</span>
            </div>
          )}
        </div>
      )}
      {isComplete && nextScreenUrl && (
        <div className="flex justify-between items-center mt4">
          <p className="f6 gray mb0">Next, we&apos;ll configure your build environment settings.</p>
          <a href={nextScreenUrl} className="btn btn-primary">Continue</a>
        </div>
      )}
    </Fragment>
  );
};

interface ProjectConnectionProps {
  data: ConnectionData;
  onReload: () => Promise<void>;
  projectName: string;
  csrfToken: string;
}

const ProjectConnection = ({ data, onReload, projectName, csrfToken }: ProjectConnectionProps) => {
  const [isRegeneratingDeployKey, setIsRegeneratingDeployKey] = useState(false);
  const [isRegeneratingWebhook, setIsRegeneratingWebhook] = useState(false);

  const handleRegenerateDeployKey = async (e: Event) => {
    e.preventDefault();
    if (!confirm(`Are you sure? This will regenerate a Deployment Key on Repository.`)) {
      return;
    }

    setIsRegeneratingDeployKey(true);
    try {
      const response = await fetch(data.deploy_key_regenerate_url, {
        method: `POST`,
        headers: {
          'Content-Type': `application/json`,
          'X-CSRF-Token': csrfToken || ``,
        },
        body: JSON.stringify({
          name_or_id: projectName
        })
      });

      if (!response.ok) {
        throw new Error(`Failed to regenerate deploy key`);
      }

      await onReload();
    } catch (err) {
      Notice.error(`Error regenerating deploy key: ${err instanceof Error ? err.message : String(err)}`);
    } finally {
      setIsRegeneratingDeployKey(false);
    }
  };

  const handleRegenerateWebhook = async (e: Event) => {
    e.preventDefault();
    setIsRegeneratingWebhook(true);
    try {
      const response = await fetch(data.hook_regenerate_url, {
        method: `POST`,
        headers: {
          'Content-Type': `application/json`,
          'X-CSRF-Token': csrfToken || ``,
        },
        body: JSON.stringify({
          name_or_id: projectName
        })
      });

      if (!response.ok) {
        throw new Error(`Failed to regenerate webhook`);
      }

      await onReload();
    } catch (err) {
      Notice.error(`Error regenerating webhook: ${err instanceof Error ? err.message : String(err)}`);
    } finally {
      setIsRegeneratingWebhook(false);
    }
  };

  return (
    <Fragment>
      <div className="mb3">
        {data.deploy_key === null ? (
          <p className="f6 measure-wide mb3">{data.deploy_key_message}</p>
        ) : (
          <>
            <div className="mb1">
              <label className="b mr1">Deploy Key</label>
              {isRegeneratingDeployKey ? (
                <toolbox.Asset path="images/spinner-2.svg" width="20" height="20" class="v-mid"/>
              ) : (
                <toolbox.Asset path="images/icn-passed.svg" class="v-mid"/>
              )}
              <span className="f5 fw5">
                ·
                <a
                  href="#"
                  onClick={(e) => { void handleRegenerateDeployKey(e); }}
                  className={isRegeneratingDeployKey ? `o-50` : ``}
                  style={isRegeneratingDeployKey ? { pointerEvents: `none` } : {}}
                >
                  {isRegeneratingDeployKey ? `Regenerating...` : `Regenerate`}
                </a>
              </span>
            </div>
            <div className="flex items-center">
              <toolbox.Asset path="images/icn-key.svg" class="mr2"/>
              <div className="f5 f4-m">{data.deploy_key.title}</div>
            </div>
            <div className="code word-wrap">
              ({data.deploy_key.fingerprint})
            </div>
            <div className="f6 gray mt1">Added on {data.deploy_key.created_at}</div>
          </>
        )}
      </div>

      <div className="mb3">
        {data.hook === null ? (
          <p className="f6 measure-wide mb3">{data.hook_message}</p>
        ) : (
          <>
            <div className="mb1">
              <label className="b mr1">Webhook</label>
              {isRegeneratingWebhook ? (
                <toolbox.Asset path="images/spinner-2.svg" width="20" height="20" class="v-mid"/>
              ) : (
                <toolbox.Asset path="images/icn-passed.svg" class="v-mid"/>
              )}
              <span className="f5 fw5">
                ·
                <a
                  href="#"
                  onClick={(e) => { void handleRegenerateWebhook(e); }}
                  className={isRegeneratingWebhook ? `o-50` : ``}
                  style={isRegeneratingWebhook ? { pointerEvents: `none` } : {}}
                >
                  {isRegeneratingWebhook ? `Regenerating...` : `Regenerate`}
                </a>
              </span>
            </div>
            <div>
              <input
                id="webhook"
                type="text"
                className="form-control w-100 mr2"
                value={data.hook.url}
                readOnly
                disabled
              />
            </div>
          </>
        )}
      </div>
    </Fragment>
  );
};

const ZeroState = () => {
  return (
    <div className="mt2 bg-white br3 pa5 shadow-1 center tc">
      <toolbox.Asset path="images/ill-hand-wave.svg" class="db center mb3"/>
      <h3 className="f4 fw4 black-70 mt0 mb3">Finish naming the project and we&apos;ll do the rest.</h3>
    </div>
  );
};
