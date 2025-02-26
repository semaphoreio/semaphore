
import {
  Routes,
  Route,
  Navigate,
  useNavigate,
  useLocation,
} from "react-router-dom";
import {
  useContext,
  useEffect,
  useLayoutEffect,
  useReducer,
} from "preact/hooks";
import { Config } from "../app";

import * as types from "../types";
import * as stores from "../stores";
import * as util from "../util";
import * as components from "./index";
import { CreateDashboard } from "../types/json_interface";
// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
import { Notice } from "../../notice";
import { MetricsDateRange } from "../types/metric_date_range";
import { Userpilot } from "userpilot";

export const Insights = () => {
  const appConfig = useContext(Config);

  const [loading, dispatchLoading] = useReducer(
    stores.Loading.Reducer,
    stores.Loading.EmptyState
  );
  const [summary, dispatchSummary] = useReducer(
    stores.Summary.Reducer,
    stores.Summary.EmptyState
  );
  const [metricDateRange, dispatchMetricDateRange] = useReducer(
    stores.MetricDateRange.Reducer,
    stores.MetricDateRange.EmptyState
  );

  const loc = useLocation();

  useEffect(() => {
    Userpilot.reload();
  }, [loc]);

  const fetchSummary = (url: string) => {
    return fetch(url)
      .then((response) => response.json())
      .then((res: types.JSONInterface.Summary) => {
        return res;
      });
  };

  const fetchAvailableDates = (url: string) => {
    return fetch(url)
      .then((response) => response.json())
      .then((res: types.JSONInterface.AvailableDateRanges) => {
        return res;
      });
  };

  useLayoutEffect(() => {
    fetchAvailableDates(appConfig.availableDatesUrl)
      .then((res) => {
        dispatchMetricDateRange({
          type: `SET_METRIC_DATE_RANGES`,
          value: MetricsDateRange.fromJSON(res).ranges,
        });
      })
      .catch(() => {
        dispatchMetricDateRange({ type: `SET_METRIC_DATE_RANGES`, value: [] });
      });
  }, []);

  useEffect(() => {
    const url = new URL(appConfig.summaryUrl, location.origin);

    if (metricDateRange.selectedMetricDateRange) {
      const { from, to } = metricDateRange.selectedMetricDateRange;
      url.searchParams.set(`from_date`, from);
      url.searchParams.set(`to_date`, to);
    }

    const fetchDefaultBranchMetrics = fetchSummary(url.toString());

    url.searchParams.set(`branch`, `all`);
    const fetchAllBranchesMetrics = fetchSummary(url.toString());

    url.searchParams.delete(`branch`);
    url.searchParams.set(`cd`, `true`);
    const fetchCdSummaryMetrics = fetchSummary(url.toString());

    dispatchLoading({ type: `RESET` });
    Promise.all([
      fetchDefaultBranchMetrics,
      fetchAllBranchesMetrics,
      fetchCdSummaryMetrics,
    ])
      .then((summaries) => {
        const [defaultBranch, allBranches, cdSummary] = summaries;
        const summary = types.Summary.Project.fromJSON(
          defaultBranch,
          allBranches,
          cdSummary
        );

        dispatchSummary({ type: `SET_SUMMARY`, summary });
      })
      .catch((err) => {
        dispatchLoading({ type: `ADD_ERROR`, error: err });
      })
      .finally(() => {
        dispatchLoading({ type: `LOADED` });
      });
  }, [metricDateRange.selectedMetricDateRangeLabel]);

  const navigate = useNavigate();
  const [dashboards, dispatchDashboards] = useReducer(
    stores.Dashboards.Reducer,
    stores.Dashboards.EmptyState
  );
  const { dashboardsUrl } = useContext(Config);

  const fetchDashboards = async (url: string) => {
    try {
      const response = await fetch(url);
      const data: types.JSONInterface.Dashboards = await response.json();
      const dashboards = types.Dashboard.Dashboards.fromJSON(data);
      dispatchDashboards({ type: `SET_STATE`, state: dashboards.dashboards });
    } catch (e) {
      Notice.error(`Failed to load Dashboards`);
    }
  };

  useLayoutEffect(() => {
    fetchDashboards(dashboardsUrl).catch(() => {
      return;
    });
  }, []);

  //extract headers machinery to a new network component and use it here
  const sendNewDashboard = async (url: string, name: string) => {
    try {
      const response = await fetch(url, {
        method: `POST`,
        headers: util.Headers(),
        body: `name=${name}`,
      });
      const data: CreateDashboard = await response.json();
      const dashboard = types.Dashboard.Dashboard.fromJSON(data.dashboard);
      dispatchDashboards({ type: `ADD_DASHBOARD`, dashboard: dashboard });
      navigate(`/custom-dashboards/${dashboard.id}`);
    } catch (e) {
      Notice.error(`Failed to create Dashboard`);
    }
  };

  const createDashboard = (name: string) => {
    sendNewDashboard(dashboardsUrl, name).catch(() => {
      return;
    });
  };

  const deleteDashboard = async (url: string, id: string) => {
    try {
      const response = await fetch(`${url}/${id}`, {
        method: `DELETE`,
        headers: util.Headers(),
      });

      if (response.ok) {
        dispatchDashboards({ type: `DELETE_DASHBOARD`, id: id });
        navigate(`/`);
      }
    } catch (e) {
      Notice.error(`Failed to delete Dashboard`);
    }
  };

  const updateDashboard = async (url: string, id: string, name: string) => {
    try {
      const response = await fetch(`${url}/${id}`, {
        method: `PUT`,
        headers: util.Headers(),
        body: `name=${name}`,
      });

      if (response.ok) {
        dispatchDashboards({
          type: `UPDATE_DASHBOARD_NAME`,
          id: id,
          name: name,
        });
      }
    } catch (e) {
      Notice.error(`Failed to update Dashboard`);
    }
  };

  const deleteDashboardHandler = (id: string) => {
    deleteDashboard(dashboardsUrl, id).catch(() => {
      return;
    });
  };

  const updateDashboardHandler = (id: string, name: string) => {
    updateDashboard(dashboardsUrl, id, name).catch(() => {
      return;
    });
  };

  return (
    <stores.Summary.Context.Provider value={summary}>
      <stores.MetricDateRange.Context.Provider
        value={{ state: metricDateRange, dispatch: dispatchMetricDateRange }}
      >
        <util.Loader loadingState={loading}>
          <div className="flex bg-washed-gray mt4 br3 ba b--black-075">
            <components.Navigation
              createDashboard={createDashboard}
              state={dashboards}
            />
            <Routes>
              <Route path="/" element={<Navigate to="/performance"/>}/>
              <Route
                path="/performance"
                element={<components.PipelinePerformance/>}
              />
              <Route
                path="/frequency"
                element={<components.PipelineFrequency/>}
              />
              <Route
                path="/reliability"
                element={<components.PipelineReliability/>}
              />
              <Route
                path="/settings"
                element={<components.InsightsSettings/>}
              />
              <Route
                path="/custom-dashboards/:id"
                element={
                  <components.CustomDashboards
                    state={dashboards}
                    dispatchDashboard={dispatchDashboards}
                    deleteHandler={deleteDashboardHandler}
                    renameHandler={updateDashboardHandler}
                  />
                }
              />
            </Routes>
          </div>
        </util.Loader>
      </stores.MetricDateRange.Context.Provider>
    </stores.Summary.Context.Provider>
  );
};
