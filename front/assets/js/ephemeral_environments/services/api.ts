import type { AppConfig } from "../contexts/ConfigContext";
import * as types from "../types";

export interface EnvironmentPayload {
  name: string;
  description: string;
  max_instances: number;
  stages?: types.StageConfig[];
  environment_context?: types.EnvironmentContext[];
  accessible_project_ids?: string[];
  ttl_config?: types.TTLConfig | null;
}

export const createEnvironmentAPI = (
  config: AppConfig,
  environmentId?: string
) => {
  const create = async (payload: EnvironmentPayload) => {
    const response = await config.apiUrls.create.call({ body: payload });

    if (response.error) {
      throw new Error(response.error);
    }

    return response.data;
  };

  const update = async (payload: EnvironmentPayload) => {
    if (!environmentId) throw new Error(`Environment ID is required`);

    const response = await config.apiUrls.update
      .replace({ __ID__: environmentId })
      .call({ body: payload });

    if (response.error) {
      throw new Error(response.error);
    }

    return response.data;
  };

  return {
    create,
    update,
  };
};
