import * as toolbox from "js/toolbox";

export class Agent {
  arch: string;
  connectedAt: Date;
  disabled: boolean;
  disabledAt: Date;
  hostname: string;
  ipAddress: string;
  name: string;
  os: string;
  pid: number;
  state: number;
  typeName: string;
  userAgent: string;
  version: string;

  static fromJSON(json: any): Agent {
    const agent = new Agent();
    agent.name = json.name;
    agent.arch = json.arch;
    agent.ipAddress = json.ip_address;
    agent.os = json.os;
    agent.pid = json.pid;
    agent.state = json.state;
    agent.typeName = json.type_name;
    agent.userAgent = json.user_agent;
    agent.version = json.version;
    agent.connectedAt = new Date(json.connected_at?.seconds * 1000);
    agent.disabled = json.disabled;
    agent.disabledAt = new Date(json.disabled_at?.seconds * 1000);
    return agent;
  }
}

export type AssignmentOrigin =
  | `ASSIGNMENT_ORIGIN_AWS_STS`
  | `ASSIGNMENT_ORIGIN_AGENT`;

export class AgentNameSetting {
  assignmentOrigin: AssignmentOrigin = `ASSIGNMENT_ORIGIN_AGENT`;
  nameReleaseAfter = 0;
  awsAccount: string;
  awsRolePatterns: string;
  nameSuffix: string;

  static fromJSON(json: any): AgentNameSetting {
    const setting = new AgentNameSetting();
    setting.assignmentOrigin = json.agent_name_assignment_origin;
    setting.nameReleaseAfter = json.agent_name_release_after;
    setting.awsAccount = json.aws_account || ``;
    setting.awsRolePatterns = json.aws_role_patterns || ``;
    setting.nameSuffix = json.name_suffix || ``;

    return setting;
  }

  isNameReleasedImmediately(): boolean {
    return this.nameReleaseAfter === 0;
  }

  isAwsConfigRequired(): boolean {
    return this.assignmentOrigin === `ASSIGNMENT_ORIGIN_AWS_STS`;
  }
}

export class AgentType {
  name: string;
  createdAt: Date;
  updatedAt: Date;
  settings: AgentNameSetting;

  totalAgentCount = 0;
  organizationId = ``;
  requesterId = ``;
  token = ``;
  agents: Agent[] = [];

  constructor(nameSuffix: string) {
    this.organizationId = ``;
    this.requesterId = ``;
    this.createdAt = new Date();
    this.updatedAt = new Date();
    this.settings = new AgentNameSetting();
    this.settings.nameSuffix = nameSuffix;
    this.name = `s1-${nameSuffix}`;
  }

  static fromJSON(json: any): AgentType {
    const agent = new AgentType(``);
    agent.name = json.name;
    agent.organizationId = json.organization_id;
    agent.requesterId = json.requester_id;
    agent.totalAgentCount = json.total_agent_count;
    agent.createdAt = new Date(json.created_at as string);
    agent.updatedAt = new Date(json.updated_at as string);
    agent.settings = AgentNameSetting.fromJSON(json.settings);

    return agent;
  }

  static async get(url: string, name: string): Promise<AgentType> {
    return toolbox.APIRequest.get(`${url}/${name}?format=json`).then((res) => {
      if (res.error) {
        throw res.error;
      }
      const { agent_type, agents } = res.data as any;

      const agentType = AgentType.fromJSON(agent_type);
      agentType.agents = agents.map(Agent.fromJSON);
      return agentType;
    });
  }

  async create(url: string): Promise<AgentType> {
    const request = {
      name: this.name,
    };

    return toolbox.APIRequest.post(`${url}?format=json`, request).then(
      (res) => {
        if (res.error) {
          throw res.error;
        }
        const { agent_type, token } = res.data as any;

        const agentType = AgentType.fromJSON(agent_type);
        agentType.token = token;
        return agentType;
      },
    );
  }

  async delete(url: string): Promise<void> {
    return toolbox.APIRequest.del(`${url}/${this.name}?format=json`).then(
      (res) => {
        if (res.error) {
          throw res.error;
        }
      },
    );
  }

  async update(url: string): Promise<AgentType> {
    const request = {
      self_hosted_agent: {
        agent_name_assignment_origin: this.settings.assignmentOrigin,
        agent_name_release_after: `${this.settings.nameReleaseAfter}`,
        aws_account: this.settings.awsAccount,
        aws_role_patterns: this.settings.awsRolePatterns,
      },
    };

    return toolbox.APIRequest.put(
      `${url}/${this.name}?format=json`,
      request,
    ).then((res) => {
      if (res.error) {
        throw res.error;
      }
      const { agent_type } = res.data as any;

      const agentType = AgentType.fromJSON(agent_type);
      return agentType;
    });
  }

  async disableAllAgents(url: string, onlyIdle: boolean): Promise<string> {
    const request = {
      only_idle_agents: onlyIdle ? `true` : `false`,
    };

    return toolbox.APIRequest.post(
      `${url}/${this.name}/disable_all_agents?format=json`,
      request,
    ).then((res) => {
      if (res.error) {
        throw res.error;
      }
      const message = (res.data as any).message as string;

      return message;
    });
  }

  async resetToken(
    url: string,
    disconnectRunningAgents: boolean,
  ): Promise<string> {
    const request = {
      disconnect_running_agents: disconnectRunningAgents ? `true` : `false`,
    };
    return toolbox.APIRequest.post(
      `${url}/${this.name}/reset_token?format=json`,
      request,
    ).then((res) => {
      if (res.error) {
        throw res.error;
      }
      const token = (res.data as any).token as string;

      return token;
    });
  }
}

export default {
  Agent,
  AgentType,
};
