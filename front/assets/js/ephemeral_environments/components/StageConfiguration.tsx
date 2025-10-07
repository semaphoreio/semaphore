import { useState } from "preact/hooks";
import { Box, MaterializeIcon, RichSelect } from "js/toolbox";
import * as types from "../types";
import { ParametersList } from "./ParametersList";
import { RBACSubjectSelector } from "./RBACSubjectSelector";
import { useProjects } from "../contexts/ProjectsContext";
import pluralize from "js/toolbox/pluralize";
import { StageIcon } from "../utils/elements";

interface StageConfigurationProps {
  stage: types.StageConfig;
  onPipelineUpdate: (config: types.PipelineConfig) => void;
  onParameterAdded: (param: types.EnvironmentParameter) => void;
  onParameterUpdated: (paramKey: string, param: types.EnvironmentParameter) => void;
  onParameterRemoved: (param: types.EnvironmentParameter) => void;
  onSubjectAdded: (subject: types.RBACSubject) => void;
  onSubjectRemoved: (subject: types.RBACSubject) => void;
}

export const StageConfiguration = (props: StageConfigurationProps) => {
  const {
    stage,
    onPipelineUpdate,
    onParameterAdded,
    onParameterRemoved,
    onParameterUpdated,
    onSubjectAdded,
    onSubjectRemoved,
  } = props;
  const [expanded, setExpanded] = useState(false);

  return (
    <div className="ba b--black-10 br2">
      <div className="pa3">
        <div className="flex items-start gap-2 flex-wrap">
          <div className="flex-1 flex items-center gap-1">
            <StageIcon stageId={stage.id}/>
            <label className="db fw6">{stage.name}</label>
          </div>

          <div className="flex-3 flex flex-column gap-2">
            <PipelineConfiguration pipeline={stage.pipeline} onPipelineUpdate={onPipelineUpdate}/>
            <StageOverview stage={stage}/>

            <button type="button" className="btn btn-link pa0 flex items-center" onClick={() => setExpanded(!expanded)}>
              <MaterializeIcon name={expanded ? `expand_less` : `expand_more`}/>
              {expanded ? `Hide` : `Show`} Configuration
            </button>

            {expanded && (
              <StageTabs
                className="mt2"
                stage={stage}
                onParameterAdded={onParameterAdded}
                onParameterRemoved={onParameterRemoved}
                onParameterUpdated={onParameterUpdated}
                onSubjectAdded={onSubjectAdded}
                onSubjectRemoved={onSubjectRemoved}
              />
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

interface StageTabsProps {
  stage: types.StageConfig;
  onParameterAdded: (param: types.EnvironmentParameter) => void;
  onParameterUpdated: (paramKey: string, param: types.EnvironmentParameter) => void;
  onParameterRemoved: (param: types.EnvironmentParameter) => void;
  onSubjectAdded: (subject: types.RBACSubject) => void;
  onSubjectRemoved: (subject: types.RBACSubject) => void;
  className?: string;
}

const StageTabs = (props: StageTabsProps) => {
  const {
    stage,
    onParameterRemoved,
    onParameterUpdated,
    onParameterAdded,
    onSubjectAdded,
    onSubjectRemoved,
    className,
  } = props;
  const paramCount = stage.parameters?.length || 0;
  const rbacCount = stage.rbacAccess?.length || 0;
  const [activeTab, setActiveTab] = useState<`parameters` | `rbac`>(`parameters`);

  return (
    <div className={className}>
      <div className="flex bb b--black-10 bg-white gap-2">
        <button
          type="button"
          className={`pv2 bn bg-transparent pointer flex items-center ${
            activeTab === `parameters` ? `fw6` : `hover-bg-near-white`
          }`}
          onClick={() => setActiveTab(`parameters`)}
        >
          <MaterializeIcon name="settings" className="mr1 f7"/>
          Parameters ({paramCount})
        </button>
        <button
          type="button"
          className={`pv2 bn bg-transparent pointer flex items-center ${
            activeTab === `rbac` ? `fw6` : `hover-bg-near-white`
          }`}
          onClick={() => setActiveTab(`rbac`)}
        >
          <MaterializeIcon name="security" className="mr1"/>
          Access Control ({rbacCount})
        </button>
      </div>

      <div className="pa3 bg-white">
        {activeTab === `parameters` && (
          <div>
            <Box type="info" className="mb3">
              <p className="ma0">Define parameters that will be passed to this stage&apos;s pipeline.</p>
            </Box>
            <ParametersList
              parameters={stage.parameters}
              onParameterAdded={onParameterAdded}
              onParameterUpdated={onParameterUpdated}
              onParameterRemoved={onParameterRemoved}
            />
          </div>
        )}
        {activeTab === `rbac` && (
          <div>
            <Box type="info" className="mb3">
              <p className="ma0">
                Define who can execute this stage. You can specify users, groups, or service accounts.
              </p>
            </Box>
            <RBACSubjectSelector
              subjects={stage.rbacAccess}
              onSubjectAdded={onSubjectAdded}
              onSubjectRemoved={onSubjectRemoved}
            />
          </div>
        )}
      </div>
    </div>
  );
};

interface PipelineConfigurationProps {
  pipeline: types.PipelineConfig;
  onPipelineUpdate: (config: types.PipelineConfig) => void;
}

const PipelineConfiguration = (props: PipelineConfigurationProps) => {
  const { pipeline, onPipelineUpdate } = props;
  const { projects, loading } = useProjects();
  const projectOptions: types.ProjectSelectOption[] = projects.map((project) => ({
    value: project.id,
    label: project.name,
    description: project.description,
  }));

  const projectSearchFilter = (searchTerm: string, option: types.ProjectSelectOption) => {
    const term = searchTerm.toLowerCase();
    return option.label.toLowerCase().includes(term) || option.description?.toLowerCase().includes(term) || false;
  };

  const renderProjectOption = (option: types.ProjectSelectOption, isSelected: boolean) => {
    return (
      <div className={`pa2 bb b--black-05 pointer hover-bg-washed-gray ${isSelected ? `bg-washed-gray` : ``}`}>
        <div className="flex items-center">
          <div className="flex-1">
            <div className={isSelected ? `fw6` : ``}>{option.label}</div>
            {option.description && (
              <div className={`gray truncate`} style="max-height: 2.5em; line-height: 1.25em; overflow: hidden;">
                {option.description}
              </div>
            )}
          </div>
        </div>
      </div>
    );
  };

  return (
    <div className="flex items-center gap-2 mb2">
      <div className="flex-2">
        <RichSelect.RichSelect
          options={projectOptions}
          value={pipeline.projectId}
          onChange={(value) => {
            const projectId = value as string;
            const project = projects.find((p) => p.id === projectId);
            onPipelineUpdate({
              ...pipeline,
              projectId,
              projectName: project?.name || projectId,
              projectDescription: project?.description || null,
            });
          }}
          placeholder={loading ? `Loading projects...` : `Select project...`}
          searchable={true}
          searchFilter={projectSearchFilter}
          renderOption={renderProjectOption}
          maxResults={10}
          disabled={loading}
        />
      </div>
      <div className="flex-1">
        <input
          type="text"
          className="form-control pa1 br2 w-100"
          value={pipeline.branch}
          onChange={(e) =>
            onPipelineUpdate({
              ...pipeline,
              branch: (e.target as HTMLInputElement).value,
            })
          }
          placeholder="Branch"
        />
      </div>
      <div className="flex-2">
        <input
          type="text"
          className="form-control pa1 br2 w-100"
          value={pipeline.pipelineYamlFile}
          onChange={(e) =>
            onPipelineUpdate({
              ...pipeline,
              pipelineYamlFile: (e.target as HTMLInputElement).value,
            })
          }
          placeholder="Pipeline path (e.g., .semaphore/provision.yml)"
        />
      </div>
    </div>
  );
};

interface StageOverviewProps {
  stage: types.StageConfig;
}

const StageOverview = (props: StageOverviewProps) => {
  const { stage } = props;
  const paramCount = stage.parameters?.length || 0;
  const rbacCount = stage.rbacAccess?.length || 0;

  return (
    <div className="flex gap-1 gray">
      {paramCount > 0 && (
        <span className="flex items-center gap-1">
          <MaterializeIcon name="settings"/>
          {pluralize(paramCount, `parameter`, `parameters`)}
        </span>
      )}

      {paramCount > 0 && rbacCount > 0 && <span>&middot;</span>}
      {rbacCount > 0 && (
        <span className="flex items-center gap-1">
          <MaterializeIcon name="security"/>
          {pluralize(rbacCount, `access rule`, `access rules`)}
        </span>
      )}
      {paramCount === 0 && rbacCount === 0 && <span>No additional configuration</span>}
    </div>
  );
};
