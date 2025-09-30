import { Box } from "js/toolbox";
import { StageConfiguration } from "./StageConfiguration";
import { ProjectAccessConfiguration } from "./ProjectAccessConfiguration";
import { TTLSelector } from "./TTLSelector";
import { EnvironmentContextList } from "./EnvironmentContextList";
import {
  EnvironmentProvider,
  useEnvironment,
} from "../contexts/EnvironmentContext";
import { useProjects } from "../contexts/ProjectsContext";

interface EnvironmentFormProps {
  environmentId?: string;
}
export const EnvironmentForm = (props: EnvironmentFormProps) => {
  const { environmentId } = props;
  const mode = environmentId ? `edit` : `create`;
  return (
    <EnvironmentProvider environmentId={environmentId} mode={mode}>
      <div className="bg-white br3 ba b--black-10">
        <form onSubmit={(e) => e.preventDefault()}>
          <BasicConfiguration/>

          <StagesConfiguration/>

          <EnvironmentContextSection/>
          <ProjectAccessSection/>
          <TTLConfiguration/>

          <FormActions/>
        </form>
      </div>
    </EnvironmentProvider>
  );
};

const BasicConfiguration = () => {
  const { state, updateName, updateDescription, updateMaxInstances, errors } =
    useEnvironment();
  return (
    <div className="pa4">
      <h2 className="f3 mb4">Basic Configuration</h2>

      <div className="mb2">
        <label className="db fw6 lh-copy mb2">
          Name: <span className="red">*</span>
        </label>
        <input
          type="text"
          id="name"
          className={`form-control pa2 db w-100 ${errors.name ? `b--red` : ``}`}
          value={state.name}
          onChange={(e) => updateName((e.target as HTMLInputElement).value)}
          placeholder="e.g., Development Environment"
        />
        {errors.name && <small className="red db mt1">{errors.name}</small>}
      </div>

      <div className="mb2">
        <label className="db fw6 lh-copy mb2">Description:</label>
        <textarea
          id="name"
          className={`form-control pa2 db w-100 ${
            errors.description ? `b--red` : ``
          }`}
          value={state.description}
          onChange={(e) =>
            updateDescription((e.target as HTMLInputElement).value)
          }
          placeholder="Brief description of this environment type"
        />
        {errors.description && (
          <small className="red db mt1">{errors.description}</small>
        )}
      </div>

      <div className="mb2">
        <label className="db fw6 lh-copy mb2">
          Max number of instances: <span className="red">*</span>
        </label>
        <input
          type="number"
          id="max_instances"
          className={`form-control pa2 db w-30 ${
            errors.maxInstances ? `b--red` : ``
          }`}
          value={state.maxInstances}
          onChange={(e) =>
            updateMaxInstances(
              parseInt((e.target as HTMLInputElement).value) || 1
            )
          }
        />
        {errors.maxInstances && (
          <small className="red db mt1">{errors.maxInstances}</small>
        )}
      </div>
    </div>
  );
};

const EnvironmentContextSection = () => {
  const { state, addContext, updateContext, removeContext, isSubmitting } =
    useEnvironment();

  return (
    <div className="bt b--black-10 pa4">
      <h2 className="f3 mb3">Environment Context</h2>
      <Box type="info" className="mb3">
        <p className="ma0">
          Environment context variables are set during provisioning and are
          available globally to all stages throughout the environment lifecycle.
        </p>
      </Box>

      <EnvironmentContextList
        contexts={state.environmentContext}
        onContextAdded={addContext}
        onContextRemoved={removeContext}
        onContextUpdated={updateContext}
        disabled={isSubmitting}
      />
    </div>
  );
};

const ProjectAccessSection = () => {
  const { state, addProjectAccess, removeProjectAccess, isSubmitting } =
    useEnvironment();
  const { projects, loading } = useProjects();

  return (
    <div className="bt b--black-10 pa4">
      <h2 className="f3 mb3">Access Control</h2>
      <ProjectAccessConfiguration
        projects={projects}
        onProjectAdded={addProjectAccess}
        onProjectRemoved={removeProjectAccess}
        projectAccess={state.projectAccess}
        disabled={isSubmitting || loading}
      />
    </div>
  );
};
const StagesConfiguration = () => {
  const {
    state,
    updatePipelineConfig,
    updateParameter,
    addParameter,
    removeParameter,
    addRBACSubject,
    removeRBACSubject,
  } = useEnvironment();
  return (
    <div className="bt b--black-10 pa4">
      <h2 className="f3 mb3">Pipeline Configuration</h2>
      <Box type="info" className="mb4">
        <p className="ma0">
          Configure pipelines, parameters, and access control for each stage of
          the environment lifecycle.
        </p>
      </Box>

      <div className="w-100 flex flex-column gap-2">
        {state.stages.map((stage) => (
          <StageConfiguration
            key={stage.id}
            stage={stage}
            onPipelineUpdate={updatePipelineConfig(stage)}
            onParameterRemoved={removeParameter(stage)}
            onParameterUpdated={updateParameter(stage)}
            onParameterAdded={addParameter(stage)}
            onSubjectAdded={addRBACSubject(stage)}
            onSubjectRemoved={removeRBACSubject(stage)}
          />
        ))}
      </div>
    </div>
  );
};

const TTLConfiguration = () => {
  const { state, updateTTLConfig, isSubmitting } = useEnvironment();
  return (
    <div className="bt b--black-10 pa4">
      <h2 className="f3 mb3">Lifecycle Management</h2>
      <TTLSelector
        ttlConfig={state.ttlConfig}
        onTTLChange={updateTTLConfig}
        disabled={isSubmitting}
      />
    </div>
  );
};

const FormActions = () => {
  const { save, reset, canSubmit, isDirty, isSubmitting, mode } =
    useEnvironment();

  return (
    <div className="bt b--black-10 pa4 flex justify-end">
      <div className="flex items-center gap-3">
        {mode == `edit` && isDirty && (
          <>
            <span className="unsaved-indicator">Unsaved changes</span>

            <button
              type="button"
              className="btn btn-secondary"
              onClick={reset}
              disabled={!isDirty}
            >
              Reset
            </button>
          </>
        )}

        <button
          type="submit"
          onClick={save}
          disabled={!canSubmit}
          className="btn btn-primary mr3"
        >
          {isSubmitting ? `Saving...` : mode === `create` ? `Create` : `Update`}
        </button>
      </div>
    </div>
  );
};
