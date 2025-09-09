import { createContext } from "preact";

interface ApiUrl {
  method: string;
  path: string;
}

export class AppConfig {
  static fromJSON(json: any): AppConfig {
    return new AppConfig(
      json.can_manage as boolean,
      json.can_view as boolean,
      [],
      json.base_path as string,
      json.base_url as string,
      json.api_urls as {
        list: ApiUrl;
        create: ApiUrl;
        show: ApiUrl;
        update: ApiUrl;
        delete: ApiUrl;
        cordon: ApiUrl;
      }
    );
  }

  constructor(
    public canManage: boolean,
    public canView: boolean,
    public projects: Array<{ id: string, name: string, }>,
    public basePath: string,
    public baseUrl: string,
    public apiUrls: {
      list: ApiUrl;
      create: ApiUrl;
      show: ApiUrl;
      update: ApiUrl;
      delete: ApiUrl;
      cordon: ApiUrl;
    }
  ) {}
}

export const ConfigContext = createContext<AppConfig>(null);
