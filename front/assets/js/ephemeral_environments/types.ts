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

export interface CreateEnvironmentData {
  name: string;
  description: string;
  max_instances: number;
  provisioning_pipeline?: PipelineConfig;
  deprovisioning_pipeline?: PipelineConfig;
  deployment_pipeline?: PipelineConfig;
  project_access?: ProjectAccess[];
  ephemeral_secrets?: EphemeralSecret[];
}

export interface PipelineConfig {
  project_id: string;
  branch: string;
  pipeline_yaml_name: string;
}

export interface ProjectAccess {
  project_id: string;
  permission: `provision` | `deploy` | `admin`;
}

export interface EphemeralSecret {
  name: string;
  description: string;
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
