import { createContext } from "preact";
import { Config } from "./types";

export const ConfigContext = createContext<Config>({} as Config);

export class AppConfig {
  static fromJSON(json: any): Config {
    const isOrgScope = !json.project_id;

    return {
      organizationId: json.organization_id,
      projectId: json.project_id,
      isOrgScope,
      permissions: {
        canView: json.permissions?.view || false,
        canManage: json.permissions?.manage || false,
      },
      roles: json.roles || [],
      urls: {
        list: `/service_accounts`,
        create: `/service_accounts`,
        update: (id: string) => `/service_accounts/${id}`,
        delete: (id: string) => `/service_accounts/${id}`,
        regenerateToken: (id: string) =>
          `/service_accounts/${id}/regenerate_token`,
        assignRole: json.assign_role_url,
      },
    };
  }
}
