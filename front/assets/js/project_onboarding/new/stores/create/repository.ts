import { createContext } from "preact";
import { useReducer, useCallback, useContext } from "preact/hooks";
import * as stores from ".";

// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
import { Notice } from "js/notice";

interface Repository {
  url: string;
  name: string;
  full_name: string;
  description: string;
  addable: boolean;
  connected_projects?: Array<{
    name: string;
    url: string;
  }>;
}

interface RepositoryState {
  selectedRepo: Repository | null;
  projectName: string;
  isDuplicate: boolean;
  isCheckingDuplicates: boolean;
  nextIterationName?: string;
  isCreatingProject: boolean;
  repoConnectionUrl?: string;
  projectCreationStatus: {
    checkUrl?: string;
    steps: Array<{
      id: string;
      label: string;
      completed: boolean;
    }>;
    isComplete: boolean;
    error?: string;
    waitingMessage?: string;
    errorMessage?: string;
    ready?: boolean;
    nextScreenUrl?: string;
  };
}

type RepositoryAction =
  | { type: `SELECT_REPOSITORY`, payload: Repository | null, }
  | { type: `SET_PROJECT_NAME`, payload: string, }
  | { type: `START_DUPLICATE_CHECK`, }
  | {
    type: `FINISH_DUPLICATE_CHECK`; payload: {
      connected_projects?: Array<{ name: string, url: string, }>;
      next_iteration_name?: string;
    };
  }
  | { type: `ENABLE_DUPLICATE_MODE`, }
  | { type: `START_PROJECT_CREATION`, }
  | { type: `SET_PROJECT_CHECK_URL`, payload: string, }
  | { type: `SET_REPO_CONNECTION_URL`, payload: string, }
  | {
    type: `UPDATE_PROJECT_STATUS`; payload: {
      steps: Array<{ id: string, label: string, completed: boolean, }>;
      isComplete: boolean;
      error?: string;
      waitingMessage?: string;
      errorMessage?: string;
      ready?: boolean;
      nextScreenUrl?: string;
    };
  }
  | { type: `FINISH_PROJECT_CREATION`, success: boolean, }
  | { type: `RESET`, };

const initialState: RepositoryState = {
  selectedRepo: null,
  projectName: ``,
  isDuplicate: false,
  isCheckingDuplicates: false,
  nextIterationName: undefined,
  isCreatingProject: false,
  repoConnectionUrl: undefined,
  projectCreationStatus: {
    steps: [
      { id: `analyze-repo`, label: `Analyzing repository structure`, completed: false },
      { id: `setup-permissions`, label: `Configuring project permissions`, completed: false },
      { id: `connect-repository`, label: `Setting up repository hooks`, completed: false },
      { id: `connect-cache`, label: `Configuring build cache`, completed: false },
      { id: `connect-artifacts`, label: `Setting up artifact storage`, completed: false }
    ],
    isComplete: false,
    waitingMessage: `Please wait while we set up your project...`
  },
};

function repositoryReducer(state: RepositoryState, action: RepositoryAction): RepositoryState {
  switch (action.type) {
    case `SELECT_REPOSITORY`:
      return {
        ...state,
        selectedRepo: action.payload,
        projectName: action.payload?.name || ``,
        isDuplicate: false,
        isCheckingDuplicates: Boolean(action.payload),
        nextIterationName: undefined
      };
    case `SET_PROJECT_NAME`:
      return {
        ...state,
        projectName: action.payload
      };
    case `START_DUPLICATE_CHECK`:
      return {
        ...state,
        isCheckingDuplicates: true
      };
    case `FINISH_DUPLICATE_CHECK`: {
      if (!state.selectedRepo) return state;

      const updatedRepo = {
        ...state.selectedRepo,
        connected_projects: action.payload.connected_projects
      };

      return {
        ...state,
        selectedRepo: updatedRepo,
        isDuplicate: Boolean(action.payload.connected_projects?.length),
        isCheckingDuplicates: false,
        nextIterationName: action.payload.next_iteration_name
      };
    }
    case `ENABLE_DUPLICATE_MODE`:
      return {
        ...state,
        isDuplicate: false,
        projectName: state.nextIterationName || state.selectedRepo?.name || ``
      };
    case `START_PROJECT_CREATION`:
      return {
        ...state,
        isCreatingProject: true,
        projectCreationStatus: {
          ...state.projectCreationStatus,
          steps: state.projectCreationStatus.steps.map(step => ({ ...step, completed: false })),
          isComplete: false,
          error: undefined,
          errorMessage: undefined,
          waitingMessage: `Please wait while we set up your project...`
        }
      };
    case `SET_PROJECT_CHECK_URL`:
      return {
        ...state,
        projectCreationStatus: {
          ...state.projectCreationStatus,
          checkUrl: action.payload
        }
      };
    case `SET_REPO_CONNECTION_URL`:
      return {
        ...state,
        repoConnectionUrl: action.payload
      };
    case `UPDATE_PROJECT_STATUS`:
      return {
        ...state,
        projectCreationStatus: {
          ...state.projectCreationStatus,
          steps: action.payload.steps,
          isComplete: action.payload.isComplete,
          error: action.payload.error,
          waitingMessage: action.payload.waitingMessage,
          errorMessage: action.payload.errorMessage,
          ready: action.payload.ready,
          nextScreenUrl: action.payload.nextScreenUrl,
        },
      };
    case `FINISH_PROJECT_CREATION`:
      return {
        ...state,
        isCreatingProject: false
      };
    case `RESET`:
      return initialState;
    default:
      return state;
  }
}

