import { useContext, useEffect, useLayoutEffect, useMemo, useRef, useState } from "preact/hooks";
import { FilterStore, NavigationStore } from "../stores";
import Popper, { createPopper } from "@popperjs/core";
import { State } from "../util/stateful";
import _ from "lodash";
import Icon from "../util/icon";

export const Filters = () => {
  const filter = useContext(FilterStore.Context);
  const navigation = useContext(NavigationStore.Context);

  const onCollapseChanged = () => {
    if (filter.state.toggleAll) {
      navigation.dispatch({ type: `SET_ACTIVE_SUITE`, suiteId: `` });
    }
    filter.dispatch({ type: `SET_TOGGLE`, toggle: !filter.state.toggleAll });
  };

  return (
    <div className="pv2 bb b--lighter-gray gray flex items-center justify-between mb3">
      <div className="flex flex-auto items-center">
        <button className="btn btn-secondary btn-tiny mr3" onClick={() => onCollapseChanged()}>
          {filter.state.toggleAll ? `Collapse` : `Expand`} All
        </button>
        <div className="flex items-center flex-auto">
          <Icon path="images/icn-search-15.svg" class="db ml1 mr2" alt="magnifying glass"/>
          <QueryFilter/>
        </div>
      </div>
      <div className="flex items-center">
        <div className="flex items-center">
          <Icon path="images/icn-sort-15.svg" class="db ml1 mr2" alt="filter"/>
          <SortFilter/>
        </div>
        <div className="flex items-center ml3">
          <Icon path="images/icn-eye-15.svg" class="db ml1 mr2" alt="eye"/>
          <FilterOptions/>
        </div>
      </div>
    </div>
  );
};

const FilterOptions = () => {
  const anchorEl = useRef(null);
  const tooltipEl = useRef(null);
  const tooltipArrowEl = useRef(null);
  const filterOptionsRef = useRef(null);

  const { state, dispatch } = useContext(FilterStore.Context);
  const [expanded, setExpanded] = useState(false);
  const [popper, setPopper] = useState<null | Popper.Instance>(null);

  useLayoutEffect(() => {
    const instance = createPopper(anchorEl.current as HTMLElement, tooltipEl.current as HTMLElement, {
      placement: `bottom-end`,
      modifiers: [
        {
          name: `arrow`,
          options: {
            element: tooltipArrowEl.current,
          },
          data: {
            y: 12,
          },
        },
        {
          name: `offset`,
          options: {
            offset: [0, 8],
          },
        },
      ],
    });

    setPopper(instance);
  }, []);

  useEffect(() => {
    const check = (ev: MouseEvent) => {
      if ((filterOptionsRef.current as HTMLElement).contains(ev.target as HTMLElement)) {
        return;
      } else {
        if (expanded) {
          setExpanded(false);
        }
      }
    };

    window.addEventListener(`click`, check);
    return () => window.removeEventListener(`click`, check);
  }, [filterOptionsRef.current, expanded]);

  useEffect(() => {
    if (!popper) {
      return;
    }

    popper.forceUpdate();
  }, [expanded]);

  const skippedTestsVisibilityChanged = () => {
    if (!state.excludedStates.includes(State.SKIPPED)) {
      dispatch({ type: `EXCLUDE_TEST_STATE`, state: State.SKIPPED });
    } else {
      dispatch({ type: `REMOVE_EXCLUDED_TEST_STATE`, state: State.SKIPPED });
    }
  };

  const passedTestsVisibilityChanged = () => {
    if (!state.excludedStates.includes(State.PASSED)) {
      dispatch({ type: `EXCLUDE_TEST_STATE`, state: State.PASSED });
    } else {
      dispatch({ type: `REMOVE_EXCLUDED_TEST_STATE`, state: State.PASSED });
    }
  };

  const wrapTestLinesChanged = () => {
    if (state.wrapTestLines) {
      dispatch({ type: `DONT_WRAP_LINES` });
    } else {
      dispatch({ type: `WRAP_LINES` });
    }
  };

  const trimReportNameChanged = () => {
    if (state.trimReportName) {
      dispatch({ type: `DONT_TRIM_REPORT_NAME` });
    } else {
      dispatch({ type: `TRIM_REPORT_NAME` });
    }
  };

  return (
    <div ref={filterOptionsRef}>
      <span className="gray hover-dark-gray pointer" ref={anchorEl} aria-expanded="false" onClick={() => setExpanded(!expanded)}>
        View
      </span>
      <div ref={tooltipEl} className="f5 bg-white br2 pa2 tooltip" style={{ zIndex: 200, display: expanded ? `` : `none`, boxShadow: `` }}>
        <div className="tooltip-arrow" data-popper-arrow ref={tooltipArrowEl}></div>
        <div className="b mv1 ph2 gray">Display preferences</div>
        <div>
          <label className="flex items-center pv1 ph2 br2 pointer hover-bg-lightest-blue">
            <input type="checkbox" checked={state.excludedStates.includes(State.SKIPPED)} onChange={skippedTestsVisibilityChanged}/>
            <span className="ml1">Hide Skipped tests</span>
          </label>
          <label className="flex items-center pv1 ph2 br2 pointer hover-bg-lightest-blue">
            <input type="checkbox" checked={state.excludedStates.includes(State.PASSED)} onChange={passedTestsVisibilityChanged}/>
            <span className="ml1">Hide Passed tests</span>
          </label>
          <label className="flex items-center pv1 ph2 br2 pointer hover-bg-lightest-blue">
            <input type="checkbox" checked={state.wrapTestLines} onChange={wrapTestLinesChanged}/>
            <span className="ml1">Wrap lines</span>
          </label>
          <label className="flex items-center pv1 ph2 br2 pointer hover-bg-lightest-blue">
            <input type="checkbox" checked={state.trimReportName} onChange={trimReportNameChanged}/>
            <span className="ml1">Trim report name</span>
          </label>
        </div>
      </div>
    </div>
  );
};

const QueryFilter = () => {
  const { state, dispatch } = useContext(FilterStore.Context);
  const debounceTimeout = 1000; // miliseconds

  const queryChanged = (event: Event) => {
    const target = event.target as HTMLInputElement;
    const query = target.value as FilterStore.SortOrder;
    dispatch({ type: `SET_QUERY`, query });
  };

  const deboundedQueryChanged = useMemo(() => _.debounce(queryChanged, debounceTimeout), []);

  return <input type="text" className="bn flex-auto" value={state.query} onInput={deboundedQueryChanged} placeholder="Find test…"/>;
};

const SortFilter = () => {
  const { state, dispatch } = useContext(FilterStore.Context);

  const sortChanged = (event: Event) => {
    const target = event.target as HTMLInputElement;
    const sort = target.value as FilterStore.SortOrder;
    dispatch({ type: `SET_SORT`, sort });
  };

  const availableFilters: Record<FilterStore.SortOrder, string> = {
    "failed-first": `Failed first`,
    alphabetical: `A-Z`,
    "slowest-first": `Slowest first`,
  };

  return (
    <select className="input-reset bn gray hover-dark-gray pa0 pointer" value={state.sort} onChange={sortChanged}>
      {Object.keys(availableFilters).map((filterKey: FilterStore.SortOrder) => {
        return (
          <option value={filterKey} key={filterKey}>
            {availableFilters[filterKey]}
          </option>
        );
      })}
    </select>
  );
};
