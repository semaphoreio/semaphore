import * as toolbox from "js/toolbox";
import {
  Config,
  ServiceAccount,
  ServiceAccountWithToken,
  PaginatedResponse,
} from "../types";

export class ServiceAccountsAPI {
  constructor(private config: Config) {}

  async list(
    page?: number
  ): Promise<
    toolbox.APIRequest.ApiResponse<PaginatedResponse<ServiceAccount>>
    > {
    const params = new URLSearchParams();
    if (page) params.append(`page`, `${page}`);

    const response = await toolbox.APIRequest.get<any>(
      `${this.config.urls.list}?${params.toString()}`
    );

    if (response.error) {
      return { data: null, error: response.error, status: response.status };
    }

    // Extract total pages from response
    const totalPages = response.data?.total_pages || null;

    return {
      data: {
        items: response.data?.service_accounts || [],
        totalPages: totalPages,
      },
      error: null,
      status: response.status,
    };
  }

  async create(
    name: string,
    description: string,
    roleId: string
  ): Promise<toolbox.APIRequest.ApiResponse<ServiceAccountWithToken>> {
    return toolbox.APIRequest.post<ServiceAccountWithToken>(
      this.config.urls.create,
      { name, description, role_id: roleId }
    );
  }

  async update(
    id: string,
    name: string,
    description: string,
    role_id: string
  ): Promise<toolbox.APIRequest.ApiResponse<ServiceAccount>> {
    return toolbox.APIRequest.put<ServiceAccount>(this.config.urls.update(id), {
      name,
      description,
      role_id,
    });
  }

  async delete(id: string): Promise<toolbox.APIRequest.ApiResponse<void>> {
    return toolbox.APIRequest.del<void>(this.config.urls.delete(id));
  }

  async regenerateToken(
    id: string
  ): Promise<toolbox.APIRequest.ApiResponse<{ api_token: string, }>> {
    return toolbox.APIRequest.post<{ api_token: string, }>(
      this.config.urls.regenerateToken(id)
    );
  }
}
