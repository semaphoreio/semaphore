import { Fragment } from "preact";
import * as toolbox from "js/toolbox";
import { useContext, useState, useMemo, useEffect } from "preact/hooks";
import { WorkflowSetup } from "../../stores";
import { useNavigate } from "react-router-dom";
import type { Templates } from "../../types";
import { FilterButton, PreviewPanel } from "../../components";
// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
import { Notice } from "js/notice";

interface TemplateOptionProps {
  template: Templates.Template;
  onClick?: () => void;
  isSelected?: boolean;
}

const TemplateOption = ({ template, onClick, isSelected }: TemplateOptionProps) => (
  <div
    className={`flex items-center pa2 pointer ${isSelected ? `bg-washed-green` : `hover-bg-washed-green`}`}
    onClick={onClick}
  >
    <toolbox.Asset path={`images/${template.icon}`} style={{ width: `28px` }}/>
    <div className="flex-auto pl3">
      <h3 className="f4 mb0">{template.title}</h3>
      <p className="mb0 gray">{template.short_description}</p>
    </div>
  </div>
);

interface TemplateGroupProps {
  group: Templates.Group;
  templates: Templates.Template[];
  onTemplateSelect: (template: Templates.Template) => void;
  selectedTemplate?: Templates.Template;
}

const TemplateGroup = ({ group, templates, onTemplateSelect, selectedTemplate }: TemplateGroupProps) => {
  if (templates.length === 0) return null;

  return (
    <>
      <div className="relative f7 gray pb2 mt2 mb3 bb b--black-10">
        <span className="absolute bg-white pr2">{group.label}</span>
      </div>
      {templates.map(template => (
        <TemplateOption
          key={template.template_path}
          template={template}
          onClick={() => onTemplateSelect(template)}
          isSelected={selectedTemplate?.template_path === template.template_path}
        />
      ))}
    </>
  );
};

