
import { useContext, useEffect, useReducer, useState } from "preact/hooks";
import * as toolbox from "js/toolbox";
import * as Store from "./store";
import { TargetedEvent } from "preact/compat";

export const App = () => {
  const [onboardingState, onboardingDispatch] = useReducer(
    Store.Request.Reducer,
    Store.Request.EmptyState,
  );

  const [waitUrl, setWaitUrl] = useState(``);

  const hasWaitUrl = waitUrl !== ``;

  return (
    <Store.Request.Context.Provider
      value={{ state: onboardingState, dispatch: onboardingDispatch }}
    >
      {!hasWaitUrl && <OnboardingPage setWaitUrl={setWaitUrl}/>}
      {hasWaitUrl && <WaitPage setWaitUrl={setWaitUrl} waitUrl={waitUrl}/>}
    </Store.Request.Context.Provider>
  );
};

interface WaitPageProps {
  waitUrl: string;
  setWaitUrl: (url: string) => void;
}
interface WaitResponse {
  location: string;
}
const WaitPage = (props: WaitPageProps) => {
  const { dispatch: requestDispatch } = useContext(Store.Request.Context);
  const MAX_ATTEMPTS = 20;
  const RETRY_DELAY_MS = 2000;

  useEffect(() => {
    let attempts = 0;
    const checkUrl = async () => {
      if (attempts >= MAX_ATTEMPTS) {
        requestDispatch({ type: `SET_ERROR` });
        requestDispatch({ type: `ADD_ERROR`, value: `Max attempts reached` });
        return;
      }
      const { data, error, status } =
        await toolbox.APIRequest.get<WaitResponse>(props.waitUrl);

      attempts++; // Increment attempts counter
      if (error) {
        requestDispatch({ type: `SET_ERROR` });
        requestDispatch({ type: `ADD_ERROR`, value: error });
      } else if (status === 201) {
        requestDispatch({ type: `SET_LOADED` });
        window.location.href = data.location;
        return;
      } else {
        requestDispatch({ type: `SET_LOADING` });
        setTimeout(() => void checkUrl(), RETRY_DELAY_MS);
      }
    };
    void checkUrl();
    return () => {
      attempts = MAX_ATTEMPTS; // Prevent further calls if the component is unmounted
    };
  }, [props.waitUrl, requestDispatch]);

  return (
    <div
      className="bg-white shadow-1 w-100 pa3 pa4-m"
      style="min-height: calc(100vh - 90px)"
    >
      <div className="mw8 center pa5-l">
        <div className="flex flex-column flex-row-l">
          <div className="w-100 ph4-l">
            <h1 className="f2 f1-m lh-title mb1">
              We&apos;re setting up your organization
            </h1>
            <p className="f3-m mb4">
              Please wait while we create your organization. This should only
              take a few seconds.
            </p>
            <toolbox.Asset path="images/spinner.svg" className="spinner"/>
          </div>
        </div>
      </div>
    </div>
  );
};

interface OnboardingPageProps {
  setWaitUrl: (url: string) => void;
}

const OnboardingPage = (props: OnboardingPageProps) => {
  const { state, dispatch: requestDispatch } = useContext(
    Store.Request.Context,
  );
  const { config } = useContext(Store.Config.Context);
  const [organizationUrl, setOrganizationUrl] = useState(``);

  interface Request {
    location: string;
  }

  const handleSubmit = async (e: Event) => {
    e.preventDefault();
    if (isLoaded) return;
    requestDispatch({ type: `CLEAN` });
    requestDispatch({ type: `SET_LOADING` });
    const { data, error } = await toolbox.APIRequest.post<Request>(
      config.createOrganizationURL,
      { url: organizationUrl },
    );
    if (error) {
      requestDispatch({ type: `SET_ERROR` });
      requestDispatch({ type: `ADD_ERROR`, value: error });
    } else {
      props.setWaitUrl(data.location);
      requestDispatch({ type: `SET_LOADED` });
    }
  };

  const handleInput = (e: TargetedEvent<HTMLInputElement>) => {
    setOrganizationUrl(e.currentTarget.value);
  };

  const isLoading = state.status === Store.Request.Status.Loading;
  const isLoaded = state.status === Store.Request.Status.Loaded;
  const isEmpty = state.status === Store.Request.Status.Empty;
  const isErrored = state.status === Store.Request.Status.Error;

  return (
    <div
      className="bg-white shadow-1 w-100 pa3 pa4-m"
      style="min-height: calc(100vh - 90px)"
    >
      <div className="mw8 center pa5-l">
        <div className="flex flex-column flex-row-l">
          <div className="w-100 ph4-l">
            <h1 className="f2 f1-m lh-title mb1">Create a new organization</h1>
            <p className="f3-m mb4">
              Tell us more about this organization and we’ll set you up in two
              minutes.
            </p>
            <toolbox.Asset
              path="images/ill-couple-in-office.svg"
              className="db mw4 mw-none-m mb4"
            />
          </div>

          <div className="w-100 ph4-l">
            <label className="b db mb1">Semaphore URL</label>
            <div className="input-group">
              <input
                value={organizationUrl}
                onInput={handleInput}
                className="form-control w-50 tr"
                required
                disabled={isLoading}
                type="text"
              />
              <input
                type="text"
                className="form-control w-50"
                value=".semaphoreci.com"
                disabled
              />
            </div>

            <p className="f6 gray mv1">You can always change your URL later</p>

            <ErrorDisplay/>
            <form onSubmit={(e) => void handleSubmit(e)}>
              <button
                disabled={isLoading}
                className={`btn ${
                  isLoaded ? `btn-green` : `btn-primary`
                } btn-large w-100 mt3`}
              >
                {(isEmpty || isErrored) && `Save & Continue…`}
                {isLoaded && `Organization created!`}
                {isLoading && (
                  <toolbox.Asset
                    path="images/spinner.svg"
                    className="spinner"
                  />
                )}
              </button>
            </form>
          </div>
        </div>
      </div>
    </div>
  );
};

const ErrorDisplay = () => {
  const { state } = useContext(Store.Request.Context);
  if (state.errors.length === 0) {
    return null;
  }

  return (
    <div className="red pt2">
      {state.errors.map((error, index) => (
        <p key={index}>{error}</p>
      ))}
    </div>
  );
};
