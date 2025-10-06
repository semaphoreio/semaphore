import { createContext } from "preact";
import { APIRequest } from "js/toolbox";
import { UserProvider } from "./types";

export interface RawConfig {
  config: string;
}

interface ParsedConfig {
  users: {
    collaborators_url: string;
    create_url: string;
    invite_url: string;
    sync_url: string;
    providers: string[];
  };
}

export class AppConfig {
  collaboratorListUrl: APIRequest.Url<{ collaborators: any }>;
  inviteMemberUrl: APIRequest.Url<{ message: string }>;
  createMemberUrl: APIRequest.Url<{
    password: string;
    message: string;
  }>;

  allowedProviders: UserProvider[] = [];
  baseUrl: string;

  static fromJSON(rawJson: RawConfig): AppConfig {
    const config = AppConfig.default();
    const json: ParsedConfig = JSON.parse(rawJson.config);

    config.collaboratorListUrl = APIRequest.Url.fromJSON(
      json.users.collaborators_url
    );
    config.createMemberUrl = APIRequest.Url.fromJSON(json.users.create_url);
    config.inviteMemberUrl = APIRequest.Url.fromJSON(json.users.invite_url);

    json.users.providers
      .map((provider: string) => {
        switch (provider) {
          case `email`:
            return UserProvider.Email;
          case `github`:
            return UserProvider.GitHub;
          case `bitbucket`:
            return UserProvider.Bitbucket;
          case `gitlab`:
            return UserProvider.GitLab;
          default:
            return null;
        }
      })
      .filter((provider: UserProvider | null) => provider)
      .forEach((provider) => config.allowedProviders.push(provider));

    return config;
  }

  static default(): AppConfig {
    const config = new AppConfig();
    return config;
  }
}

export const Config = createContext<AppConfig>(AppConfig.default());
