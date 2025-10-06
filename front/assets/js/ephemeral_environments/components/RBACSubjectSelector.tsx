import { useState } from "preact/hooks";
import { MaterializeIcon, RichSelect } from "js/toolbox";
import * as types from "../types";
import { useRBACSearch } from "../hooks/useRBACSearch";
import {
  getSubjectIcon,
  getSubjectTypeLabel,
  groupSubjectsByType,
  SUBJECT_TYPE_OPTIONS,
} from "../utils/rbacHelpers";
import { Badge } from "../utils/elements";

interface RBACSubjectSelectorProps {
  subjects: types.RBACSubject[];
  onSubjectAdded: (subject: types.RBACSubject) => void;
  onSubjectRemoved: (subject: types.RBACSubject) => void;
  disabled?: boolean;
}

export const RBACSubjectSelector = (props: RBACSubjectSelectorProps) => {
  const { subjects, onSubjectAdded, onSubjectRemoved, disabled } = props;
  const {
    members,
    loading,
    setSearchTerm,
    subjectType,
    setSubjectType,
    handleInteraction,
  } = useRBACSearch();
  const [selectedIds, setSelectedIds] = useState<string[]>([]);

  const getSubjectOptions = (): RichSelect.RichSelectOption[] => {
    return members
      .filter(
        (m) => !subjects.some((s) => s.type === subjectType && s.id === m.id)
      )
      .map((m) => ({ value: m.id, label: m.name }));
  };

  const getSubjectName = (id: string): string => {
    return members.find((m) => m.id === id)?.name || id;
  };

  const addSubject = () => {
    selectedIds.forEach((selectedId) => {
      const newSubject: types.RBACSubject = {
        type: subjectType,
        id: selectedId,
        name: getSubjectName(selectedId),
      };
      onSubjectAdded(newSubject);
    });
    setSelectedIds([]);
  };

  const handleTypeChange = (newType: types.RBACSubjectType) => {
    setSubjectType(newType);
    setSelectedIds([]);
  };

  return (
    <div>
      <SelectedSubjectsDisplay
        subjects={subjects}
        onSubjectRemoved={onSubjectRemoved}
        disabled={disabled}
      />

      {!disabled && (
        <SubjectSearchInput
          subjectType={subjectType}
          onTypeChange={handleTypeChange}
          searchOptions={getSubjectOptions()}
          selectedIds={selectedIds}
          onSelectedIdsChange={setSelectedIds}
          onSearchChange={setSearchTerm}
          onInteraction={handleInteraction}
          onAdd={addSubject}
          loading={loading}
          disabled={disabled}
        />
      )}
    </div>
  );
};

interface SelectedSubjectsDisplayProps {
  subjects: types.RBACSubject[];
  onSubjectRemoved: (subject: types.RBACSubject) => void;
  disabled?: boolean;
}

const SelectedSubjectsDisplay = (props: SelectedSubjectsDisplayProps) => {
  const { subjects, onSubjectRemoved, disabled } = props;
  const groupedSubjects = groupSubjectsByType(subjects);

  return (
    <div className="mb3 ba b--black-10 br2 pa2 bg-near-white mb2 flex flex-column gap-1">
      {subjects.length === 0 && (
        <p className="ma0 gray lh-copy tc">No subjects added yet.</p>
      )}
      {Object.entries(groupedSubjects).map(([type, items]) => {
        if (items.length === 0) return null;
        const rbacType = type as types.RBACSubjectType;

        return (
          <div key={type} className="mb2">
            <div className="flex items-center mb1">
              <MaterializeIcon
                name={getSubjectIcon(rbacType)}
                className="mr1 gray"
              />
              <span className="fw6 gray">
                {getSubjectTypeLabel(rbacType)}s:
              </span>
            </div>
            <div className="flex flex-wrap gap-1 ml3">
              {items.map((subject) => (
                <Badge
                  icon={getSubjectIcon(rbacType)}
                  key={subject.id}
                  label={subject.name}
                  onDeselect={() => onSubjectRemoved(subject)}
                />
              ))}
            </div>
          </div>
        );
      })}
    </div>
  );
};

interface SubjectSearchInputProps {
  subjectType: types.RBACSubjectType;
  onTypeChange: (type: types.RBACSubjectType) => void;
  searchOptions: RichSelect.RichSelectOption[];
  selectedIds: string[];
  onSelectedIdsChange: (ids: string[]) => void;
  onSearchChange: (search: string) => void;
  onInteraction: () => void;
  onAdd: () => void;
  loading: boolean;
  disabled?: boolean;
}

const SubjectSearchInput = (props: SubjectSearchInputProps) => {
  const {
    subjectType,
    onTypeChange,
    searchOptions,
    selectedIds,
    onSelectedIdsChange,
    onSearchChange,
    onInteraction,
    onAdd,
    loading,
    disabled,
  } = props;

  return (
    <div className="ba b--black-10 br2 pa3 bg-white">
      <div className="flex items-center gap-2">
        <select
          className="form-control pa1"
          value={subjectType}
          onChange={(e) =>
            onTypeChange(
              (e.target as HTMLSelectElement).value as types.RBACSubjectType
            )
          }
        >
          {SUBJECT_TYPE_OPTIONS.map((option) => (
            <option key={option.value} value={option.value}>
              {option.label}
            </option>
          ))}
        </select>

        <div className="flex-1" onClick={onInteraction}>
          <RichSelect.RichSelect
            options={searchOptions}
            value={selectedIds}
            onChange={(values) => onSelectedIdsChange(values)}
            onSearchChange={(search) => onSearchChange(search)}
            placeholder={
              loading
                ? `Loading ${getSubjectTypeLabel(
                  subjectType
                ).toLowerCase()}s...`
                : `Search ${getSubjectTypeLabel(subjectType)}...`
            }
            disabled={disabled}
            loading={loading}
            disableLocalFilter={true}
            searchable={true}
            multiple={true}
            renderValue={(selectedOptions, onDeselect) => (
              <div className="flex flex-wrap gap-1">
                {selectedOptions.map((option) => (
                  <Badge
                    icon={getSubjectIcon(subjectType)}
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
          className="btn btn-secondary flex items-center gap-1"
          onClick={onAdd}
          disabled={!selectedIds.length}
        >
          <MaterializeIcon name="add"/>
          Add
        </button>
      </div>
    </div>
  );
};
