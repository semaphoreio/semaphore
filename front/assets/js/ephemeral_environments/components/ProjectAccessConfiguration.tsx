import { MaterializeIcon, RichSelect } from "js/toolbox";
import * as types from "../types";
import { useState } from "preact/hooks";
import { Badge } from "../utils/elements";
interface ProjectAccessConfigurationProps {
  projects: types.Project[];
  disabled?: boolean;
  onProjectAdded: (projectId: types.ProjectAccess) => void;
  onProjectRemoved: (projectId: types.ProjectAccess) => void;
  projectAccess: types.ProjectAccess[];
}
export const ProjectAccessConfiguration = (
  props: ProjectAccessConfigurationProps
) => {
  const {
    projects,
    projectAccess,
    onProjectAdded,
    onProjectRemoved,
    disabled,
  } = props;
  const [selectedProjectIds, setSelectedProjectIds] = useState<string[]>([]);

  const availableProjects = projects.filter(
    (p) => !projectAccess.some((pa) => pa.projectId === p.id)
  );

  const projectOptions: types.ProjectSelectOption[] = availableProjects.map(
    (project) => ({
      value: project.id,
      label: project.name,
      description: project.description,
    })
  );

  const projectSearchFilter = (
    searchTerm: string,
    option: types.ProjectSelectOption
  ) => {
    const term = searchTerm.toLowerCase();
    return (
      option.label.toLowerCase().includes(term) ||
      option.description?.toLowerCase().includes(term) ||
      false
    );
  };

  const renderProjectOption = (
    option: types.ProjectSelectOption,
    isSelected: boolean
  ) => {
    return (
      <div
        className={`pa2 bb b--black-05 pointer hover-bg-washed-gray ${
          isSelected ? `bg-washed-gray` : ``
        }`}
      >
        <div className="flex items-start">
          <input
            type="checkbox"
            checked={isSelected}
            className="mr2 mt1"
            onClick={(e) => e.stopPropagation()}
            tabIndex={-1}
            aria-hidden="true"
          />
          <div className="flex-1">
            <div className="f6">{option.label}</div>
            {option.description && (
              <div
                className="f7 gray truncate"
                style="max-height: 2.5em; line-height: 1.25em; overflow: hidden;"
              >
                {option.description}
              </div>
            )}
          </div>
        </div>
      </div>
    );
  };

  const getProjectName = (projectId: string): string => {
    return projects.find((p) => p.id === projectId)?.name || projectId;
  };

  const addProjects = () => {
    selectedProjectIds.forEach((projectId) => {
      onProjectAdded({ projectId });
    });
    setSelectedProjectIds([]);
  };

  return (
    <div>
      <div className="mb3 ba b--black-10 br2 pa2 bg-near-white flex flex-column gap-2">
        {projectAccess.length === 0 && (
          <p className="ma0 gray lh-copy tc">No projects have access yet.</p>
        )}
        {projectAccess.length > 0 && (
          <div>
            <div className="flex items-center mb1">
              <MaterializeIcon name="folder" className="mr1 gray"/>
              <span className="fw6 gray">Projects:</span>
            </div>
            <div className="flex flex-wrap gap-1 ml3">
              {projectAccess.map((access) => (
                <Badge
                  key={access.projectId}
                  label={getProjectName(access.projectId)}
                  onDeselect={() => onProjectRemoved(access)}
                  icon="folder"
                />
              ))}
            </div>
          </div>
        )}
      </div>

      <div className="ba b--black-10 br2 pa3 bg-white">
        <div className="flex items-center gap-2">
          <div className="flex-1">
            <RichSelect.RichSelect
              options={projectOptions}
              value={selectedProjectIds}
              onChange={(values) => setSelectedProjectIds(values)}
              placeholder="Select projects to grant access..."
              disabled={disabled}
              searchable={true}
              searchFilter={projectSearchFilter}
              renderOption={renderProjectOption}
              maxResults={10}
              multiple={true}
              renderValue={(selectedOptions, onDeselect) => (
                <div className="flex flex-wrap gap-2">
                  {selectedOptions.map((option) => (
                    <Badge
                      icon="folder"
                      key={option.value}
                      label={option.label}
                      onDeselect={() => onDeselect(option.value)}
                    />
                  ))}
                </div>
              )}
            />
          </div>

          <button
            type="button"
            className="btn btn-secondary flex items-center"
            onClick={addProjects}
            disabled={!selectedProjectIds.length || disabled}
          >
            <MaterializeIcon name="add" className="mr1 f5"/>
            Add
          </button>
        </div>
      </div>
    </div>
  );
};
