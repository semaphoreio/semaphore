import { createContext } from "preact";
import { useContext, useState, useEffect } from "preact/hooks";

export interface AgentType {
  type: string;
  available_os_images: string[];
}

export interface State {
  yamlPath: string;
  selectedAgentType?: AgentType;
  yamlContent: string;
}

export interface Store {
  state: State;
  setYamlPath: (path: string) => void;
  setSelectedAgentType: (agentType: AgentType) => void;
  subscribe: (listener: () => void) => () => void;
}

const generateYamlContent = (agentType: AgentType | null) => {
  return `version: v1.0
name: Hello Semaphore # <-- Your pipeline name
agent:
  machine:
    type: ${agentType?.type || `not-selected`} # <-- The agent that will run your jobs
    
    # We will define the rest of the pipeline
    # in the next step`;
};

const initialState: State = {
  yamlPath: `.semaphore/semaphore.yml`,
  yamlContent: generateYamlContent(null),
};

export const Context = createContext<Store | null>(null);

export function createEnvironmentStore(): Store {
  let currentState: State = { ...initialState };
  const listeners = new Set<() => void>();

  const store: Store = {
    get state() {
      return currentState;
    },
    setYamlPath(path: string) {
      currentState = { ...currentState, yamlPath: path };
      listeners.forEach(l => l());
    },
    setSelectedAgentType(agentType: AgentType) {
      currentState = {
        ...currentState,
        selectedAgentType: agentType,
        yamlContent: generateYamlContent(agentType),
      };
      listeners.forEach(l => l());
    },
    subscribe(listener: () => void) {
      listeners.add(listener);
      return () => listeners.delete(listener);
    }
  };

  return store;
}

export function useEnvironmentStore() {
  const store = useContext(Context);
  if (!store) {
    throw new Error(`useEnvironmentStore must be used within an EnvironmentProvider`);
  }

  const [state, setState] = useState<State>(store.state);

  useEffect(() => {
    const unsubscribe = store.subscribe(() => {
      setState({ ...store.state });
    });
    return unsubscribe;
  }, [store]);

  return {
    state,
    setYamlPath: store.setYamlPath,
    setSelectedAgentType: store.setSelectedAgentType,
  };
}
