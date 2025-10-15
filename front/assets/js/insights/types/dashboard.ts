import type * as types from './index';

export class Dashboards {
  dashboards: Dashboard[];

  constructor() {
    this.dashboards = [];
  }

  static fromJSON(json: types.JSONInterface.Dashboards): Dashboards {
    const dashboards = new Dashboards();
    dashboards.dashboards = json.dashboards.map(Dashboard.fromJSON);
    return dashboards;
  }
}


export class Dashboard {
  id: string;
  name: string;
  projectId: string;
  organization_id: string;
  insertedAt: Date;
  updatedAt: Date;
  items: DashboardItem[];

  static fromJSON(json: types.JSONInterface.Dashboard): Dashboard {
    const dashboard = new Dashboard();
    dashboard.id = json.id;
    dashboard.name = json.name;
    dashboard.projectId = json.project_id;
    dashboard.organization_id = json.organization_id;
    dashboard.insertedAt = new Date(json.inserted_at);
    dashboard.updatedAt = new Date(json.updated_at);
    if (json.items && json.items.length > 0) {
      dashboard.items = json.items.map(DashboardItem.fromJSON);
    } else {
      dashboard.items = [];
    }
    return dashboard;
  }

}


export class DashboardItem {
  id: string;
  name: string;
  branchName: string;
  pipelineFileName: string;
  insertedAt: Date;
  updatedAt: Date;
  settings: DashboardItemSettings;
  notes: string;

  static fromJSON(json: types.JSONInterface.DashboardItem): DashboardItem {
    const dashboardItem = new DashboardItem();
    dashboardItem.id = json.id;
    dashboardItem.name = json.name;
    dashboardItem.branchName = json.branch_name;
    dashboardItem.pipelineFileName = json.pipeline_file_name;
    dashboardItem.insertedAt = new Date(json.inserted_at);
    dashboardItem.updatedAt = new Date(json.updated_at);
    dashboardItem.settings = DashboardItemSettings.fromJSON(json.settings);
    dashboardItem.notes = json.notes;
    return dashboardItem;
  }
}

export class DashboardItemSettings {
  metric: number;
  goal: string;

  static fromJSON(json: types.JSONInterface.DashboardItemSettings): DashboardItemSettings {
    const dashboardItemSettings = new DashboardItemSettings();
    dashboardItemSettings.goal = json.goal;
    dashboardItemSettings.metric = json.metric;
    return dashboardItemSettings;
  }
}