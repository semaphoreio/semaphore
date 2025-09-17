import { AppConfig } from "../config";
import {
  EnvironmentType,
  EnvironmentDetails,
  CreateEnvironmentData,
  ListResponse,
} from "../types";
import { Url, ApiResponse } from "js/toolbox/api_request";

export class EphemeralEnvironmentsAPI {
  constructor(private config: AppConfig) {}

  private replaceId<T>(
    apiUrl: { method: string, path: string, },
    id: string
  ): Url<T> {
    const path = apiUrl.path.replace(`__ID__`, id);
    return new Url(apiUrl.method, path);
  }

  async list(): Promise<ApiResponse<ListResponse>> {
    const url = Url.fromJSON<ListResponse>(this.config.apiUrls.list);
    return url.call();
  }

  async get(id: string): Promise<ApiResponse<EnvironmentDetails>> {
    const url = this.replaceId<EnvironmentDetails>(
      this.config.apiUrls.show,
      id
    );
    return url.call();
  }

  async create(
    data: CreateEnvironmentData
  ): Promise<ApiResponse<EnvironmentType>> {
    const url = Url.fromJSON<EnvironmentType>(this.config.apiUrls.create);
    return url.call({
      body: {
        name: data.name,
        description: data.description,
        max_instances: data.max_instances,
      },
    });
  }

  async update(
    id: string,
    data: Partial<CreateEnvironmentData>
  ): Promise<ApiResponse<EnvironmentType>> {
    const url = this.replaceId<EnvironmentType>(this.config.apiUrls.update, id);
    return url.call({
      body: {
        name: data.name,
        description: data.description,
        max_instances: data.max_instances,
        state: `ready`,
      },
    });
  }

  async delete(id: string): Promise<ApiResponse<void>> {
    const url = this.replaceId<void>(this.config.apiUrls.delete, id);
    return url.call();
  }

  async cordon(id: string): Promise<ApiResponse<EnvironmentType>> {
    const url = this.replaceId<EnvironmentType>(this.config.apiUrls.cordon, id);
    return url.call();
  }
}
