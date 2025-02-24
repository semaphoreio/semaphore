import { Component } from 'preact';
import { MutableRef, useEffect, useMemo, useRef, useState } from "preact/hooks";
import { AutocompletePropGetters, AutocompleteScopeApi, BaseItem, createAutocomplete } from "@algolia/autocomplete-core";

// Create a global variable 'React' that points to Preact (because autocomplete-core expects it)
// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
window.React = { createElement: h, Component };


// export to a json file
export const allowedParams = [
  {
    label: `@git.branch:`,
    example: `Example: @git.branch:"master" or @git.branch:"feature-*`,
    description: `Git branch.`,
    add_quotes: false,
  },
  {
    label: `@git.commit_sha:`,
    example: `Example: @git.commit_sha:"d530a2a"`,
    description: `Commit SHA.`,
    add_quotes: false,
  },
  {
    label: `@test.name:`,
    example: `Example: Lorem ipsum dolor sit amet`,
    description: `Name of the test.`,
    add_quotes: true,
  },
  {
    label: `@test.group:`,
    example: `Example: Consectetur adipiscing elit`,
    description: `Group that the test is assigned to.`,
    add_quotes: false
  },
  {
    label: `@test.file:`,
    example: `Example: Nam a turpis in augue`,
    description: `Test file.`,
    add_quotes: false
  },
  {
    label: `@metric.age:`,
    example: `Example: @metric.age:>30`,
    description: `Time passed in days since first flaked.`,
    add_quotes: false
  },
  {
    label: `@test.class.name:`,
    example: `Example: nulla vel lobortis blandit`,
    description: `Name of the test class.`,
    add_quotes: false
  },
  {
    label: `@test.suite:`,
    example: `Example: libero mollis bibendum`,
    description: `Name of the test suite.`,
    add_quotes: false
  },
  {
    label: `@test.runner:`,
    example: `Example: Donec vitae lobortis sapien`,
    description: `Name of the test runner.`,
    add_quotes: false
  },
  {
    label: `@metric.pass_rate:`,
    example: `Example: Maecenas at lectus `,
    description: `Pass rate of a test.`,
    add_quotes: false
  },
  {
    label: `@metric.disruptions:`,
    example: `Example: tempus maximus`,
    description: `Number of disruptions of a test.`,
    add_quotes: false
  },
  {
    label: `@label:`,
    example: `Example: Vivamus fringilla nisl`,
    description: `Assigned label to the test`,
    add_quotes: true
  },
  {
    label: `@is.resolved:`,
    example: `Example: @is.resolved:false`,
    description: `Filter by resolved or unresolved tests.`,
    add_quotes: false
  },
  {
    label: `@is.scheduled:`,
    example: `Example: @is.scheduled:true`,
    description: `Filter by scheduled or unscheduled tests.`,
    add_quotes: false
  },
  {
    label: `@date.from:`,
    example: `Example: @date.from:2023-09-21 or @date.from:now-30d`,
    description: `Starting date range.`,
    add_quotes: false
  },
  {
    label: `@date.to:`,
    example: `Example: @date.to:2023-09-21 or @date.to:now-30d`,
    description: `End of the filtered date range.`,
    add_quotes: false
  },
];

const Form = (autocomplete: AutocompleteScopeApi<BaseItem> & AutocompletePropGetters<BaseItem, Event, MouseEvent, KeyboardEvent>, inputRef: MutableRef<HTMLInputElement>, p: ComposeBoxProps) => {

  useEffect(() => {
    autocomplete.setQuery(p.query);
  }, [p.query]);

  const handleInput = (event: Event) => {
    const target = event.target as HTMLInputElement;
    p.onQueryChange(target.value);
  };

  const handleKeyPress = (event: KeyboardEvent) => {
    if (event.which == 13) {
      event.preventDefault();
      event.stopPropagation();
      p.onSubmit();
    }
  };

  const inputProps = autocomplete.getInputProps({
    inputElement: inputRef.current,
    autoFocus: true,
    spellCheck: false,
  });

  // Extract only the valid HTML input element properties
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  const { autoFocus, spellCheck, ...restInputProps } = inputProps;

  return <form
    {...autocomplete.getFormProps({
      inputElement: inputRef.current,
    })}>

    <input type="text"
      className="box-textbox form-control w-100 br0"
      ref={inputRef}
      onInput={handleInput}
      onKeyPress={handleKeyPress}
      {...restInputProps}
    />
  </form>;
};

const Panel = (autocomplete: AutocompleteScopeApi<BaseItem> & AutocompletePropGetters<BaseItem, Event, MouseEvent, KeyboardEvent>, state: {
  completion: null;
  isOpen: boolean;
  collections: any[];
  query: string;
  context: unknown;
  activeItemId: null;
  status: string;
}) => {
  return <div style={{ position: `absolute`, top: `100%`, left: 0, right: 0, zIndex: 99 }}
    {...autocomplete.getPanelProps({})}
    className="autocomplete-panel bg-white  shadow-1">
    {state.status === `stalled` && !state.isOpen && (
      <AutocompleteSpinner/>
    )}
    {state.isOpen && state.collections.map(({ source, items }) => {
      return (
        <div
          key={`source-${source.sourceId as string}`}
          className={[
            `autocomplete-source`,
            state.status === `stalled` && `autocomplete-source-stalled`,]
            .filter(Boolean)
            .join(` `)}
        >
          {items.length > 0 && (
            <ul className="autocomplete-items pl0" {...autocomplete.getListProps()}>
              {items.map((item: any) => {
                const itemProps = autocomplete.getItemProps({
                  item,
                  source,
                });
                return (
                  <li key={item.label} {...itemProps}
                    style={{ listStyleType: `none` }}>

                    <div
                      className={[`autocomplete-item`, itemProps[`aria-selected`] && `autocomplete-item-selected`]
                        .filter(Boolean).join(` `)}>
                      <FilterItem hit={item} isSelected={itemProps[`aria-selected`]}/>
                    </div>
                  </li>
                );
              })}
            </ul>
          )}
        </div>
      );
    })}
  </div>;
};

