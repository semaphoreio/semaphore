import { createRef, Fragment, h } from "preact";
import { useContext, useEffect, useLayoutEffect, useState } from "preact/hooks";
import { NavigationStore, FilterStore } from "../stores";
import { Suite } from "../types/suite";
import { Duration } from "./duration";
import { Test } from "./test";
import * as types from "../types";
import { State } from "../util/stateful";
import $ from "jquery";

export interface TestSuiteProps {
  className?: string;
  suite: Suite;
  startExpanded: boolean;
}

export const TestSuite = ({ className, suite, startExpanded }: TestSuiteProps) => {
  const navigation = useContext(NavigationStore.Context);
  const filter = useContext(FilterStore.Context);
  const [expanded, setExpanded] = useState(false);

  const [filteredTests, setFilteredTests] = useState([]);
  const el = createRef();

  const sortTests = (suites: types.TestCase[], sort: FilterStore.SortOrder) => {
    switch(sort) {
      case `alphabetical`:
        suites
          .sort((a, b) => a.name.localeCompare(b.name));
        break;
      case `failed-first`:
        suites
          .sort((a, b) => b.state.valueOf() - a.state.valueOf());
        break;
      case `slowest-first`:
        suites
          .sort((a, b) => b.duration - a.duration);
        break;
    }
    return suites;
  };

  const classPalette = {
    dot: {
      [State.PASSED]: `green`,
      [State.FAILED]: `red`,
      [State.SKIPPED]: `gray`,
      [State.EMPTY]: `green`,
    }
  };

  useLayoutEffect(() => {
    if(navigation.state.activeTestId != ``) {
      return;
    }
    if(navigation.state.activeSuiteId == suite.id) {
      const currentEl = el.current as HTMLElement;
      $(`html`).animate({ scrollTop: currentEl.offsetTop - 100 }, 200);
    }
  }, []);

  useEffect(() => {
    let tests = [...suite.tests];

    tests = sortTests(tests, filter.state.sort);

    setFilteredTests(tests);
  }, [filter.state, suite]);

  useEffect(() => {
    setExpanded(filter.state.toggleAll);
  }, [filter.state.toggleAll]);

  useEffect(() => {
    if(startExpanded) {
      setExpanded(startExpanded);
    }
  }, [startExpanded]);

  useEffect(() => {
    if(navigation.state.activeSuiteId == suite.id) {
      setExpanded(true);
    }
  }, [navigation.state.activeSuiteId]);

  const toggleExpand = () => {
    if(expanded) {
      navigation.dispatch({ type: `SET_ACTIVE_SUITE`, suiteId: `` });
      setExpanded(false);
    }
    else {
      navigation.dispatch({ type: `SET_ACTIVE_SUITE`, suiteId: suite.id });
    }
  };

  return (
    <Fragment key={suite.id}>
      <div className={className} onClick={toggleExpand} ref={el}>
        <h4 className="f4 mb0 pointer">
          <span className={`mr1 ${classPalette.dot[suite.state]}`}>●</span>
          {suite.name}
          <span className="f6 normal gray ph1">{suite.summary.formattedResults()}</span>
        </h4>
        <div className="ph2-m">
          <Duration duration={suite.summary.duration} className="f7 code"/>
        </div>
      </div>
      {expanded &&
        <div className="bl b--lighter-gray pl3 ml1">
          {filteredTests.map((test) => {
            return <Test test={test} key={test.id}/>;
          }
          )}
        </div>
      }
    </Fragment>
  );
};
