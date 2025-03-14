import { Report } from "../types/report";
import { Summary } from "../types/summary";
import { Duration } from "./duration";
import { State } from "../util/stateful";
import { useContext, useEffect } from "preact/hooks";
import { FilterStore, NavigationStore, ReportStore } from "../stores";
import { Inflector } from "../util";

export const NavBar = ({ className }: { className?: string, }) => {
  const reports = useContext(ReportStore.Context);
  const navigation = useContext(NavigationStore.Context);

  useEffect(() => {
    if(!navigation.state.activeReportId) {
      return;
    }

    const currentReport: Report = reports.state.items.find(report => report.id === navigation.state.activeReportId);

    if(!currentReport) {
      return;
    }

    reports.dispatch({ type: `SELECT_ITEM`, item: currentReport });
  }, [navigation.state.activeReportId, reports.state.items]);

  return (
    <div className={className}>
      <div className="pa2 gray">{Inflector.pluralize(reports.state.items.length, `test report`)}</div>
      {reports.state.items.map((report) => {
        return <NavBarItem
          className="pl2 pr3 pv1 mb2 pointer br2 br--left"
          report={report}
          key={report.id}
        />;
      })}
    </div>
  );
};

const NavBarItem = ({ className, report }: { className?: string, report: Report, }) => {
  const navigation = useContext(NavigationStore.Context);
  const filter = useContext(FilterStore.Context);
  const { summary } = report;
  const palette = {
    item: {
      class: {
        [State.FAILED]: `hover-bg-lightest-red br bw2 b--transparent`,
        [State.PASSED]: `hover-bg-lightest-green br bw2 b--transparent`,
        [State.SKIPPED]: `hover-bg-lightest-gray br bw2 b--transparent`,
        [State.EMPTY]: `hover-bg-lightest-green br bw2 b--transparent`,
      },
      focusClass: {
        [State.FAILED]: `bg-lightest-red b--red br--left br bw2`,
        [State.PASSED]: `bg-lightest-green b--green br--left br bw2`,
        [State.SKIPPED]: `bg-lightest-gray b--gray br--left br bw2`,
        [State.EMPTY]: `bg-lightest-green b--green br--left br bw2`,
      },
    },
    dot: {
      class: {
        [State.FAILED]: `red`,
        [State.PASSED]: `green`,
        [State.SKIPPED]: `gray`,
        [State.EMPTY]: `green`,
      }
    }
  };


  const itemClass = (summary: Summary): string => {
    if(navigation.state.activeReportId == report.id) {
      return `${palette.item.focusClass[summary.state]}`;
    } else {
      return `${palette.item.class[summary.state]}`;
    }
  };

  const dotClass = (summary: Summary): string => {
    return `${palette.dot.class[summary.state]}`;
  };

  const shouldTruncate = () => {
    return filter.state.trimReportName;
  };

  const setActiveReport = () => {
    navigation.dispatch({ type: `SET_ACTIVE_REPORT`, reportId: report.id });
  };


  return (
    <div className={className + ` ${itemClass(summary)}`} onClick={setActiveReport}>
      <div className={`b word-wrap ${shouldTruncate() ? `truncate` : ``}`}>
        <span className={`mr1 ${dotClass(summary)} select-none`}>●</span>
        {report.name}
      </div>
      <div className="f6">{report.summary.formattedResults()}</div>
      <div className="f6">Duration: <Duration duration={summary.duration}/></div>
    </div>
  );
};
