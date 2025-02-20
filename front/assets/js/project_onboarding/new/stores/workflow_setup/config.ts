import { createContext } from "preact";
import type { Templates } from "../../types";

export interface AgentType {
  type: string;
  available_os_images: string[];
  platform: string;
  state: `enabled` | `disabled`;
  vcpu: string;
  disk: string;
  ram: string;
}

export interface SelfHostedAgentType {
  type: string;
}

export interface Agents {
  cloud: AgentType[];
  selfHosted: SelfHostedAgentType[];
}

export interface Config {
  baseUrl: string;
  domain: string;
  csrfToken: string;
  stage?: string;
  user?: {
    id: string;
    name: string;
  };
  project?: {
    id: string;
    name: string;
  };
  userProfileUrl?: string;
  templates?: Templates.Template[];
  templatesSetup?: Templates.TemplatesSetup;
  hasPipeline?: boolean;
  agentTypes?: Agents;
  activityRefreshUrl?: string;
  projectUrl?: string;
  updateProjectUrl?: string;
  skipOnboardingUrl?: string;
  commitStarterTemplatesUrl?: string;
  workflowBuilderUrl?: string;
  createSelfHostedAgentUrl?: string;
  checkWorkflowUrl?: string;
}

export interface ConfigContextType {
  state: Config;
}

export const Context = createContext<ConfigContextType>({
  state: {
    baseUrl: ``,
    domain: ``,
    csrfToken: ``,
    projectUrl: ``,
  },
});
