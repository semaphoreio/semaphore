import { useContext, useState } from "preact/hooks";
import { createContext } from "preact";
import * as types from "../types";
import { createEnvironmentAPI } from "../services/api";
import { useConfig } from "../contexts/ConfigContext";

interface Errors {
  [field: string]: string;
}

export interface EnvironmentState {
  name: string;
  description: string;
  maxInstances: number;
  stages: types.StageConfig[];
  environmentContext: types.EnvironmentContext[];
  projectAccess: types.ProjectAccess[];
  ttlConfig: types.TTLConfig;
}

type Mode = `create` | `edit`;

interface EnvironmentContextValue {
  state: EnvironmentState;
  mode: Mode;

  errors: Errors;
  globalError?: string;

  isSubmitting: boolean;
  isLoading: boolean;

  // Basic Info
  updateName: (name: string) => void;
  updateDescription: (description: string) => void;
  updateMaxInstances: (max: number) => void;

  // Stages
  updatePipelineConfig: (
    stage: types.StageConfig
  ) => (config: types.PipelineConfig) => void;
  addParameter: (
    stage: types.StageConfig
  ) => (param: types.EnvironmentParameter) => void;
  updateParameter: (
    stage: types.StageConfig
  ) => (paramKey: string, param: types.EnvironmentParameter) => void;
  removeParameter: (
    stage: types.StageConfig
  ) => (param: types.EnvironmentParameter) => void;
  addRBACSubject: (
    stage: types.StageConfig
  ) => (subject: types.RBACSubject) => void;
  removeRBACSubject: (
    stage: types.StageConfig
  ) => (subject: types.RBACSubject) => void;

  // TTL Config
  updateTTLConfig: (config: types.TTLConfig) => void;

  // Environment Context
  updateContext: (
    contextKey: string,
    context: types.EnvironmentContext
  ) => void;
  addContext: (context: types.EnvironmentContext) => void;
  removeContext: (context: types.EnvironmentContext) => void;

  // Project Access
  addProjectAccess: (access: types.ProjectAccess) => void;
  removeProjectAccess: (access: types.ProjectAccess) => void;

  // Save actions
  saveEnvironment: () => Promise<void>;

  validate: () => boolean;
  hasErrors: boolean;
}

const defaultStage: types.StageConfig = {
  id: ``,
  name: ``,
  pipeline: {
    projectId: ``,
    projectName: ``,
    projectDescription: null,
    branch: ``,
    pipelineYamlFile: ``,
  },
  parameters: [],
  rbacAccess: [],
};

const defaultState: EnvironmentState = {
  name: ``,
  description: ``,
  maxInstances: 1,
  stages: [
    { ...defaultStage, id: `provisioning`, name: `Provisioning` },
    { ...defaultStage, id: `deployment`, name: `Deployment` },
    { ...defaultStage, id: `deprovisioning`, name: `Deprovisioning` },
  ],
  environmentContext: [],
  projectAccess: [],
  ttlConfig: {
    default_ttl_hours: 24,
    allow_extension: true,
  },
};

export const EnvironmentContext = createContext<EnvironmentContextValue | null>(
  null
);

interface EnvironmentProviderProps {
  children?: any;
  mode?: Mode;
  initialData?: EnvironmentState | null;
  environmentId?: string | null;
}