export interface ComposeBoxProps {
  query: string;
  onQueryChange: (newQuery: string) => void;
  onSubmit: () => void;
}

export const ComposeBox = (props: ComposeBoxProps) => {

  const getSources = (query: string) => {
    const cursorPosition = inputRef.current?.selectionEnd || 0;
    const activeToken = getActiveToken(query, cursorPosition);

    const onSelect = (item: any, setQuery: (newQuery: string) => void) => {
      const [index] = activeToken.range;
      const r = item.label as string;
      const replacement = item.add_quotes ? `${r}"` : r;
      const newQuery = replaceAt(query, `${replacement}`, index, activeToken.word.length);
      setQuery(newQuery);

      if (inputRef.current) {
        inputRef.current.selectionEnd = index + replacement.length;
      }
    };

    return [
      {
        onSelect({ item, setQuery }: { item: any, setQuery: (newQuery: string) => void, }) {
          onSelect(item, setQuery);
        },

        sourceId: `filters`,
        getItems() {
          return activeToken?.word ? allowedParams.filter((item) =>
            item.label.toLowerCase().includes(activeToken.word.slice(1).toLowerCase())
          ) : allowedParams;
        }
      }
    ];
  };

  const { autocomplete, state } = useAutocomplete({
    ...props,
    id: `autocomplete-search-filter`,
    defaultActiveItemId: 0,
    getSources({ query }: { query: string, }) {
      return getSources(query);
    }
  });

  const inputRef = useRef<HTMLInputElement>(null);

  return (
    <div {...autocomplete.getRootProps({})} className="w-100">
      <div className="box">
        <div className="box-body">
          <div className="box-compose" style={{ position: `relative` }}>
            {Form(autocomplete, inputRef, props)}
            {Panel(autocomplete, state)}
          </div>
        </div>
      </div>
    </div>
  );

};

export const useAutocomplete = (props: any) => {
  const [state, setState] = useState({
    collections: [],
    completion: null,
    context: {},
    isOpen: false,
    query: ``,
    activeItemId: null,
    status: `idle`,
  });

  const autocomplete = useMemo(
    () =>
    // eslint-disable-next-line @typescript-eslint/no-unsafe-argument
      createAutocomplete({
        ...props,
        onStateChange(params) {
          props.onStageChange?.(params);
          setState(params.state);
        }
      }),
    []
  );

  return { autocomplete, state };
};


const FilterItem = ({ hit, isSelected }: { hit: any, isSelected: boolean, }) => {
  const baseClassName = `justify-between pointer pv1 ph2 bb b--black-075`;
  const labelClassName = isSelected ? `bg-dark-gray white` : `bg-white hover-bg-washed-gray`;
  const valueClassName = isSelected ? `f6 light-gray` : `f6 gray`;

  const finalLabelClassName = `${baseClassName} ${labelClassName} flex`;
  const finalValueClassName = `${valueClassName} mb0 truncate measure tl`;

  return (
    <div className="item-body">
      <div className={finalLabelClassName}>
        <div className="flex items-start">
          <span className="mr2 material-symbols-outlined b f3">search</span>
          <span className="b">{hit.label}</span>
        </div>
        <div className="flex justify-end">
          <span className={finalValueClassName}>{hit.description}</span>
        </div>
      </div>
    </div>
  );
};

interface Token {
  word: string;
  range: [number, number];
}

const getActiveToken = (input: string, cursorPosition: number): Token | undefined => {
  const tokenizedQuery = input.split(/[\s\n]/).reduce((acc: Token[], word, index) => {
    const previous = acc[index - 1];
    const start = (index === 0 ? index : previous.range[1] + 1);
    const end = start + word.length;

    return acc.concat([{ word, range: [start, end] }]);
  }, []);

  if (cursorPosition === undefined) {
    return undefined;
  }

  return tokenizedQuery.find(
    ({ range }) => range[0] <= cursorPosition && range[1] >= cursorPosition
  );
};

const replaceAt = (str: string, replacement: string, index: number, length = 0) => {
  const prefix = str.substring(0, index);
  const suffix = str.substring(index + length);

  return prefix + replacement + suffix;
};

const AutocompleteSpinner = () => {
  return (<div className="autocomplete-loading">
    <svg
      className="autocomplete-loading-icon"
      viewBox="0 0 100 100"
      fill="currentColor"
    >
      <circle
        cx="50"
        cy="50"
        r="35"
        fill="none"
        stroke="currentColor"
        strokeDasharray="164.93361431346415 56.97787143782138"
        strokeWidth="6"
      >
        <animateTransform
          attributeName="transform"
          dur="1s"
          keyTimes="0;0.40;0.65;1"
          repeatCount="indefinite"
          type="rotate"
          values="0 50 50;90 50 50;180 50 50;360 50 50"
        ></animateTransform>
      </circle>
    </svg>
  </div>);
};
