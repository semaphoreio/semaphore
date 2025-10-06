import { useState, useRef, useEffect } from "preact/hooks";
import MaterializeIcon from "./materialize_icon";
import { JSX } from "preact/compat";

export interface RichSelectOption {
  value: string;
  label: string;
}

interface RichSelectBase {
  options: RichSelectOption[];
  placeholder?: string;
  disabled?: boolean;
  className?: string;
  id?: string;
  required?: boolean;
  searchable?: boolean;
  searchFilter?: (searchTerm: string, option: RichSelectOption) => boolean;
  renderOption?: (option: RichSelectOption, isSelected: boolean) => JSX.Element;
  renderValue?: (
    selectedOptions: RichSelectOption[],
    onDeselect?: (value: string) => void
  ) => JSX.Element | string;
  onSearchChange?: (searchTerm: string) => void;
  loading?: boolean;
  disableLocalFilter?: boolean;
  maxResults?: number; // Limit number of options displayed (search uses full set)
}

interface SingleSelectProps extends RichSelectBase {
  multiple?: false;
  value?: string;
  onChange?: (value: string) => void;
}

interface MultiSelectProps extends RichSelectBase {
  multiple: true;
  value?: string[];
  onChange?: (values: string[]) => void;
}

export type RichSelectProps = SingleSelectProps | MultiSelectProps;

