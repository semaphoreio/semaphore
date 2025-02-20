import { Dashboard, DashboardItem } from '../types/dashboard';
import { Metric } from '../types/chart';

export type Action =
  | { type: `SET_STATE`, state: Dashboard[], }
  | { type: `DELETE_DASHBOARD`, id: string, }
  | { type: `ADD_DASHBOARD`, dashboard: Dashboard, }
  | { type: `UPDATE_DASHBOARD_NAME`, id: string, name: string, }
  | { type: `ADD_DASHBOARD_ITEM`, dashboardId: string, item: DashboardItem, }
  | { type: `DELETE_DASHBOARD_ITEM`, dashboardId: string, itemId: string, }
  | { type: `UPDATE_DASHBOARD_ITEM_NAME`, dashboardId: string, itemId: string, name: string, }
  | { type: `UPDATE_DASHBOARD_ITEM_DESCRIPTION`, dashboardId: string, itemId: string, description: string, }
  | { type: `ADD_ITEM_METRICS`, itemId: string, metrics: Metric[], };


export interface State {
  dashboards: Dashboard[];

  metrics: Map<string, Metric[]>;
}


export function Reducer(state: State, action: Action): State {
  switch (action.type) {
    case `SET_STATE`:
      return { ...state, dashboards: action.state };
    case `DELETE_DASHBOARD`:
      state.dashboards = state.dashboards.filter(dashboard => dashboard.id !== action.id);
      return { ...state };
    case `ADD_DASHBOARD`:
      state.dashboards = [...state.dashboards, action.dashboard];
      return { ...state };
    case `UPDATE_DASHBOARD_NAME`:
      state.dashboards = state.dashboards.map(dashboard => {
        if (dashboard.id === action.id) {
          dashboard.name = action.name;
        }
        return dashboard;
      });
      return { ...state };
    case `ADD_DASHBOARD_ITEM`: {
      const dashboard = state.dashboards.find(dashboard => dashboard.id === action.dashboardId);
      if (dashboard) {
        dashboard.items.push(action.item);
      }
      return { ...state };
    }
    case `DELETE_DASHBOARD_ITEM`: { 
      const dashboard = state.dashboards.find(dashboard => dashboard.id === action.dashboardId);
      if (dashboard) {
        dashboard.items = dashboard.items.filter(item => item.id !== action.itemId);
      }
      return { ...state };
    }
    case `UPDATE_DASHBOARD_ITEM_NAME`: {
      const dashboard = state.dashboards.find(dashboard => dashboard.id === action.dashboardId);
      if (dashboard) {
        const item = dashboard.items.find(item => item.id === action.itemId);
        if (item) {
          item.name = action.name;
        }
      }
      return { ...state };
    }
    case `UPDATE_DASHBOARD_ITEM_DESCRIPTION`: {
      const dashboard = state.dashboards.find(dashboard => dashboard.id === action.dashboardId);
      if (dashboard) {
        const item = dashboard.items.find(item => item.id === action.itemId);
        if (item) {
          item.notes = action.description;
        }
      }
      return { ...state };
    }
    case `ADD_ITEM_METRICS`:
      state.metrics.set(action.itemId, action.metrics);
      return { ...state };

    default:
      return state;
  }
}

export const EmptyState: State = {
  dashboards: [],
  metrics: new Map(),
};