export function useRepositoryStore(configState: stores.Config.State) {
  const [state, dispatch] = useReducer(repositoryReducer, initialState);
  const providerState = useContext(stores.Provider.Context);

  const selectRepository = useCallback(async (repo: Repository | null) => {
    dispatch({ type: `START_DUPLICATE_CHECK` });
    if (repo) {
      try {
        const response = await fetch(configState.duplicateCheckUrl, {
          method: `POST`,
          headers: {
            'Content-Type': `application/json`,
            'X-CSRF-Token': configState.csrfToken,
          },
          body: JSON.stringify({
            url: repo.url,
            name: repo.name
          })
        });

        const data = await response.json();

        let connected_projects;
        if (data.projects) {
          connected_projects = data.projects.map((project: { name: string, path: string, }) => ({
            name: project.name,
            url: project.path
          }));
        }

        dispatch({ type: `SELECT_REPOSITORY`, payload: repo });
        dispatch({
          type: `FINISH_DUPLICATE_CHECK`,
          payload: {
            connected_projects,
            next_iteration_name: data.next_iteration_name
          }
        });

      } catch (error) {
        Notice.error(`Failed to check for duplicates. Please try again.`);
        dispatch({
          type: `FINISH_DUPLICATE_CHECK`,
          payload: {
            connected_projects: undefined,
            next_iteration_name: undefined
          }
        });
      }
    }
  }, [configState.csrfToken, configState.duplicateCheckUrl]);

  const setProjectName = (name: string) => {
    dispatch({ type: `SET_PROJECT_NAME`, payload: name });
  };

  const enableDuplicateMode = () => {
    dispatch({ type: `ENABLE_DUPLICATE_MODE` });
  };

  const checkProjectStatus = useCallback(async (checkUrl: string) => {
    try {
      const response = await fetch(checkUrl);
      if (!response.ok) {
        Notice.error(`Failed to check project status`);
        throw new Error(`Failed to check project status`);
      }

      const data = await response.json();

      // Map the deps to our steps
      const updatedSteps = state.projectCreationStatus.steps.map(step => {
        let completed = false;
        switch (step.id) {
          case `analyze-repo`:
            completed = data.deps.repo_analyzed;
            break;
          case `setup-permissions`:
            completed = data.deps.permissions_setup;
            break;
          case `connect-repository`:
            completed = data.deps.connected_to_repository;
            break;
          case `connect-cache`:
            completed = data.deps.connected_to_cache;
            break;
          case `connect-artifacts`:
            completed = data.deps.connected_to_artifacts;
            break;
        }
        return {
          ...step,
          completed
        };
      });

      dispatch({
        type: `UPDATE_PROJECT_STATUS`,
        payload: {
          steps: updatedSteps,
          isComplete: data.ready || false,
          error: data.error,
          waitingMessage: data.waiting_message,
          errorMessage: data.error_message,
          ready: data.ready,
          nextScreenUrl: data.next_screen_url,
        }
      });

      // If not complete and no error, schedule next check
      if (!data.ready && !data.error) {
        setTimeout(() => void checkProjectStatus(checkUrl), 2000);
      } else if (data.ready && data.redirect_to) {
        window.location.href = data.redirect_to;
      }
    } catch (error) {
      dispatch({
        type: `UPDATE_PROJECT_STATUS`,
        payload: {
          steps: state.projectCreationStatus.steps,
          isComplete: false,
          error: `Failed to check project creation status`
        }
      });
    }
  }, [state.projectCreationStatus.steps]);

  const createProject = useCallback(async () => {
    if (!state.selectedRepo) return;

    dispatch({ type: `START_PROJECT_CREATION` });

    try {
      if (!configState.csrfToken) {
        throw new Error(`CSRF token not found`);
      }

      const response = await fetch(`/projects`, {
        method: `POST`,
        headers: {
          'Content-Type': `application/json`,
          'X-CSRF-Token': configState.csrfToken
        },
        body: JSON.stringify({
          integration_type: providerState.state.selectedProvider?.type,
          duplicate: `true`,
          name: state.projectName,
          url: state.selectedRepo.url || ``
        })
      });

      if (!response.ok) {
        Notice.error(`Failed to create project`);
      }

      const data = await response.json();

      if (data.check_url) {
        dispatch({ type: `SET_PROJECT_CHECK_URL`, payload: data.check_url });
        if (data.repo_connection_url) {
          dispatch({ type: `SET_REPO_CONNECTION_URL`, payload: data.repo_connection_url });
        }
        void checkProjectStatus(data.check_url as string);
      }
    } catch (error) {
      dispatch({ type: `FINISH_PROJECT_CREATION`, success: false });
    }
  }, [state.selectedRepo, state.projectName, providerState.state.selectedProvider, configState.csrfToken, checkProjectStatus]);

  const reset = () => {
    dispatch({ type: `RESET` });
  };

  return {
    state,
    selectRepository,
    setProjectName,
    enableDuplicateMode,
    createProject,
    reset
  };
}

interface RepositoryContextType {
  state: RepositoryState;
  selectRepository: (repo: Repository | null) => void;
  setProjectName: (name: string) => void;
  enableDuplicateMode: () => void;
  createProject: () => Promise<void>;
  reset: () => void;
}

export const Context = createContext<RepositoryContextType>({
  state: initialState,
  selectRepository: () => { 
    throw new Error(`Repository context not initialized: selectRepository`);
  },
  setProjectName: () => { 
    throw new Error(`Repository context not initialized: setProjectName`);
  },
  enableDuplicateMode: () => { 
    throw new Error(`Repository context not initialized: enableDuplicateMode`);
  },
  createProject: () => { 
    throw new Error(`Repository context not initialized: createProject`);
  },
  reset: () => { 
    throw new Error(`Repository context not initialized: reset`);
  }
});
