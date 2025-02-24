import { h } from "preact";
import { Spendings } from "../types";
import * as components from "../components";
import * as types from "../types";
import * as stores from "../stores";
import { Dispatch, StateUpdater, useContext, useEffect, useLayoutEffect, useReducer, useState } from "preact/hooks";
import _ from "lodash";
import { Formatter } from "js/toolbox";
import moment from "moment";
import * as d3 from "d3";

enum AggregationType {
  Daily = `daily`,
  Cumulative = `cumulative`
}

interface Props {
  project: types.Spendings.DetailedProject;
}

export const ProjectChart = (props: Props) => {
  const [plotData, setPlotData] = useState<components.Charts.PlotData[]>([]);
  const [workflowPlotData, setWorkflowPlotData] = useState<components.Charts.PlotData[]>([]);
  const [currentPlotData, setCurrentPlotData] = useState<components.Charts.PlotData[]>([]);
  const [aggregationType, setAggregationType] = useState(AggregationType.Cumulative);
  const [domain, setDomain] = useState<[Date, Date]>([new Date(), new Date()]);
  const [selectedMetric, setSelectedMetrics] = useState(``);
  const [groupTypes, setGroupTypes] = useState<types.Spendings.GroupType[]>([props.project.cost.groups[0].type]);

  const [tooltipState, dispatchTooltip] = useReducer(stores.Tooltip.Reducer, {
    ...stores.Tooltip.EmptyState
  });

  const [colorScale, setColorScale] = useState<(arg0: string) => string>(() => d3.scaleOrdinal(d3.schemeTableau10));
  const project = props.project;

  useLayoutEffect(() => {
    if(!project)
      return;

    let aggregatedPlotData: components.Charts.PlotData[] = [];

    if(project.cost.groupTypes.length > 1 && project.cost.groupTypes.length == groupTypes.length) {
      aggregatedPlotData = _.chain([project])
        .map<components.Charts.PlotData[]>((project) => project.detailedPlotData)
        .map<components.Charts.PlotData[]>((plotData) => aggregatePlotData(plotData, aggregationType) )
        .flatten()
        .value();
    } else {
      aggregatedPlotData = _.chain([project])
        .map<components.Charts.PlotData[]>((project) => project.plotDataForGroup(groupTypes))
        .map<components.Charts.PlotData[]>((plotData) => aggregatePlotData(plotData, aggregationType) )
        .flatten()
        .value();
    }

    const colorScale = () => d3.scaleOrdinal<string, string>()
      .domain(project.metricNames())
      .range(d3.schemeTableau10);

    if(groupTypes.length == 1) {
      setColorScale(colorScale);
    }
    else {
      setColorScale(() => Formatter.colorFromName);
    }

    const workflowPlotData = _.chain([project])
      .map<components.Charts.PlotData[]>((project) => project.workflowPlotData)
      .map<components.Charts.PlotData[]>((plotData) => aggregatePlotData(plotData, aggregationType) )
      .flatten()
      .value();

    const plotDataTillNow = _.chain(aggregatedPlotData)
      .filter(plotData => moment(plotData.day).isSameOrBefore(moment()))
      .value();


    setPlotData(aggregatedPlotData);
    setCurrentPlotData(plotDataTillNow);
    setWorkflowPlotData(workflowPlotData);
  }, [project, aggregationType, groupTypes, selectedMetric]);

  useEffect(() => {
    if(!project)
      return;

    setDomain(project.plotDomain);
    setGroupTypes([props.project.cost.groups[0].type]);
  }, [project]);

  const aggregatePlotData = (plotData: components.Charts.PlotData[], aggregationType: AggregationType): components.Charts.PlotData[] => {
    let value = 0;
    const details: Record<string, number> = {};
    return _.chain([...plotData])
      .map(plotData => {
        let detailTotal = 0;
        switch(aggregationType) {
          case AggregationType.Cumulative:
            for(const detailName in plotData.details) {
              const detailValue = plotData.details[detailName];
              if(!details[detailName]) {
                details[detailName] = 0;
              }
              details[detailName] += detailValue;
              detailTotal += detailValue;
            }

            value += detailTotal;
            return { ...plotData, value, details: { ...details } } as components.Charts.PlotData;

          default:
          case AggregationType.Daily:
            return plotData;
        }
      })
      .value();
  };


  return (
    <div className="c-billing-chart">
      <stores.Tooltip.Context.Provider value={{ state: tooltipState, dispatch: dispatchTooltip }}>
        <components.Charts.Plot plotData={plotData} domain={domain}>
          <components.Charts.DateAxisX/>
          <components.Charts.MoneyScaleY/>
          <components.Charts.TooltipLine/>
          <components.Charts.StackedBar plotData={currentPlotData} colorScale={colorScale} selectedMetric={selectedMetric}/>
          <components.Charts.LineChartLeft plotData={workflowPlotData}/>
        </components.Charts.Plot>
        <Legend
          aggregationType={aggregationType}
          setAggregationType={setAggregationType}
          plotData={plotData}
          project={project}
          selectedMetric={selectedMetric}
          setSelectedMetrics={setSelectedMetrics}
          groupTypes={groupTypes}
          setGroupTypes={setGroupTypes}
          colorScale={colorScale}
        />
        <Tooltip plotData={workflowPlotData} selectedMetric={selectedMetric}/>
      </stores.Tooltip.Context.Provider>
    </div>
  );
};

