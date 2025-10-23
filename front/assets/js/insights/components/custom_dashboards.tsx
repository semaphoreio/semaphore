import { useNavigate, useParams } from "react-router-dom";
import { useContext, useLayoutEffect, useState } from "preact/hooks";
import { Dashboard, DashboardItem } from "../types/dashboard";
import { DashboardItemForm } from "./forms/dashboard_item_form";
import * as types from "../types";
import * as util from "../util";
import { useToggle } from "../util";
import { CreateDashboardItem } from "../types/json_interface";
import { Config } from "../app";
import { State as DState } from "../stores/dashboards";
import { State as DRState } from "../stores/metric_date_range";
// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
import { Notice } from "../../notice";
import { DashboardItemCard } from "./dashboard_item_card";
import { InsightsType, typeByMetric } from "../types/insights_type";
import { empty_custom_dashboard } from "./zero_state/empty_custom_dashboard";
import Tippy from "@tippyjs/react";
import { handleMetricDatePickerChanged } from "../util/event_handlers";
import * as stores from "../stores";

interface Props {
  state: DState;
  dispatchDashboard: any;
  deleteHandler: (id: string) => void;
  renameHandler: (id: string, name: string) => void;
}

export const CustomDashboards = ({
  state,
  dispatchDashboard,
  deleteHandler,
  renameHandler,
}: Props) => {
  const { id } = useParams<`id`>();
  const dashboard = state.dashboards.find((d) => d.id === id);
  const navigate = useNavigate();
  const {
    dashboardsUrl,
    pipelineReliabilityUrl,
    pipelineFrequencyUrl,
    pipelinePerformanceUrl,
  } = useContext(Config);

  const dateRangeStore = useContext(stores.MetricDateRange.Context);
  const dateRangeState = dateRangeStore.state;
  const endpointUrls = new EndpointUrls();
  endpointUrls.performance = pipelinePerformanceUrl;
  endpointUrls.reliability = pipelineReliabilityUrl;
  endpointUrls.frequency = pipelineFrequencyUrl;
  endpointUrls.dashboards = dashboardsUrl;

  const [dashboardName, setDashboardName] = useState(dashboard.name);

  const { show, toggle } = useToggle();

  if (!dashboard) {
    navigate(`/performance`);
    return;
  }

  const scrollToForm = () => {
    toggle();
    setTimeout(() => {
      document
        .getElementById(`dashboard-item-form`)
        ?.scrollIntoView({ behavior: `smooth` });
    }, 100);
  };

  useLayoutEffect(() => {
    let items = dashboard.items;
    if (!items) {
      items = [];
    }

    const routeItems = urlBuilder(endpointUrls, items, dateRangeState);
    for (const [url, items] of routeItems) {
      metricsFetcher(url, items, dashboard.id, dispatchDashboard).catch(() => {
        return;
      });
    }
  }, [dashboard, dateRangeState.selectedMetricDateRangeLabel]);

  // --- rename dashboard item
  const updateDashboardItem = async (
    url: string,
    dashboardId: string,
    id: string,
    name: string,
    notes: string
  ) => {
    try {
      const response = await fetch(`${url}/${dashboardId}/${id}`, {
        method: `PUT`,
        headers: util.Headers(),
        body: `name=${name}&description=${notes}`,
      });

      if (response.ok) {
        dispatchDashboard({
          type: `UPDATE_DASHBOARD_ITEM_NAME`,
          dashboardId: dashboard.id,
          itemId: id,
          name: name,
        });

        dispatchDashboard({
          type: `UPDATE_DASHBOARD_ITEM_DESCRIPTION`,
          dashboardId: dashboard.id,
          itemId: id,
          description: notes,
        });
      }
    } catch (e) {
      Notice.error(`Failed to update Dashboard Item.`);
    }
  };

  const updateDashboardItemHandler = (
    id: string,
    name: string,
    notes: string
  ) => {
    updateDashboardItem(dashboardsUrl, dashboard.id, id, name, notes).catch(
      () => {
        return;
      }
    );
  };

  // --- delete dashboard item

  const deleteDashboardItem = async (
    url: string,
    dashboardId: string,
    id: string
  ) => {
    try {
      const response = await fetch(`${url}/${dashboardId}/${id}`, {
        method: `DELETE`,
        headers: util.Headers(),
      });

      if (response.ok) {
        dispatchDashboard({
          type: `DELETE_DASHBOARD_ITEM`,
          dashboardId: dashboard.id,
          itemId: id,
        });
      }
    } catch (e) {
      Notice.error(`Failed to delete Dashboard Item.`);
    }
  };

  const deleteDashboardItemHandler = (id: string) => {
    deleteDashboardItem(dashboardsUrl, dashboard.id, id).catch(() => {
      return;
    });
  };

  // --- create new dashboard item
  const sendNewDashboardItem = async (
    url: string,
    dashboardId: string,
    item: object
  ) => {
    try {
      const response = await fetch(`${url}/${dashboardId}`, {
        method: `POST`,
        headers: util.Headers(`application/json`),
        body: JSON.stringify(item),
      });
      const data: CreateDashboardItem = await response.json();
      const dashboardItem = types.Dashboard.DashboardItem.fromJSON(data.item);
      //load metric

      const routeItems = urlBuilder(
        endpointUrls,
        [dashboardItem],
        dateRangeState
      );
      for (const [url, items] of routeItems) {
        metricsFetcher(url, items, dashboard.id, dispatchDashboard).catch(
          () => {
            return;
          }
        );
      }
      dispatchDashboard({
        type: `ADD_DASHBOARD_ITEM`,
        id: dashboard.id,
        item: dashboardItem,
      });
      dashboard.items.push(dashboardItem);
      Notice.notice(`New Metric added to Dashboard.`);
    } catch (e) {
      Notice.error(`Failure to create dashboard item.`);
    }
  };

  const saveHandler = (item: object) => {
    sendNewDashboardItem(dashboardsUrl, dashboard.id, item).catch(() => {
      return;
    });
  };

  const [visible, setVisible] = useState(false);
  const showTippy = () => setVisible(true);
  const hideTippy = () => setVisible(false);

  // -- event handlers
  const onInputNameChange = (e: any) => {
    setDashboardName(e.target.value as string);
  };

  const onSubmit = (e: any) => {
    e.preventDefault();
    renameHandler(dashboard.id, dashboardName);
  };

  // ----- render
  return (
    <div className="w-100 pa4">
      <div className="flex items-center mb1">
        <h1 className="f3 mr2 mb0">
          <span>{dashboard.name}</span>
        </h1>

        <Tippy
          trigger="click"
          interactive={true}
          theme="light"
          placement="bottom"
          allowHTML={true}
          visible={visible}
          onClickOutside={hideTippy}
          content={
            <form onSubmit={onSubmit}>
              <div className="f5 pa1">
                <div className="b mb1">Dashboard name</div>
                <input
                  value={dashboardName}
                  onInput={onInputNameChange}
                  className="x-select-on-click form-control w-90 mb1"
                />
                <div className="mt3">
                  <button
                    className="btn btn-primary btn-small"
                    onClick={hideTippy}
                    type="submit"
                  >
                    Save
                  </button>
                  <button
                    className="btn btn-secondary ml2 btn-small"
                    type="reset"
                    onClick={hideTippy}
                  >
                    Cancel
                  </button>
                </div>
                <div className="mt2 bt b--lighter-gray pt2">
                  <button
                    className="link"
                    onClick={() => confirmDeletion(deleteHandler, id)}
                    type="reset"
                  >
                    Delete
                  </button>
                </div>
              </div>
            </form>
          }
        >
          <button
            className="btn btn-secondary btn-tiny"
            onClick={visible ? hideTippy : showTippy}
          >
            Edit
          </button>
        </Tippy>
        <div className="ml-auto">
          <select
            className="form-control mw5 form-control-tiny"
            onChange={handleMetricDatePickerChanged(dateRangeStore.dispatch)}
            value={dateRangeState.selectedMetricDateRangeLabel}
          >
            {dateRangeState.dateRanges.map((d) => (
              <option key={d.label} value={d.label}>
                {d.label}
              </option>
            ))}
          </select>
        </div>
      </div>

      <div hidden={shouldHideEmptyPage(dashboard, show)}>
        {empty_custom_dashboard(toggle)}
      </div>
      <div hidden={isEmpty(dashboard)}>
        {dashboard.items?.map((item: DashboardItem) => (
          <DashboardItemCard
            key={item.id}
            item={item}
            metrics={state.metrics.get(item.id)}
            updateHandler={updateDashboardItemHandler}
            deleteHandler={deleteDashboardItemHandler}
          />
        ))}
        <div className="mt3">
          <button
            className="btn btn-primary mb2"
            hidden={show}
            onClick={scrollToForm}
          >
            Add New Metric
          </button>
        </div>
      </div>

      <div hidden={!show}>{DashboardItemForm({ toggle, saveHandler })}</div>
    </div>
  );
};

