export interface PipelinePerformance {
  all: PerformanceMetric[];
  passed: PerformanceMetric[];
  failed: PerformanceMetric[];
}

export interface PerformanceMetric {
  from_date: string;
  to_date: string;
  count: number;
  mean: number;
  min: number;
  max: number;
  std_dev: number;
  p50: number;
  p95: number;
}

export interface PipelineReliability {
  metrics: ReliabilityMetric[];
}

export interface ReliabilityMetric {
  from_date: string;
  to_date: string;
  all_count: number;
  passed_count: number;
  failed_count: number;
}

export interface PipelineFrequency {
  metrics: FrequencyMetric[];
}

export interface FrequencyMetric {
  from_date: string;
  to_date: string;
  count: number;
}

export interface ProjectPerformance {
  mean_time_to_recovery: number;
  last_successful_run_at: number;
}

export interface Summary {
  frequency: PipelineFrequency;
  performance: PipelinePerformance;
  reliability: PipelineReliability;
  project: ProjectPerformance;
}


export interface Branch {
  display_name: string;
  id: string;
}

export interface Dashboards {
  dashboards: Dashboard[];
}

export interface CreateDashboard {
  dashboard: Dashboard;
}

export interface CreateDashboardItem {
  item: DashboardItem;
}

export interface Dashboard {
  id: string;
  name: string;
  project_id: string;
  organization_id: string;
  inserted_at: string;
  updated_at: string;
  items: DashboardItem[];
}

export interface DashboardItem {
  id: string;
  name: string;
  branch_name: string;
  pipeline_file_name: string;
  inserted_at: string;
  updated_at: string;
  settings: DashboardItemSettings;
  notes: string;
}

export interface DashboardItemSettings {
  metric: number;
  goal: string;
}

export interface AvailableDateRanges {
  available_dates: MetricDateRange[];
}

export interface MetricDateRange {
  label: string;
  from: string;
  to: string;
}