interface TooltipProps {
  plotData: components.Charts.PlotData[];
  selectedMetric?: string;
}

const Tooltip = (props: TooltipProps) => {
  const { state: tooltip } = useContext(stores.Tooltip.Context);
  if(tooltip.hidden && !tooltip.focus)
    return;
  const adjustedLeft = (left: number) => {
    if (left < 2 * width) {
      left += 25;
    } else {
      left -= (width + 25);
    }

    return left;
  };

  if(!tooltip.tooltipMetrics)
    return;

  const width = 250;
  const left = adjustedLeft(tooltip.x);
  const metric = tooltip.tooltipMetrics[0];
  const selectedDetailName = props.selectedMetric;

  if(!metric)
    return;


  const workflowData = props.plotData.find((plotData) => moment(plotData.day).isSame(tooltip.selectedDate, `day`));

  return (
    <div
      className="tooltip"
      style={{
        "position": `absolute`,
        "top": tooltip.y,
        "left": left,
        "width": width,
        "z-index": `3`
      }}
    >
      <div className="f6">
        <b>{moment(metric.day).format(`MMMM Do`)}</b>
        <br/>
        {workflowData && <div className={`flex justify-between`}>
          <div>Workflow count</div>
          <div>{Formatter.decimalThousands(workflowData.value)}</div>
        </div>}
        <b>{metric.name}</b>
        <br/>
        {_.map(metric.details, (detailValue, detailName) => {
          return <div className={`flex justify-between ${selectedDetailName == detailName ? `b`: ``}`}>
            <div>{detailName}</div>
            <div>{Formatter.toMoney(detailValue)}</div>
          </div>;
        })}
        <div className="flex justify-between">
          <div>Total</div>
          <div>{Formatter.toMoney(metric.value)}</div>
        </div>
      </div>
    </div>
  );
};

interface LegendProps {
  aggregationType: AggregationType;
  setAggregationType: Dispatch<StateUpdater<AggregationType>>;
  project: types.Spendings.DetailedProject;
  plotData: components.Charts.PlotData[];
  selectedMetric: string;
  setSelectedMetrics: Dispatch<StateUpdater<string>>;
  groupTypes: Spendings.GroupType[];
  setGroupTypes: Dispatch<StateUpdater<Spendings.GroupType[]>>;
  colorScale: (arg0: string) => string;
}
const Legend = (props: LegendProps) => {
  const setAggregationFromEvent = (event: Event) => {
    const target = event.target as HTMLSelectElement;
    const aggregate = target.value as AggregationType;
    props.setAggregationType(aggregate);
  };
  const setGroup = (group: Spendings.GroupType) => {
    const index = props.groupTypes.indexOf(group);

    props.setSelectedMetrics(``);
    if(index == -1) {
      props.setGroupTypes([...props.groupTypes, group]);
    } else {
      const newGroupTypes = [...props.groupTypes];
      newGroupTypes.splice(index, 1);
      if(newGroupTypes.length == 0) {
        props.setGroupTypes(props.project.cost.groupTypes);
      } else {
        props.setGroupTypes(newGroupTypes);
      }
    }
  };

  const selectMetric = (metric: string) => {
    if(props.selectedMetric == metric) {
      props.setSelectedMetrics(``);
    } else {
      props.setSelectedMetrics(metric);
    }
  };

  let labels: string[] = [];
  if(props.groupTypes.length == 1) {
    labels = props.project.metricNamesForGroup(props.groupTypes[0]);
  }

  const showLabels = props.groupTypes.length == 1;
  return (
    <div className="bt b--black-075 gray pv3 ph3 flex items-center justify-between">
      <div className="flex items-center">
        <label className="mr2">Show</label>
        <select className="db form-control mb3 mb0-m mr2 form-control-tiny" value={props.aggregationType} onChange={ setAggregationFromEvent }>
          <option value={AggregationType.Cumulative}>Cumulative</option>
          <option value={AggregationType.Daily}>Daily</option>
        </select>
        <span className="mr2">for</span>
        {props.project.cost.groups.map((group, idx) => (
          <label className="flex items-center" key={idx}>
            <input type="checkbox" checked={props.groupTypes.includes(group.type)} onClick={ () => setGroup(group.type) }/>
            <span className="ml1 mr2">{ group.name }</span>
          </label>
        ))}
      </div>
      {showLabels && <div className="gray f6 pointer">
        <div className="tr inline-flex items-center">
          {labels.map((label, idx) => {
            let classes = ``;
            if(props.selectedMetric == label || props.selectedMetric == ``) {
              classes += `o-100`;
            } else {
              classes += `o-50`;
            }

            return <div key={idx} className={`inline-flex items-center ${classes}`} onClick={() => selectMetric(label)}>
              <span className="mr2 ml3 dib" style={`width: 10px; height: 10px; background: ${props.colorScale(label)};`}></span>
              <span className="">{label}</span>
            </div>;
          })}
        </div>
      </div>}
    </div>
  );
};
