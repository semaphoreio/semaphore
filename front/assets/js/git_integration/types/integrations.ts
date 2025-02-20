import { IntegrationType } from '../../project_onboarding/new/types/provider';
export { IntegrationType };

interface BaseIntegration {
  type: IntegrationType;
  appName: string;
  description: string;
  deleteUrl: string;
  updateUrl: string;
  connectionStatus: IntegrationStatus;
  manifest: {
    permissions?: string;
    redirect_urls?: string;
    webhookUrl?: string;
    url?: string;
    setupUrl?: string;
    callbackUrl?: string;
  };
}

export interface GithubIntegration extends BaseIntegration {
  type: IntegrationType.GithubApp;
  name: string;
  appId: string;
  clientId: string;
  htmlUrl: string;
  privateKeySignature: string;
}

export interface GitlabIntegration extends BaseIntegration {
  type: IntegrationType.Gitlab;
  connectUrl: string;
}

export interface BitbucketIntegration extends BaseIntegration {
  type: IntegrationType.BitBucket;
  connectUrl: string;
}

export type Integration = GithubIntegration | GitlabIntegration | BitbucketIntegration;

export enum IntegrationStatus {
  Connected = `connected`,
  Disconnected = `disconnected`,
}

export interface NewIntegration {
  name: string;
  description: string;
  setupTime: string;
  type: IntegrationType;
  connectUrl: string;
  manifest: {
    permissions?: string;
    redirect_urls?: string;
  };
  internalSetup: boolean;
}
