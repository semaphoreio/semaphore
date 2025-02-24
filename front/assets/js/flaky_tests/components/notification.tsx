import {
  Dispatch,
  StateUpdater,
  useContext,
  useEffect,
  useLayoutEffect,
  useReducer,
  useState,
} from "preact/hooks";
import * as stores from "./../stores";
import * as types from "./../types";
import * as toolbox from "js/toolbox";
import { Headers } from "../network/request";
import { WebhookSettings } from "../types/webhook_settings";
import { Fragment } from "preact";
// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
import { Notice } from "js/notice";

interface NotificationProps {
  signal: boolean;
  setSignal: Dispatch<StateUpdater<boolean>>;
  whenDone: () => void;
}

export const Notification = (props: NotificationProps) => {
  const config = useContext(stores.Config.Context);
  const [request, dispatchRequest] = useReducer(stores.Request.Reducer, {
    url: new URL(config.webhookSettingsURL, location.origin),
    status: types.RequestStatus.Zero,
  });

  const [settings, setSettings] = useState<WebhookSettings>(
    new WebhookSettings()
  );
  const [active, setActive] = useState<boolean>(false);

  // first, try to fetch notification settings, to see if there's a notification already
  useEffect(() => {
    dispatchRequest({ type: `SET_METHOD`, value: `GET` });
    dispatchRequest({ type: `FETCH` });
  }, []);

  const loadWebhookSettings = async () => {
    return await fetch(request.url, {
      method: request.method,
      credentials: `same-origin`,
      headers: Headers(`application/json`),
    })
      .then((res) => res.json())
      .then((json) => {
        const ws = WebhookSettings.fromJSON(json.webhook_settings);
        setSettings(ws);
        setActive(ws.enabled);
        props.setSignal(ws.enabled);
        dispatchRequest({
          type: `SET_STATUS`,
          value: types.RequestStatus.Success,
        });
      })
      .catch(() => {
        props.setSignal(false);
        setActive(false);
        dispatchRequest({
          type: `SET_STATUS`,
          value: types.RequestStatus.Zero,
        });
      });
  };

  const createWebhookSettings = async () => {
    return await fetch(request.url, {
      method: request.method,
      credentials: `same-origin`,
      body: request.body,
      headers: Headers(`application/json`),
    })
      .then((res) => {
        if (!res.ok) {
          throw new Error(`Failed to create webhook settings`);
        }
        return res.json();
      })
      .then((json) => {
        const ws = WebhookSettings.fromJSON(json);
        setSettings(ws);
        dispatchRequest({
          type: `SET_STATUS`,
          value: types.RequestStatus.Success,
        });
        Notice.notice(`Notification settings saved`);
        props.setSignal(ws.enabled);
        setActive(ws.enabled);
        props.whenDone();
      })
      .catch(() => {
        dispatchRequest({
          type: `SET_STATUS`,
          value: types.RequestStatus.Error,
        });
        Notice.error(`Failed to save webhook settings`);
      });
  };
  const updateWebhookSettings = async () => {
    return await fetch(request.url, {
      method: request.method,
      credentials: `same-origin`,
      body: request.body,
      headers: Headers(`application/json`),
    })
      .then((response) => {
        if (!response.ok) {
          dispatchRequest({
            type: `SET_STATUS`,
            value: types.RequestStatus.Error,
          });
          Notice.error(`Failed to update webhook settings`);
          return;
        }

        dispatchRequest({
          type: `SET_STATUS`,
          value: types.RequestStatus.Success,
        });
        if (settings.enabled) {
          Notice.notice(`Notification settings updated`);
        } else {
          Notice.notice(`Notification deactivated`);
        }
        props.setSignal(settings.enabled);
        setActive(settings.enabled);
        props.whenDone();
      })
      .catch(() => {
        dispatchRequest({
          type: `SET_STATUS`,
          value: types.RequestStatus.Error,
        });
      });
  };

  useLayoutEffect(() => {
    if (request.status == types.RequestStatus.Fetch) {
      dispatchRequest({
        type: `SET_STATUS`,
        value: types.RequestStatus.Loading,
      });
      switch (request.method) {
        case `GET`:
          loadWebhookSettings().catch(() => {
            props.setSignal(false);
          });
          break;
        case `POST`:
          createWebhookSettings().catch(() => {
            Notice.error(`Failed to update webhook settings`);
          });
          break;
        case `PUT`:
          updateWebhookSettings().catch(() => {
            Notice.error(`Failed to update webhook settings`);
          });
          break;
      }
    }
  }, [request.status]);

  const validateWebhookUrl = (url: string): boolean => {
    return url.startsWith(`https://`);
  };

  const onSave = () => {
    //check if webhook url is valid
    if (!validateWebhookUrl(settings.webhook_url)) {
      Notice.error(`Invalid webhook URL, it should start with "https://"`);
      return;
    }

    if (settings.id?.length > 0) {
      dispatchRequest({ type: `SET_METHOD`, value: `PUT` });
    } else {
      dispatchRequest({ type: `SET_METHOD`, value: `POST` });
    }

    dispatchRequest({ type: `SET_BODY`, value: JSON.stringify(settings) });
    dispatchRequest({ type: `FETCH` });
  };

  const onWebhookUrlChange = (e: any) => {
    const target = e.target as HTMLInputElement;
    settings.webhook_url = target.value;
    setSettings(settings);
  };

  const onBranchesChange = (e: any) => {
    const target = e.target as HTMLInputElement;
    settings.branches = target.value
      .split(`,`)
      .map((branch) => branch.trim())
      .filter((branch) => branch.length > 0);
    setSettings(settings);
  };

  const onGreedyChange = (e: any) => {
    const target = e.target as HTMLInputElement;
    if (target.checked && target.value === `yes`) {
      settings.greedy = true;
    } else {
      settings.greedy = false;
    }
    setSettings(settings);
  };

  const onActiveClick = () => {
    const result = confirm(
      `"You're about to activate this Notification. Are you sure?"`
    );
    if (result) {
      setActive(true);
      settings.enabled = true;
      setSettings(settings);
    }
  };

  const onDeactivateClick = () => {
    const result = confirm(
      `You're about to deactivate this Notification. Are you sure?`
    );
    if (result) {
      setActive(false);
      settings.enabled = false;
      setSettings(settings);
    }
  };

  return (
    <Fragment>
      <div>
        <div className="flex justify-between items-baseline">
          <h2 className="f3 b mb0">Notifications</h2>
          <a
            href="https://docs.semaphoreci.com/essentials/flaky-tests/#notifications"
            target="_blank"
            rel="noopener noreferrer"
          >
            <toolbox.Asset className="pointer" path="images/icn-info-15.svg"/>
          </a>
        </div>

        <p className="mb3">
          Trigger a notification to your webhook whenever a new flaky test is
          detected.
        </p>

        <div className="mb3 br2 ba ph3 pv1 b--lightest-gray">
          <h2 className="f4 b mb2">Flaky test alert frequency?</h2>
          <div className="flex flex-column">
            <div>
              <label>
                <input
                  type="radio"
                  name="greedy"
                  className="mr1"
                  value={`no`}
                  checked={!settings?.greedy}
                  onClick={onGreedyChange}
                ></input>
                Only new flaky tests
              </label>
            </div>

            <div>
              <label>
                <input
                  type="radio"
                  name="greedy"
                  className="mr1"
                  value={`yes`}
                  checked={settings?.greedy}
                  onClick={onGreedyChange}
                ></input>
                Every time test flakes
              </label>
            </div>
          </div>
        </div>

        <div className="mb3">
          <label htmlFor="webhook_url" className="db b mb1">
            Endpoint
            <span className="f6 normal gray"> · HTTPS is required</span>
          </label>
          <input
            id="webhook_url"
            type="text"
            className="form-control w-100"
            placeholder="https://example.com/webhook"
            value={settings?.webhook_url}
            onInput={onWebhookUrlChange}
          />
        </div>

        <div className="mb3">
          <label htmlFor="branches" className="db b mb1">
            Branches
            <span className="f6 normal gray"> · optional</span>
          </label>
          <input
            id="branches"
            type="text"
            className="form-control w-100"
            placeholder="e.g. master,prod-*,.*"
            value={settings?.branches.join(` `)}
            onInput={onBranchesChange}
          />
          <p className="f6 mt1 mb0 nb1">
            Comma separated, regular expressions allowed
          </p>
        </div>

        <div className="flex items-center justify-between">
          {active && (
            <div className="flex items-center">
              <span className="ph1 br2 bg-green white f6">Active</span>
              <a
                className="ml2 gray underline pointer"
                onClick={onDeactivateClick}
                rel="nofollow"
              >
                Deactivate
              </a>
            </div>
          )}
          {!active && (
            <div className="flex items-center">
              <span className="ph1 br2 bg-gray white f6">Inactive</span>
              <a
                className="ml2 gray underline pointer"
                onClick={onActiveClick}
                rel="nofollow"
              >
                Activate
              </a>
            </div>
          )}
          <div className="flex">
            <button className="btn btn-primary mr2" onClick={onSave}>
              Save
            </button>
            <button
              className="btn btn-secondary"
              onClick={() => props.whenDone()}
            >
              Cancel
            </button>
          </div>
        </div>
      </div>
    </Fragment>
  );
};
