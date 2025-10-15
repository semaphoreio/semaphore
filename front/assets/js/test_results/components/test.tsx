import { createRef, Fragment } from "preact";
import { useContext, useEffect, useLayoutEffect, useState } from "preact/hooks";
import { FilterStore, NavigationStore } from "../stores";
import { TestCase } from "../types/test_case";
import { State } from "../util/stateful";
import { Duration } from "./duration";
import $ from "jquery";

export interface TestProps {
  className?: string;
  test: TestCase;
}

export const Test = ({ test }: TestProps) => {
  const navigation = useContext(NavigationStore.Context);
  const filter = useContext(FilterStore.Context);
  const [expanded, setExpanded] = useState(false);

  const classPalette = {
    details: {
      active: {
        [State.PASSED]: `b--green`,
        [State.FAILED]: `b--red`,
        [State.SKIPPED]: `b--gray`,
        [State.EMPTY]: `b--green`,
      },
      notActive: {
        [State.PASSED]: `b--lightest-green`,
        [State.FAILED]: `b--lightest-red`,
        [State.SKIPPED]: `b--lightest-gray`,
        [State.EMPTY]: `b--lightest-green`,
      },
    },
    header: {
      active: {
        [State.PASSED]: ` bg-green white`,
        [State.FAILED]: ` bg-red white`,
        [State.SKIPPED]: ` bg-gray white`,
        [State.EMPTY]: ` bg-green white`,
      },
      notActive: {
        [State.PASSED]: `bg-lightest-green b--white hover-white hover-bg-green`,
        [State.FAILED]: `bg-lightest-red b--white hover-white hover-bg-red`,
        [State.SKIPPED]: `bg-lightest-gray b--white hover-white hover-bg-gray`,
        [State.EMPTY]: `bg-lightest-green b--white hover-white hover-bg-green`,
      },
    },
    timer: {
      [State.PASSED]: ` bg-green white`,
      [State.FAILED]: ` bg-red white`,
      [State.SKIPPED]: ` bg-gray white`,
      [State.EMPTY]: ` bg-green white`,
    },
    expanded: {
      active: `mb3`,
      notActive: ``,
    },
  };

  const toggleExpand = () => {
    if (expanded && test.id !== navigation.state.activeTestId) {
      navigation.dispatch({ type: `SET_ACTIVE_TEST`, testId: test.id });
      return;
    }

    if (expanded) {
      navigation.dispatch({ type: `SET_ACTIVE_TEST`, testId: `` });
    } else {
      navigation.dispatch({ type: `SET_ACTIVE_TEST`, testId: test.id });
    }

    setExpanded(!expanded);
  };

  const isActive = () => {
    return expanded && test.id == navigation.state.activeTestId;
  };

  const headerClass = () => {
    if (isActive()) {
      return classPalette.header.active[test.state];
    } else {
      return classPalette.header.notActive[test.state];
    }
  };

  const detailsClass = () => {
    if (isActive()) {
      return classPalette.details.active[test.state];
    } else {
      return classPalette.details.notActive[test.state];
    }
  };

  const expandedClass = () => {
    if (expanded) {
      return classPalette.expanded.active;
    } else {
      return classPalette.expanded.notActive;
    }
  };

  const durationClass = () => {
    return classPalette.timer[test.state];
  };

  const el = createRef();

  useEffect(() => {
    if (navigation.state.activeTestId == test.id) {
      setExpanded(true);
    }
  }, [navigation.state.activeTestId, test]);

  useLayoutEffect(() => {
    if (navigation.state.activeTestId == test.id) {
      const currentEl = el.current as HTMLElement;
      $(`html`).animate({ scrollTop: currentEl.offsetTop - 100 }, 200);
    }
  }, []);

  return (
    <div className={`${expandedClass()}`} ref={el}>
      <div className={`flex justify-between bt b--white pointer ${headerClass()}`} onClick={toggleExpand}>
        <div className="flex-auto ph2 word-wrap">{test.name}</div>
        <div className={`bl b--white f7 code flex items-center ph2 ${durationClass()}`}>
          <Duration duration={test.duration} className="f7 code"/>
        </div>
      </div>
      {expanded && (
        <TestDetails wrap={filter.state.wrapTestLines} test={test} className={`overflow-auto ph2 pv1 bl br bb bw1 ${detailsClass()}`}/>
      )}
    </div>
  );
};

export const TestDetails = ({ test, className, wrap }: { test: TestCase, className?: string, wrap: boolean }) => {
  const Info = ({ title, content }: { title: string, content: string }) => {
    return (
      <Fragment>
        <strong className="f6 db mt0 mb1">{title}</strong>
        <div className={`pre code f6 mb0 pb3 ${wrap ? `pre-wrap` : ``}`}>{content}</div>
      </Fragment>
    );
  };
  const FilePartial = () => {
    return <Fragment>{test.fileName != `` && <Info title="File" content={test.fileName}/>}</Fragment>;
  };

  const ClassPartial = () => {
    return <Fragment>{test.className != `` && <Info title="Class name" content={test.className}/>}</Fragment>;
  };

  const PackagePartial = () => {
    return <Fragment>{test.packageName != `` && <Info title="Package" content={test.packageName}/>}</Fragment>;
  };

  const FailurePartial = () => {
    return (
      <Fragment>
        {!test.failure.isEmpty() && <Info title={`${test.failure.type} ${test.failure.message}`} content={test.failure.body}/>}
      </Fragment>
    );
  };

  const SystemErrPartial = () => {
    return <Fragment>{test.systemErr != `` && <Info title="System Err" content={test.systemErr}/>}</Fragment>;
  };

  const SystemOutPartial = () => {
    return <Fragment>{test.systemOut != `` && <Info title="System Err" content={test.systemOut}/>}</Fragment>;
  };

  return (
    <div className={className} style={{ maxHeight: `480px` }}>
      <FilePartial/>
      <ClassPartial/>
      <PackagePartial/>
      <FailurePartial/>
      <SystemOutPartial/>
      <SystemErrPartial/>
    </div>
  );
};
