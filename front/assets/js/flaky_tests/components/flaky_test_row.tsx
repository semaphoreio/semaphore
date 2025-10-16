import { Fragment } from "preact";
import * as util from "../../insights/util";
import { DisruptionHistoryChart } from "./index";
import { FlakyTestItem } from "../types/flaky_test_item";
import { useContext, useEffect, useState } from "preact/hooks";
import { Link } from "react-router-dom";
import * as stores from "../stores";
import * as components from "../components";

export const FlakyTestRow = ({ item }: { item: FlakyTestItem, }) => {
  const [labels, setLabels] = useState([``]);
  useEffect(() => {
    const labels = item.labels.map((label) => {
      return label;
    });
    setLabels(labels);
  }, [item]);

  return (
    <div className="flex-m bt b--black-10 pv2 items-center">
      {/*Name*/}
      <div className="w-25-m" style={{ wordBreak: `break-word` }}>
        <Name item={item}/>
      </div>

      {/*  Labels */}
      <div className="w-10-m flex flex-column items-center justify-center">
        <components.LabelList
          testId={item.testId}
          labels={labels}
          setLabels={setLabels}
        />
      </div>

      {/* Age */}
      <div className="w-10-m flex flex-column items-center justify-center">
        <span className="gray">{item.daysAge()}</span>
      </div>

      {/*  Latest flaky occurrence */}
      <div className="w-10-m flex flex-column items-center justify-center">
        <LatestFlakyOccurrence item={item}/>
      </div>

      {/*  Disruption History*/}
      <div className="w-25-m flex flex-column items-center justify-center flex-wrap">
        <DisruptionHistoryChart items={item.disruptionHistory}/>
      </div>

      {/*  Disruptions */}
      <div className="w-10-m flex flex-column items-center justify-center">
        <span className="f3 b">{item.disruptions}</span>
      </div>

      {/*    Actions */}
      <div className="w-10-m flex flex-column items-center justify-center">
        <components.Actions item={item}/>
      </div>
    </div>
  );
};

const Name = ({ item }: { item: FlakyTestItem, }) => {
  const { state: filterState, dispatch: dispatchFilter } = useContext(
    stores.Filter.Context
  );

  const onClick = (toAppend: string) => {
    const query = filterState.query;
    const setQuery = (q: string) =>
      dispatchFilter({ type: `SET_QUERY`, value: q });
    if (query.includes(toAppend)) return;
    const q = `${query} ${toAppend}`;
    setQuery(q);
  };

  return (
    <div className="flex-m items-start justify-between">
      <div className="pr3-m">
        <div>
          <Link to={item.testId}>{item.testName}</Link>
        </div>
        <a
          className="f5 mt1 black link underline-hover db pointer"
          onClick={() => onClick(`@test.group:"${item.testGroup}"`)}
        >
          {item.testGroup}
        </a>
        <a
          className="f6 gray link underline-hover db pointer"
          onClick={() => onClick(`@test.runner:"${item.testRunner}"`)}
        >
          {item.testRunner}
        </a>
        <a
          className="f6 gray link underline-hover db pointer"
          onClick={() => onClick(`@test.suite:"${item.testSuite}"`)}
        >
          {item.testSuite}
        </a>
      </div>
    </div>
  );
};

const LatestFlakyOccurrence = ({ item }: { item: FlakyTestItem, }) => {
  return (
    <Fragment>
      <div title={util.Formatter.dateTime(item.latestDisruptionTimestamp)}>
        <a
          href={item.latestDisruptionJobUrl}
          className="link gray underline-hover"
          target="_blank"
          rel="noreferrer"
        >
          {util.Formatter.dateDiff(item.latestDisruptionTimestamp, new Date())}
        </a>
      </div>
      <div className="flex items-center ph2">
        <span className="material-symbols-outlined b f4 db mr2 gray">
          commit
        </span>
        <a
          href={item.latestDisruptionJobUrl}
          className="link gray underline-hover"
          target="_blank"
          rel="noreferrer"
        >
          {item.latestDisruptionHash.slice(0, 7)}
        </a>
      </div>
    </Fragment>
  );
};