const isEmpty = (d: Dashboard) => {
  return d.items === undefined || d.items.length === 0;
};

const fromJsonByInsightsType = (item: DashboardItem) => {
  switch (typeByMetric(item.settings.metric)) {
    case InsightsType.Performance:
      return (json: types.JSONInterface.PipelinePerformance) => {
        const response =
          types.PipelinePerformance.DynamicMetrics.fromJSON(json);
        return response.metrics;
      };
    case InsightsType.Frequency:
      return (json: types.JSONInterface.PipelineFrequency) => {
        const response = types.PipelineFrequency.Metrics.fromJSON(json);
        return response.metrics;
      };
    case InsightsType.Reliability:
      return (json: types.JSONInterface.PipelineReliability) => {
        const response = types.PipelineReliability.Metrics.fromJSON(json);
        return response.metrics;
      };
  }
};

class EndpointUrls {
  dashboards: string;
  performance: string;
  frequency: string;
  reliability: string;
}

const urlBuilder = (
  endpointUrls: EndpointUrls,
  items: DashboardItem[],
  state: DRState
): Map<string, DashboardItem[]> => {
  const map = new Map<string, DashboardItem[]>();
  const url = (type: InsightsType): string => {
    switch (type) {
      case InsightsType.Performance:
        return endpointUrls.performance;
      case InsightsType.Frequency:
        return endpointUrls.frequency;
      case InsightsType.Reliability:
        return endpointUrls.reliability;
    }
  };

  for (const item of items) {
    if (item == null || isInvalid(item)) {
      continue;
    }

    const from = state.selectedMetricDateRange.from;
    const to = state.selectedMetricDateRange.to;
    const urlString = url(typeByMetric(item.settings.metric))
      .concat(
        `?custom_dashboards=true&branch=${item.branchName}&ppl_file_name=${item.pipelineFileName}`
      )
      .concat(`&from_date=${from}&to_date=${to}`);

    if (map.has(urlString)) {
      map.get(urlString).push(item);
    } else {
      map.set(urlString, [item]);
    }
  }

  return map;
};

const metricsFetcher = async (
  url: string,
  items: DashboardItem[],
  dashboardId: string,
  dispatcher: any
) => {
  const response = await fetch(url);
  const data: any = await response.json();

  for (const item of items) {
    const fromJson = fromJsonByInsightsType(item);
    dispatcher({
      type: `ADD_ITEM_METRICS`,
      // eslint-disable-next-line @typescript-eslint/no-unsafe-argument
      metrics: fromJson(data),
      itemId: item.id,
    });
  }
};

const isInvalid = (item: DashboardItem): boolean => {
  return (
    item.settings == null ||
    item.settings.metric == 0 ||
    item.branchName == null ||
    item.pipelineFileName == null
  );
};

function shouldHideEmptyPage(dashboard: Dashboard, show: boolean) {
  return !isEmpty(dashboard) || show;
}

function confirmDeletion(deleteHandler: (id: string) => void, id: string) {
  const result = confirm(`Are you sure you want to delete?`);
  if (result) {
    deleteHandler(id);
  }
}