export const EnvironmentProvider = ({
  children,
  mode = `create`,
  initialData,
  environmentId,
}: EnvironmentProviderProps) => {
  const config = useConfig();
  const [state, setState] = useState<EnvironmentState>(
    initialData || defaultState
  );
  const [errors, setErrors] = useState<Errors>({});
  const [globalError, setGlobalError] = useState<string | undefined>(undefined);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isLoading, setIsLoading] = useState(false);

  const clearError = (field: string) => {
    if (errors[field]) {
      setErrors((prev) => {
        const next = { ...prev };
        delete next[field];
        return next;
      });
    }
  };

  // Basic Info Updates
  const updateName = (name: string) => {
    setState((prev) => ({ ...prev, name }));
    clearError(`name`);
  };

  const updateDescription = (description: string) => {
    setState((prev) => ({ ...prev, description }));
    clearError(`description`);
  };

  const updateMaxInstances = (maxInstances: number) => {
    setState((prev) => ({ ...prev, maxInstances }));
    clearError(`maxInstances`);
  };

  // Stage Updates
  const updatePipelineConfig =
    (stage: types.StageConfig) => (config: types.PipelineConfig) => {
      setState((prev) => {
        const updatedStages = prev.stages.map((s) =>
          s.id === stage.id ? { ...s, pipeline: config } : s
        );
        return { ...prev, stages: updatedStages };
      });
    };

  const addParameter =
    (stage: types.StageConfig) => (param: types.EnvironmentParameter) => {
      setState((prev) => {
        const updatedStages = prev.stages.map((s) =>
          s.id === stage.id
            ? { ...s, parameters: [...(s.parameters || []), param] }
            : s
        );
        return { ...prev, stages: updatedStages };
      });
    };

  const updateParameter =
    (stage: types.StageConfig) =>
      (paramKey: string, param: types.EnvironmentParameter) => {
        setState((prev) => {
          const updatedStages = prev.stages.map((s) => {
            if (s.id === stage.id) {
              const updatedParams = (s.parameters || []).map((p) =>
                p.name === paramKey ? param : p
              );
              return { ...s, parameters: updatedParams };
            }
            return s;
          });
          return { ...prev, stages: updatedStages };
        });
      };

  const removeParameter =
    (stage: types.StageConfig) => (param: types.EnvironmentParameter) => {
      setState((prev) => {
        const updatedStages = prev.stages.map((s) => {
          if (s.id === stage.id) {
            const updatedParams = (s.parameters || []).filter(
              (p) => p.name !== param.name
            );
            return { ...s, parameters: updatedParams };
          }
          return s;
        });
        return { ...prev, stages: updatedStages };
      });
    };

  const addRBACSubject =
    (stage: types.StageConfig) => (subject: types.RBACSubject) => {
      setState((prev) => {
        const updatedStages = prev.stages.map((s) =>
          s.id === stage.id
            ? { ...s, rbacAccess: [...(s.rbacAccess || []), subject] }
            : s
        );
        return { ...prev, stages: updatedStages };
      });
    };

  const removeRBACSubject =
    (stage: types.StageConfig) => (subject: types.RBACSubject) => {
      setState((prev) => {
        const updatedStages = prev.stages.map((s) => {
          if (s.id === stage.id) {
            const updatedAccess = (s.rbacAccess || []).filter(
              (sa) => !(sa.type === subject.type && sa.id === subject.id)
            );
            return { ...s, rbacAccess: updatedAccess };
          }
          return s;
        });
        return { ...prev, stages: updatedStages };
      });
    };

  // Other Updates
  const updateTTLConfig = (config: types.TTLConfig) => {
    setState((prev) => ({ ...prev, ttlConfig: config }));
    clearError(`ttlConfig`);
  };

  const updateContext = (
    contextKey: string,
    context: types.EnvironmentContext
  ) => {
    setState((prev) => {
      const index = prev.environmentContext.findIndex(
        (ec) => ec.name === contextKey
      );
      if (index === -1) return prev;
      const updated = [...prev.environmentContext];
      updated[index] = context;
      return { ...prev, environmentContext: updated };
    });
  };

  const addContext = (context: types.EnvironmentContext) => {
    setState((prev) => ({
      ...prev,
      environmentContext: [...prev.environmentContext, { ...context }],
    }));
  };

  const removeContext = (context: types.EnvironmentContext) => {
    setState((prev) => ({
      ...prev,
      environmentContext: prev.environmentContext.filter(
        (ec) => ec.name !== context.name
      ),
    }));
  };

  const addProjectAccess = (access: types.ProjectAccess) => {
    setState((prev) => ({
      ...prev,
      projectAccess: [...prev.projectAccess, access],
    }));
    clearError(`projectAccess`);
  };

  const removeProjectAccess = (access: types.ProjectAccess) => {
    setState((prev) => ({
      ...prev,
      projectAccess: prev.projectAccess.filter(
        (pa) => pa.projectId !== access.projectId
      ),
    }));
  };

  // Validation
  const validate = (): boolean => {
    const newErrors: Errors = {};
    if (!state.name.trim()) {
      newErrors[`name`] = `Name is required.`;
    }
    if (state.maxInstances < 1) {
      newErrors[`maxInstances`] = `Max instances must be at least 1.`;
    }
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  // Unified Save Method
  const saveEnvironment = async () => {
    setGlobalError(null);
    if (!validate()) return;

    setIsSubmitting(true);
    setIsLoading(true);

    try {
      const api = createEnvironmentAPI(config, environmentId);

      const payload = {
        name: state.name,
        description: state.description,
        max_instances: state.maxInstances,
        stages: state.stages,
        environment_context: state.environmentContext,
        accessible_project_ids: state.projectAccess.map((pa) => pa.projectId),
        ttl_config: state.ttlConfig,
      };

      if (mode === `create`) {
        const newEnvironment = await api.create(payload);
        window.location.href = `/ephemeral_environments/${newEnvironment.id}`;
      } else {
        const updatedEnvironment = await api.update(payload);
        window.location.href = `/ephemeral_environments/${updatedEnvironment.id}`;
      }
    } catch (error) {
      console.error(`Save error:`, error);
      setGlobalError(
        error instanceof Error
          ? error.message
          : `Failed to save environment. Please try again.`
      );
      throw error;
    } finally {
      setIsLoading(false);
      setIsSubmitting(false);
    }
  };

  const hasErrors = Object.keys(errors).length > 0;

  const value: EnvironmentContextValue = {
    state,
    mode,
    errors,
    globalError,
    isSubmitting,
    isLoading,
    updateName,
    updateDescription,
    updateMaxInstances,
    updatePipelineConfig,
    addParameter,
    updateParameter,
    removeParameter,
    addRBACSubject,
    removeRBACSubject,
    updateTTLConfig,
    updateContext,
    addContext,
    removeContext,
    addProjectAccess,
    removeProjectAccess,
    saveEnvironment,
    validate,
    hasErrors,
  };

  return (
    <EnvironmentContext.Provider value={value}>
      {children}
    </EnvironmentContext.Provider>
  );
};

export const useEnvironment = () => {
  const context = useContext(EnvironmentContext);
  if (!context) {
    throw new Error(
      `useEnvironment must be used within an EnvironmentProvider`
    );
  }
  return context;
};
