import { Spendings } from "../types";
import * as stores from "../stores";
import * as components from "../components";
import * as types from "../types";
import { Dispatch, StateUpdater, useContext, useLayoutEffect, useReducer, useState } from "preact/hooks";
import _ from "lodash";
// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
import { Notice } from "js/notice";
import moment from "moment";
import { Formatter } from "js/toolbox";
import * as d3 from "d3";

enum AggregationType {
  Daily = `daily`,
  Cumulative = `cumulative`,
}

export const ProjectsChart = () => {
  const config = useContext(stores.Config.Context);
  const spendings = useContext(stores.Spendings.Context);
  const [request, dispatchRequest] = useReducer(stores.Request.Reducer, {
    url: new URL(config.projectSpendings.topProjectsUrl as string, location.origin),
    status: types.RequestStatus.Zero,
  });
  const [projects, setProjects] = useState<types.Spendings.DetailedProject[]>([]);

  const spending = spendings.state.selectedSpending;
  if (!spending) return;

  useLayoutEffect(() => {
    if (spendings.state.selectedSpending) {
      dispatchRequest({ type: `SET_PARAM`, name: `spending_id`, value: spendings.state.selectedSpendingId });
      dispatchRequest({ type: `FETCH` });

      setProjects([]);
    }
  }, [spendings.state.selectedSpending]);

  useLayoutEffect(() => {
    if (request.status == types.RequestStatus.Fetch) {
      dispatchRequest({ type: `SET_STATUS`, value: types.RequestStatus.Loading });
      fetch(request.url)
        .then((response) => response.json())
        .then((json) => {
          dispatchRequest({ type: `SET_STATUS`, value: types.RequestStatus.Success });
          const projects = json.map(types.Spendings.DetailedProject.fromJSON) as types.Spendings.DetailedProject[];

          setProjects(projects);
        })
        .catch((e) => {
          // eslint-disable-next-line no-console
          console.error(e);
          dispatchRequest({ type: `SET_STATUS`, value: types.RequestStatus.Error });
          Notice.error(`Loading projects failed`);
        });
    }
  }, [request.status]);

  return (
    <stores.Request.Context.Provider value={{ state: request, dispatch: dispatchRequest }}>
      <Chart projects={projects} spending={spending}/>
    </stores.Request.Context.Provider>
  );
};

interface ChartProps {
  spending: Spendings.Spending;
  projects: types.Spendings.DetailedProject[];
}

const Chart = (props: ChartProps) => {
  const [plotData, setPlotData] = useState<components.Charts.PlotData[]>([]);
  const [aggregationType, setAggregationType] = useState(AggregationType.Cumulative);
  const projects = props.projects;
  const [selectedProject, setSelectedProject] = useState(``);
  const [domain, setDomain] = useState<[Date, Date]>([new Date(), new Date()]);
  const [tooltipState, dispatchTooltip] = useReducer(stores.Tooltip.Reducer, {
    ...stores.Tooltip.EmptyState,
  });

  useLayoutEffect(() => {
    if (!projects.length) return;

    // aggregate the data according to the aggregation type. We need aggregated plot data to properly calculate the scales
    const aggregatedPlotData = _.chain(projects)
      .map<components.Charts.PlotData[]>((project) => project.plotData)
      .map<components.Charts.PlotData[]>((plotData) => aggregatePlotData(plotData, aggregationType))
      .flatten()
      .value();

    const dates = _.map(projects, (project) => project.plotDomain);
    const minDate = _.minBy(dates, (d) => d[0]);
    const maxDate = _.maxBy(dates, (d) => d[1]);

    setDomain([minDate ? minDate[0] : new Date(), maxDate ? maxDate[1] : new Date()]);

    setPlotData(aggregatedPlotData);
  }, [projects, aggregationType]);

  const aggregatePlotData = (plotData: components.Charts.PlotData[], aggregationType: AggregationType): components.Charts.PlotData[] => {
    let value = 0;
    return _.chain(plotData)
      .map((plotData) => {
        switch (aggregationType) {
          case AggregationType.Cumulative:
            value += plotData.value;
            return { ...plotData, value } as components.Charts.PlotData;

          default:
          case AggregationType.Daily:
            return plotData;
        }
      })
      .value();
  };

  const colorScale = d3
    .scaleOrdinal<string, string>()
    .domain(props.projects.map((project) => project.name))
    .range(d3.schemeTableau10);

  return (
    <div className="c-billing-chart">
      <components.Loader.Container
        loadingElement={<components.Loader.LoadingSpinner text={`Loading chart…`}/>}
        loadingFailedElement={<components.Loader.LoadingFailed text={`Loading chart failed`} retry={true}/>}
      >
        <stores.Tooltip.Context.Provider value={{ state: tooltipState, dispatch: dispatchTooltip }}>
          <components.Charts.Plot plotData={plotData} domain={domain}>
            <components.Charts.DateAxisX/>
            <components.Charts.MoneyScaleY/>
            <components.Charts.TooltipLine/>
            <>
              {projects.map((project, idx) => {
                const projectSelected = project.name == selectedProject || selectedProject == ``;
                return (
                  <components.Charts.LineChart
                    key={idx}
                    colorScale={colorScale}
                    plotData={aggregatePlotData(project.plotDataBeforeToday, aggregationType)}
                    style={projectSelected ? `opacity: 1;` : `opacity: 0.2;`}
                  />
                );
              })}
            </>
          </components.Charts.Plot>
          <Legend
            aggregationType={aggregationType}
            setAggregationType={setAggregationType}
            projects={projects}
            selectedProject={selectedProject}
            setSelectedProject={setSelectedProject}
          />
          <Tooltip/>
        </stores.Tooltip.Context.Provider>
      </components.Loader.Container>
    </div>
  );
};