export const StarterWorkflowTemplate = () => {
  const { state } = useContext(WorkflowSetup.Config.Context);
  const { state: { selectedAgentType, yamlPath } } = WorkflowSetup.Environment.useEnvironmentStore();
  const navigate = useNavigate();
  const templates = state.templates || [];
  const groups = state.templatesSetup?.groups || [];
  const [activeFilters, setActiveFilters] = useState<Record<string, string[]>>({});
  const [searchQuery, setSearchQuery] = useState(``);
  const [selectedTemplate, setSelectedTemplate] = useState<Templates.Template>(state.templates.find(t => t.title.includes(`Fan-In`)) || state.templates[0]);
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    if (!selectedAgentType) {
      navigate(`/environment`);
    }
  }, [selectedAgentType, navigate]);

  // Memoize filtered templates
  const filteredTemplates = useMemo(() => {
    return templates.filter(template => {
      // First apply search filter
      if (searchQuery) {
        const normalizedQuery = searchQuery.toLowerCase();
        const normalizedTitle = template.title.toLowerCase();
        if (!normalizedTitle.includes(normalizedQuery)) {
          return false;
        }
      }

      // Then apply other filters
      return Object.entries(activeFilters).every(([field, values]) => {
        if (!values || values.length === 0) return true;

        const templateValue = template[field as keyof Templates.Template];
        if (!templateValue) return false;

        // Convert filter values to lowercase
        const lowerValues = values.map(v => v.toLowerCase());

        // Handle array fields
        if (Array.isArray(templateValue)) {
          // Convert array values to lowercase for comparison
          const lowerTemplateValues = templateValue.map(v => v.toLowerCase());
          return lowerValues.some(value => lowerTemplateValues.includes(value));
        }

        // For single values, convert to lowercase and check
        return lowerValues.includes((templateValue as string).toLowerCase());
      });
    });
  }, [templates, searchQuery, activeFilters]);

  // Memoize grouped templates
  const { templatesByGroup, allGroups } = useMemo(() => {
    // Create a set of all group names for quick lookup
    const configuredGroupNames = new Set(groups.map(g => g.name));

    // Group templates by their group
    const templatesByGroup = groups.reduce<Record<string, Templates.Template[]>>((acc, group) => {
      acc[group.name] = filteredTemplates.filter(t => t.group === group.name);
      return acc;
    }, {});

    // Find templates that don't belong to any configured group
    const otherTemplates = filteredTemplates.filter(t => !t.group || !configuredGroupNames.has(t.group));

    // Create an "Other" group if there are ungrouped templates
    const allGroups = [
      ...groups,
      ...(otherTemplates.length > 0 ? [{ name: `other`, label: `Other` }] : [])
    ];

    // Add other templates to templatesByGroup
    if (otherTemplates.length > 0) {
      templatesByGroup[`other`] = otherTemplates;
    }

    return { templatesByGroup, allGroups };
  }, [filteredTemplates, groups]);

  const handleFiltersChange = (filters: Record<string, string[]>) => {
    setActiveFilters(filters);
  };

  const handleSearchChange = (event: Event) => {
    const target = event.target as HTMLInputElement;
    setSearchQuery(target.value);
  };

  const handleTemplateSelect = (template: Templates.Template) => {
    setSelectedTemplate(template);
  };

  const handleSubmit = async () => {
    setIsLoading(true);

    try {
      const response = await fetch(state.commitStarterTemplatesUrl, {
        method: `POST`,
        headers: {
          'Content-Type': `application/json`,
          'X-CSRF-Token': state.csrfToken
        },
        body: JSON.stringify({
          commit_path: yamlPath,
          template_title: selectedTemplate.title,
          template_path: selectedTemplate.template_path,
          machine_type: selectedAgentType.type,
          os_images: selectedAgentType.available_os_images,
        })
      });

      if (!response.ok) {
        throw new Error(`Failed to commit starter template`);
      }

      const data = await response.json();
      if (data.error) {
        Notice.error(`Error committing starter template: ${data.error as string}`);
        return;
      }

      // Start checking for workflow
      await checkWorkflow(data.branch as string, data.commit_sha as string, data.job_id as string);
    } catch (error) {
      Notice.error(`Error committing starter template: ${error as string}`);
    } finally {
      setIsLoading(false);
    }
  };

  const checkWorkflow = async (branch: string, commitSha: string, jobId?: string) => {
    setIsLoading(true);
    let params = {};

    if(jobId) {
      params = {
        branch,
        commit_sha: commitSha,
        job_id: jobId,
      };
    } else {
      params = {
        branch,
        commit_sha: commitSha,
      };
    }

    const query = new URLSearchParams(params).toString();

    const url = state.checkWorkflowUrl + `?${query}`;

    try {
      const response = await fetch(url);
      const contentType = response.headers.get(`content-type`);

      if (!contentType?.includes(`application/json`)) {
        throw new Error(`Invalid response type`);
      }

      const data = await response.json();

      if(data.artifact_url !== null) {
        try {
          const shaResponse = await fetch(data.artifact_url as string);
          const sha = await shaResponse.text();
          setTimeout(() => void checkWorkflow(branch, sha.trim()), 1000);
          return;
        } catch (error) {
          Notice.error(`Error starting the workflow: ${error as string}`);
        }
      }

      if (data.workflow_url == null) {
        // If workflow is not ready, check again in 1 second
        setTimeout(() => void checkWorkflow(branch, commitSha, jobId), 1000);
      } else {
        // Set workflow tip cookie if it exists
        if (selectedTemplate.workflow_tip && selectedTemplate.workflow_tip !== ``) {
          document.cookie = `${state.project.name}-workflow-tip=${selectedTemplate.workflow_tip}; path=/;`;
        }
        // Workflow is ready, navigate to the workflow URL
        window.location.href = data.workflow_url;
      }
    } catch (error) {
      Notice.error(`Error starting the workflow: ${error as string}`);
      setIsLoading(false);
    }
  };

  return (
    <Fragment>
      <div className="pt3 pb3">
        <div className="relative mw9 center">
          <div className="flex-l">
            {/* <!-- LEFT SIDE --> */}
            <div className="w-25 bg-white shadow-1 br3 mr2" style="position: relative; overflow: hidden;">
              <div className="f6 mb3 mb0-m pa3 br-m b--black-10 bb bb-0-m overflow-auto" style="position: absolute; top: 0; bottom: 0; left: 0; right: 0;">
                <div className="pb3 mb3 bb b--black-10">
                  <div className="flex justify-between items-center">
                    <div>
                      <h2 className="f3 fw6 mb2">Build Environment</h2>
                      <p className="black-70 mv0">Choose your runtime settings and configuration options.</p>
                    </div>
                  </div>
                </div>
                <div className="mb3 flex items-center">
                  <input
                    type="search"
                    className="form-control w-100"
                    placeholder="Search..."
                    value={searchQuery}
                    onInput={handleSearchChange}
                  />
                  <FilterButton onFiltersChange={handleFiltersChange}/>
                </div>

                {allGroups.map(group => (
                  <TemplateGroup
                    key={group.name}
                    group={group}
                    templates={templatesByGroup[group.name] || []}
                    onTemplateSelect={handleTemplateSelect}
                    selectedTemplate={selectedTemplate}
                  />
                ))}
              </div>
            </div>
            {/* <!-- RIGHT SIDE --> */}
            <div className="w-75 bg-white shadow-1 pa4 br3 ml2">
              <PreviewPanel template={selectedTemplate}/>
            </div>
          </div>
          <div className="tr">
            <button
              className="btn btn-primary mt3"
              onClick={() => void handleSubmit() }
              disabled={!selectedTemplate || isLoading}
            >
              {isLoading ? (
                <span className="flex items-center">
                  <toolbox.Asset path="images/spinner-2.svg" width="20" height="20"/>
                  <span className="ml2">Starting...</span>
                </span>
              ) : (
                `Looks good, start →`
              )}
            </button>
          </div>
        </div>
      </div>
    </Fragment>
  );
};
