/* eslint-disable quotes */
import { Fragment } from "preact";
import { useContext, useEffect, useLayoutEffect } from "preact/hooks";
import * as stores from "../../stores";
import * as components from "../../components";
import * as toolbox from "js/toolbox";
import { useNavigate, useParams } from "react-router-dom";
import type { IntegrationType } from "../../types/provider";
import { useSteps } from "../../stores/create/steps";

export const ChooseRepo = () => {
  const { integrationType } = useParams();
  const { dispatch } = useSteps();
  const steps = [
    { id: `select-type`, title: `Select project type` },
    { id: `setup-project`, title: `Setup the project` },
    { id: `select-environment`, title: `Select the environment` },
    { id: `setup-workflow`, title: `Setup workflow` },
  ];

  useLayoutEffect(() => {
    dispatch([`SET_STEPS`, steps]);
    dispatch([`SET_CURRENT`, `setup-project`]);
  }, []);

  const navigate = useNavigate();
  const integration = integrationType as IntegrationType;

  const configState = useContext(stores.Create.Config.Context);
  const { setProvider } = useContext(stores.Create.Provider.Context);

  useEffect(() => {
    if (integration && configState.providers) {
      const provider = configState.providers.find(p => p.type === integration);

      if (provider) {
        setProvider(provider);
      } else {
        navigate(`/`);
      }
    }
  }, []);

  const store = stores.Create.Repository.useRepositoryStore(configState);

  return (
    <stores.Create.Repository.Context.Provider value={store}>
      <ChooseRepoContent/>
    </stores.Create.Repository.Context.Provider>
  );
};

const ChooseRepoContent = () => {
  const configState = useContext(stores.Create.Config.Context);
  const { state: providerState } = useContext(stores.Create.Provider.Context);
  const { state, setProjectName, enableDuplicateMode, createProject } =
    useContext(stores.Create.Repository.Context);

  // Wait for provider to be set
  if (!providerState.selectedProvider) {
    return null;
  }

  const { selectedProvider } = providerState;
  const { user, scopeUrls } = configState;

  // Check if we need to show scope content instead of repository selection
  const shouldShowScopeContent = user && (
    (selectedProvider.type === 'github_app' && user.github_scope === 'NONE') ||
    (selectedProvider.type === 'github_oauth_token' && ['NONE', 'EMAIL'].includes(user.github_scope)) ||
    (selectedProvider.type === 'bitbucket' && ['NONE', 'EMAIL'].includes(user.bitbucket_scope)) ||
    (selectedProvider.type === 'gitlab' && ['NONE', 'EMAIL'].includes(user.gitlab_scope))
  );

  const repositoriesUrl = `${configState.repositoriesUrl}?integration_type=${selectedProvider.type}`;

  return (
    <div className="flex-l">
      {/* <!-- LEFT SIDE --> */}
      <components.InfoPanel
        svgPath="images/ill-girl-looking-down.svg"
        title="Connect repository"
        subtitle="Configure repository access and integration settings."
        additionalInfo="Deploy keys enable read-only repository access. Webhooks trigger automated builds on code changes."
      />
      {/* <!-- RIGHT SIDE --> */}
      <div className="w-two-thirds">

        <div className="pb3 mb3 bb b--black-10">
          <div className="flex justify-between items-center">
            <div>
              <h2 className="f3 fw6 mb2">Repository Details</h2>
              <p className="black-70 mv0">
                Configure access credentials and integration settings.
              </p>
            </div>
          </div>
        </div>

        {shouldShowScopeContent ? (
          <components.ScopeContent
            selectedProvider={selectedProvider}
            user={user}
            scopeUrls={scopeUrls}
            userProfileUrl={configState.userProfileUrl}
            csrfToken={configState.csrfToken}
          />
        ) : (

          <Fragment>
            <p className="f4 f3-m mb0">Repository URL</p>
            <p className="f6 gray mb1">
                The Git repository address where your code is hosted, you can use
                repository name or url to search.
            </p>

            <components.RepositorySelector repositoriesUrl={repositoriesUrl}/>

            {state.selectedRepo?.connected_projects && state.isDuplicate && (
              <components.DuplicateWarning
                connectedProjects={state.selectedRepo.connected_projects}
                onDuplicateClick={enableDuplicateMode}
              />
            )}
            <div className="mt2">
              <p className="f4 f3-m mb0">Project name</p>
              <p className="f6 gray mb1">
                A unique identifier for this project in Semaphore
              </p>
              <div className="flex items-center">
                <div className="relative flex items-center ba b--black-20 br2 bg-white flex-auto mr2">
                  <toolbox.Asset
                    path="images/icn-project.svg"
                    class="flex-shrink-0 mh2"
                    style="width: 16px; height: 16px;"
                  />
                  <input
                    type="text"
                    id="project-name"
                    className="form-control w-100 bn"
                    style="outline: none; box-shadow: none;"
                    value={state.projectName}
                    placeholder="project-name"
                    disabled={
                      !state.selectedRepo ||
                      state.isCheckingDuplicates ||
                      (state.isDuplicate &&
                        state.selectedRepo?.connected_projects?.length > 0) ||
                      state.isCreatingProject ||
                      state.projectCreationStatus.isComplete
                    }
                    onInput={(e) =>
                      setProjectName((e.target as HTMLInputElement).value.replace(/\s/g, '_'))
                    }
                  />
                  {state.isCheckingDuplicates && (
                    <toolbox.Asset path="images/spinner-2.svg"/>
                  )}
                </div>
                <button
                  className="btn btn-primary"
                  disabled={
                    !state.selectedRepo ||
                    state.isCheckingDuplicates ||
                    state.isDuplicate ||
                    state.isCreatingProject ||
                    state.projectCreationStatus.isComplete
                  }
                  onClick={(e) => {
                    e.preventDefault();
                    void createProject();
                  }}
                >
                  ✓
                </button>
              </div>
            </div>

            <div className="mt2">
              <components.ProjectStatus
                showZeroState={!state.selectedRepo ||
                  state.isCheckingDuplicates ||
                  state.isDuplicate ||
                  state.isCreatingProject ||
                  state.projectCreationStatus.isComplete}
                isCreatingProject={state.isCreatingProject}
                steps={state.projectCreationStatus.steps}
                isComplete={state.projectCreationStatus.isComplete}
                error={state.projectCreationStatus.error}
                waitingMessage={state.projectCreationStatus.waitingMessage}
                errorMessage={state.projectCreationStatus.errorMessage}
                nextScreenUrl={state.projectCreationStatus.nextScreenUrl}
                repoConnectionUrl={state.repoConnectionUrl}
                csrfToken={configState.csrfToken}
              />
            </div>
          </Fragment>
        )}
      </div>
    </div>
  );
};