export const RichSelect = (props: RichSelectProps) => {
  const {
    options,
    value,
    onChange,
    placeholder = props.multiple ? `Select options` : `Select an option`,
    multiple = false,
    disabled = false,
    className = ``,
    id,
    required = false,
    searchable = false,
    searchFilter,
    renderOption,
    renderValue,
    onSearchChange,
    loading = false,
    disableLocalFilter = false,
    maxResults,
  } = props;

  const [isOpen, setIsOpen] = useState(false);
  const [searchTerm, setSearchTerm] = useState(``);
  const containerRef = useRef<HTMLDivElement>(null);
  const searchInputRef = useRef<HTMLInputElement>(null);

  const selectedValues = multiple
    ? (value as string[]) || []
    : value
      ? [value as string]
      : [];

  const defaultSearchFilter = (term: string, option: RichSelectOption) => {
    return option.label.toLowerCase().includes(term.toLowerCase());
  };

  const filteredOptions =
    searchTerm && !disableLocalFilter
      ? options.filter((option) =>
        (searchFilter || defaultSearchFilter)(searchTerm, option)
      )
      : options;

  const displayOptions =
    maxResults && !searchTerm
      ? filteredOptions.slice(0, maxResults)
      : filteredOptions;

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (
        containerRef.current &&
        !containerRef.current.contains(event.target as Node)
      ) {
        setIsOpen(false);
        setSearchTerm(``);
      }
    };

    document.addEventListener(`mousedown`, handleClickOutside);
    return () => {
      document.removeEventListener(`mousedown`, handleClickOutside);
    };
  }, []);

  useEffect(() => {
    if (isOpen && searchable && searchInputRef.current) {
      searchInputRef.current.focus();
    }
  }, [isOpen, searchable]);

  const handleToggle = () => {
    if (!disabled) {
      setIsOpen(!isOpen);
      if (!isOpen) {
        setSearchTerm(``);
      }
    }
  };

  const handleSelect = (optionValue: string) => {
    if (!onChange) return;

    if (multiple) {
      const currentValues = selectedValues;
      const newValues = currentValues.includes(optionValue)
        ? currentValues.filter((v) => v !== optionValue)
        : [...currentValues, optionValue];

      (onChange as (values: string[]) => void)(newValues);
    } else {
      (onChange as (value: string) => void)(optionValue);
      setIsOpen(false);
    }
  };

  const handleDeselect = (optionValue: string) => {
    if (!onChange) return;

    if (multiple) {
      const newValues = selectedValues.filter((v) => v !== optionValue);
      (onChange as (values: string[]) => void)(newValues);
    }
  };

  const getDisplayContent = () => {
    const selectedOptions = options.filter((opt) =>
      selectedValues.includes(opt.value)
    );

    if (selectedOptions.length === 0) return placeholder;

    if (renderValue) {
      return renderValue(
        selectedOptions,
        multiple ? handleDeselect : undefined
      );
    }

    if (!multiple) {
      return selectedOptions[0]?.label || placeholder;
    }

    if (selectedOptions.length === 1) {
      return selectedOptions[0]?.label || placeholder;
    }

    return `${selectedOptions.length} selected`;
  };

  const isSelected = (optionValue: string) =>
    selectedValues.includes(optionValue);

  return (
    <div className="relative" ref={containerRef}>
      <div
        className={`form-control-border pa1 br2 bg-white pointer flex items-center justify-between ${className} ${
          disabled ? `o-50` : ``
        }`}
        onClick={handleToggle}
        tabIndex={disabled ? -1 : 0}
        role="combobox"
        aria-expanded={isOpen}
        aria-haspopup="listbox"
        aria-required={required}
        aria-multiselectable={multiple}
        id={id}
      >
        <span className={selectedValues.length > 0 ? `` : `gray`}>
          {getDisplayContent()}
        </span>
        <MaterializeIcon
          name={isOpen ? `keyboard_arrow_up` : `keyboard_arrow_down`}
          className={`ml2 ${className}`}
        />
      </div>

      {isOpen && (
        <div
          className="absolute z-999 w-100 mt1 ba b--black-10 br2 bg-white shadow-3"
          role="listbox"
          aria-multiselectable={multiple}
        >
          {searchable && (
            <div className="pa2 bb b--black-10">
              <input
                ref={searchInputRef}
                type="text"
                className="form-control w-100 pa1"
                placeholder="Search..."
                value={searchTerm}
                onChange={(e) => {
                  const newSearchTerm = (e.target as HTMLInputElement).value;
                  setSearchTerm(newSearchTerm);
                  if (onSearchChange) {
                    onSearchChange(newSearchTerm);
                  }
                }}
                onClick={(e) => e.stopPropagation()}
              />
            </div>
          )}

          <div style="max-height: 250px; overflow-y: auto;">
            {loading ? (
              <div className="pa3 gray tc flex items-center justify-center">
                <div className="mr2">Loading...</div>
              </div>
            ) : filteredOptions.length === 0 ? (
              <div className="pa3 gray tc">
                {searchTerm ? `No matching options` : `No options available`}
              </div>
            ) : (
              displayOptions.map((option, index) => {
                const selected = isSelected(option.value);

                if (renderOption) {
                  return (
                    <div
                      key={option.value}
                      className="pointer"
                      onClick={() => handleSelect(option.value)}
                      role="option"
                      aria-selected={selected}
                    >
                      {renderOption(option, selected)}
                    </div>
                  );
                }

                return (
                  <div
                    key={option.value}
                    className={`pa2 bb b--black-05 pointer hover-bg-washed-gray ${
                      selected ? `bg-washed-gray` : ``
                    } ${index == 0 ? `br2 br--top` : ``} ${
                      index === filteredOptions.length - 1
                        ? `br2 br--bottom`
                        : ``
                    }`}
                    onClick={() => handleSelect(option.value)}
                    role="option"
                    aria-selected={selected}
                  >
                    <div className="flex items-center">
                      {!multiple && (
                        <MaterializeIcon
                          name="check"
                          className={`mr2 ${selected ? `` : `o-0`}`}
                        />
                      )}
                      {multiple && (
                        <input
                          type="checkbox"
                          checked={selected}
                          className="mr2"
                          onClick={(e) => e.stopPropagation()}
                          tabIndex={-1}
                          aria-hidden="true"
                        />
                      )}
                      <span>{option.label}</span>
                    </div>
                  </div>
                );
              })
            )}
          </div>
        </div>
      )}
    </div>
  );
};
