import { createRef } from "preact";
import { useContext, useEffect, useLayoutEffect, useState } from "preact/hooks";
import { ReportStore, FilterStore, NavigationStore } from "../stores";
import { Filters } from "./filters";
import { TestSuite } from "./test_suite";
import * as types from "../types";
import _ from "lodash";
import { Inflector } from "../util";
import { State } from "../util/stateful";
import $ from "jquery";

export const TestExplorer = ({ className }: { className: string, }) => {
  const filter = useContext(FilterStore.Context);
  const report = useContext(ReportStore.Context);
  const navigation = useContext(NavigationStore.Context);
  const activeReport = report.state.selectedItem;
  const [filteredSuites, setFilteredSuites] = useState([]);
  const [expandedSuiteIds, setExpandedSuiteIds] = useState([]);
  const el = createRef();

  const sortSuites = (suites: types.Suite[], sort: FilterStore.SortOrder) => {
    switch(sort) {
      case `alphabetical`:
        suites
          .sort((a, b) => a.name.localeCompare(b.name));
        break;
      case `failed-first`:
        suites
          .sort((a, b) => b.summary.failed - a.summary.failed);
        break;
      case `slowest-first`:
        suites
          .sort((a, b) => b.summary.duration - a.summary.duration);
        break;
    }
    return suites;
  };


  useEffect(() => {
    let suites = _.cloneDeep(activeReport.suites);

    suites = suites
      .filter((suite) => {
        return suite.matchesFilter(filter.state);
      })
      .map((suite) => {
        return suite.applyFilter(filter.state);
      });

    suites = sortSuites(suites, filter.state.sort);

    setFilteredSuites(suites);
  }, [filter.state, activeReport]);

  useEffect(() => {
    const failedSuites = activeReport.suites.filter((suite) => suite.state == State.FAILED);
    if(failedSuites.length > 0) {
      if(navigation.state.activeSuiteId != `` && !failedSuites.find((suite) => navigation.state.activeSuiteId == suite.id)) {
        return;
      }
      setExpandedSuiteIds(failedSuites.map((suite) => suite.id));
      filter.dispatch({ type: `SET_EXCLUDED_TEST_STATE`, states: [State.EMPTY, State.SKIPPED, State.PASSED] });
    } else {
      filter.dispatch({ type: `SET_EXCLUDED_TEST_STATE`, states: [State.EMPTY] });
    }
  }, [activeReport]);


  useLayoutEffect(() => {
    if(navigation.state.activeReportId != `` && el.current && navigation.state.activeSuiteId == ``) {
      const currentEl = el.current as HTMLElement;
      $(`html`).animate({ scrollTop: currentEl.offsetTop - 100 }, 200);
    }
  }, [navigation.state.activeReportId]);

  return (
    <div className={className} ref={el}>
      <div className="pt2 pb2">
        Selected report: <span className="b">{activeReport.name}</span>
      </div>
      <Filters/>
      {filter.state.query != `` && <SearchResults filteredSuites={filteredSuites}/>}
      {filteredSuites.map((suite) => {
        return <TestSuite
          key={suite.id}
          suite={suite}
          startExpanded={expandedSuiteIds.includes(suite.id)}
          className="flex justify-between mv1"
        />;
      })}
      {activeReport.isEmpty() &&
        <div className="tc">
          It looks like this report is empty.
        </div>
      }
      {filter.state.excludedStates.length != 0 && <FilterInfo suites={activeReport.suites} filteredSuites={filteredSuites}/>}
    </div>
  );
};

const SearchResults = (state: { filteredSuites: types.Suite[], }) => {
  const filter = useContext(FilterStore.Context);

  const { filteredSuites } = state;
  const testCount = filteredSuites.reduce((sum, suite) => sum + suite.tests.length, 0);
  return (
    <div data-search-box="">
      <div className="mt1 mb2 f6 tc gray">
        <span>
          Found <b>{Inflector.pluralize(testCount, `test`)}</b> matching your criteria.
        </span>
        <br/>
        <span>
          <a className="gray hover-dark-gray underline pointer h7" onClick={() => filter.dispatch({ "type": `SET_QUERY`, query: `` })}>
            Clear search
          </a>
        </span>
      </div>
    </div>
  );
};

const FilterInfo = (state: { suites: types.Suite[], filteredSuites: types.Suite[], }) => {
  const filter = useContext(FilterStore.Context);
  const { suites, filteredSuites } = state;

  const suiteSummary = suites.reduce((sum, suite) => {
    return sum.add(suite.summary);
  }, types.Summary.empty());

  // We need to use cloneDeep because syncSummary mutates the suite
  const filteredSuiteSummary = _.cloneDeep(filteredSuites).reduce((sum, suite) => {
    suite.syncSummary();
    return sum.add(suite.summary);
  }, types.Summary.empty());

  const resultSummary = suiteSummary.sub(filteredSuiteSummary);

  const formatResults = (summary: types.Summary) => {
    interface formatResult {
      count: number;
      label: string;
      state: State;
    }

    const results: formatResult[] = [
      { count: summary.passed, label: `passed test`, state: State.PASSED },
      { count: summary.failed, label: `failed test`, state: State.FAILED },
      { count: summary.skipped, label: `skipped test`, state: State.SKIPPED },
    ];

    return results
      .filter((result) => {
        return result.count > 0;
      })
      .filter((result) => {
        return filter.state.excludedStates.includes(result.state);
      })
      .map((result) => {
        return Inflector.pluralize(result.count, result.label);
      })
      .join(`, `);

  };

  const displayAll = () => {
    filter.dispatch({ type: `SET_EXCLUDED_TEST_STATE`, states: [] });
  };

  const results = formatResults(resultSummary);

  if(results.length == 0) {
    return;
  } else {
    return (
      <div className="mv4 f6 tc">
        <p className="gray mb0">Hidden: {formatResults(resultSummary)}</p>
        <p><span className="gray hover-dark-gray underline pointer" onClick={displayAll}>Show everything</span></p>
      </div>
    );
  }
};
