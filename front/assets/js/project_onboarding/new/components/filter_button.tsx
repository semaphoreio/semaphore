
import { useContext, useState, useEffect } from "preact/hooks";
import Tippy from "@tippyjs/react";
import { WorkflowSetup } from "../stores";

interface FilterButtonProps {
  className?: string;
  onFiltersChange: (filters: Record<string, string[]>) => void;
}

interface FilterState {
  [key: string]: string[];
}

export const FilterButton = ({ className = ``, onFiltersChange }: FilterButtonProps) => {
  const { state } = useContext(WorkflowSetup.Config.Context);
  const { state: envState } = WorkflowSetup.Environment.useEnvironmentStore();
  const filters = state.templatesSetup?.filters;

  const initialEnvironment = (() => {
    const agentType = envState.selectedAgentType?.type;
    if (!agentType) return [];

    if (agentType.startsWith(`s1-`)) return [`docker`];
    if (agentType.startsWith(`a`)) return [`macos`];
    return [`linux`];
  })();

  // Initialize with searchFields instead of labels
  const [selectedFilters, setSelectedFilters] = useState<FilterState>({
    environment: initialEnvironment
  });

  useEffect(() => {
    onFiltersChange(selectedFilters);
  }, []);

  if (!filters) return null;

  const handleFilterChange = (filterKey: string, value: string) => {
    setSelectedFilters(prev => {
      const newFilters = { ...prev };
      const filterType = filters.find(f => f.label === filterKey);

      if (!filterType?.searchField) return prev;

      const searchField = filterType.searchField;

      if (filterType.type === `radio`) {
        // For radio buttons, replace the current value
        newFilters[searchField] = [value];
      } else {
        // For multiple selection, toggle the value
        const currentValues = prev[searchField] || [];
        if (currentValues.includes(value)) {
          newFilters[searchField] = currentValues.filter(v => v !== value);
        } else {
          newFilters[searchField] = [...currentValues, value];
        }
      }

      onFiltersChange(newFilters);
      return newFilters;
    });
  };

  const content = (
    <div className="pa3">
      {filters.map(filter => (
        <div key={filter.label}>
          <h3 className="f5 mb2 pb2 bb b--black-10">{filter.label}</h3>
          <div className="flex flex-column">
            {filter.options.map(option => {
              const isSelected = (selectedFilters[filter.searchField] || []).includes(option.value);
              return (
                <label key={option.value} className="mb2 flex items-center">
                  <input
                    type={filter.type === `radio` ? `radio` : `checkbox`}
                    name={filter.searchField}
                    value={option.value}
                    checked={isSelected}
                    onChange={() => handleFilterChange(filter.label, option.value)}
                    className="mr2"
                  />
                  {option.label}
                </label>
              );
            })}
          </div>
        </div>
      ))}
    </div>
  );

  return (
    <Tippy
      content={content}
      interactive={true}
      placement="bottom"
      trigger="click"
      arrow={true}
      theme="dropdown"
      maxWidth={350}
    >
      <button className={`btn btn-secondary ml2 flex items-center ph2 ${className}`}>
        <span className="material-symbols-outlined mr1">{Object.keys(selectedFilters).some(key => selectedFilters[key].length > 0) ? `filter_list` : `filter_list_off`}</span>
        <span className="f6">Filter</span>
      </button>
    </Tippy>
  );
};