const Tooltip = () => {
  const { state: tooltip } = useContext(stores.Tooltip.Context);
  if (tooltip.hidden && !tooltip.focus) return;
  const adjustedLeft = (left: number) => {
    if (left < 2 * width) {
      left += 25;
    } else {
      left -= width + 25;
    }

    return left;
  };

  if (!tooltip.tooltipMetrics) return;

  const width = 250;
  const left = adjustedLeft(tooltip.x);
  const metrics = tooltip.tooltipMetrics;
  const firstMetric = metrics[0];

  return (
    <div
      className="tooltip"
      style={{
        position: `absolute`,
        top: tooltip.y,
        left: left,
        width: width,
        "z-index": `3`,
      }}
    >
      <div className="f6">
        <b>{moment(firstMetric.day).format(`MMMM Do`)}</b>
        <br/>
        {metrics.map((metric, idx) => {
          return (
            <div className={`flex justify-between`} key={idx}>
              <div>{metric.name}</div>
              <div>{Formatter.toMoney(metric.value)}</div>
            </div>
          );
        })}
      </div>
    </div>
  );
};

interface LegendProps {
  aggregationType: AggregationType;
  setAggregationType: Dispatch<StateUpdater<AggregationType>>;
  projects: types.Spendings.Project[];
  selectedProject: string;
  setSelectedProject: Dispatch<StateUpdater<string>>;
}
const Legend = (props: LegendProps) => {
  const selectProject = (project: types.Spendings.Project) => () => {
    if (project.name == props.selectedProject) {
      props.setSelectedProject(``);
    } else {
      props.setSelectedProject(project.name);
    }
  };

  const setAggregationFromEvent = (event: Event) => {
    const target = event.target as HTMLSelectElement;
    const aggregate = target.value as AggregationType;
    props.setAggregationType(aggregate);
  };

  const colorScale = d3
    .scaleOrdinal<string, string>()
    .domain(props.projects.map((project) => project.name))
    .range(d3.schemeTableau10);

  return (
    <div className="bt b--black-075 gray pv3 ph3 flex items-center justify-between">
      <div className="flex items-center">
        <label className="mr2">Show</label>
        <select
          className="db form-control mb3 mb0-m mr2 form-control-tiny"
          value={props.aggregationType}
          onChange={setAggregationFromEvent}
        >
          <option value={AggregationType.Cumulative}>Cumulative</option>
          <option value={AggregationType.Daily}>Daily</option>
        </select>
      </div>
      <div className="gray f6 pointer">
        <div className="tr inline-flex items-center">
          {props.projects.map((project, idx) => {
            let classes = ``;
            if (props.selectedProject == project.name || props.selectedProject == ``) {
              classes += `o-100`;
            } else {
              classes += `o-50`;
            }

            return (
              <div
                key={idx}
                className={`inline-flex items-center ${classes}`}
                onClick={selectProject(project)}
              >
                <span className="mr2 ml3 dib" style={`width: 10px; height: 10px; background: ${colorScale(project.name)};`}></span>
                <span className="">{project.name}</span>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
};
