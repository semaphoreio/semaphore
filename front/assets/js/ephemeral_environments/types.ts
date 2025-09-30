export interface EnvironmentType {
  id: string;
  org_id: string;
  name: string;
  description: string;
  created_by: string;
  last_updated_by: string;
  created_at: string;
  updated_at: string;
  state: `draft` | `ready` | `cordoned` | `deleted`;
  max_number_of_instances: number;
}

export interface EnvironmentInstance {
  id: string;
  ee_type_id: string;
  name: string;
  url?: string;
  state: InstanceState;
  last_state_change_id?: string;
  created_at: string;
  updated_at: string;
  provisioned_at?: string;
  last_deployed?: string;
  deployed_by?: string;
}

export type InstanceState =
  | `unspecified`
  | `zero_state`
  | `provisioning`
  | `ready_to_use`
  | `sleep`
  | `in_use`
  | `deploying`
  | `deprovisioning`
  | `destroyed`
  | `acknowledged_cleanup`
  | `failed_provisioning`
  | `failed_deprovisioning`
  | `failed_deployment`
  | `failed_cleanup`
  | `failed_sleep`
  | `failed_wake_up`;

export interface EnvironmentDetails extends EnvironmentType {
  instances: EnvironmentInstance[];
  pending_count: number;
  running_count: number;
  failed_count: number;
}

export type RBACSubjectType = `user` | `group` | `service_account`;

export interface RBACSubject {
  type: RBACSubjectType;
  id: string;
  name?: string;
}

export interface StageConfig {
  id: string;
  name: string;
  description?: string;
  pipeline?: PipelineConfig;
  parameters?: EnvironmentParameter[];
  rbacAccess?: RBACSubject[];
}

export interface TTLConfig {
  default_ttl_hours: number | null; // null means never expire
  allow_extension: boolean;
}

export interface CreateEnvironmentData {
  name: string;
  description: string;
  max_instances: number;
  provisioning_stage?: StageConfig;
  deployment_stage?: StageConfig;
  deprovisioning_stage?: StageConfig;
  environment_context?: EnvironmentContext[];
  project_access?: ProjectAccess[];
  ttl_config?: TTLConfig;
}

export interface PipelineConfig {
  projectId: string;
  branch: string;
  pipelineYamlFile: string;
}

export interface ProjectAccess {
  projectId: string;
}

export interface GroupAccess {
  group_id: string;
}

export interface EnvironmentContext {
  name: string;
  description: string;
}

export interface EnvironmentParameter {
  name: string;
  description?: string;
  required?: boolean;
}

export interface ListResponse {
  environment_types: EnvironmentType[];
}

export interface InstanceCounts {
  pending: number;
  running: number;
  failed: number;
  total: number;
}

export interface Project {
  id: string;
  name: string;
  description?: string;
}

export interface ProjectSelectOption {
  value: string;
  label: string;
  description?: string;
}

export interface Group {
  id: string;
  name: string;
}

export interface Member {
  id: string;
  name: string;
}
