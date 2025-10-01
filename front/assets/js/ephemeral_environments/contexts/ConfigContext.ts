import { createContext } from "preact";
import * as types from "../types";
import { useContext } from "preact/hooks";
import { Url } from "js/toolbox/api_request";

export interface ProjectsListResponse {
  projects: types.Project[];
}

export interface MembersListResponse {
  members: types.Member[];
}

export class AppConfig {
  static fromJSON(json: any): AppConfig {
    const apiUrls = json.api_urls || {};

    return new AppConfig(
      json.can_manage as boolean,
      json.can_view as boolean,
      json.base_path as string,
      json.base_url as string,
      {
        list: Url.fromJSON<types.ListResponse>(apiUrls.list),
        create: Url.fromJSON<types.EnvironmentType>(apiUrls.create),
        show: Url.fromJSON<types.EnvironmentDetails>(apiUrls.show),
        delete: Url.fromJSON<void>(apiUrls.delete),
        cordon: Url.fromJSON<types.EnvironmentType>(apiUrls.cordon),
        update: Url.fromJSON<types.EnvironmentType>(apiUrls.update),
        projectsList: Url.fromJSON<ProjectsListResponse>(apiUrls.projects_list),
        usersList: Url.fromJSON<MembersListResponse>(apiUrls.users_list),
        groupsList: Url.fromJSON<MembersListResponse>(apiUrls.groups_list),
        serviceAccountsList: Url.fromJSON<MembersListResponse>(
          apiUrls.service_accounts_list
        ),
      }
    );
  }

  constructor(
    public canManage: boolean,
    public canView: boolean,
    public basePath: string,
    public baseUrl: string,
    public apiUrls: {
      list: Url<types.ListResponse>;
      create: Url<types.EnvironmentType>;
      show: Url<types.EnvironmentDetails>;
      delete: Url<void>;
      cordon: Url<types.EnvironmentType>;
      update: Url<types.EnvironmentType>;
      projectsList: Url<ProjectsListResponse>;
      usersList: Url<MembersListResponse>;
      groupsList: Url<MembersListResponse>;
      serviceAccountsList: Url<MembersListResponse>;
    }
  ) {}
}

export const ConfigContext = createContext<AppConfig>(null);

export const useConfig = () => {
  const context = useContext(ConfigContext);
  if (!context) {
    throw new Error(`useConfig must be used within an ConfigProvider`);
  }
  return context;
};
