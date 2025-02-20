export class AccessProvider {
  permissions: Map<string, boolean> = new Map();

  static fromJSON(json: any): AccessProvider {
    const accessProvider = new AccessProvider();

    for (const permission in json) {
      accessProvider.permissions.set(permission, json[permission] as boolean);
    }

    return accessProvider;
  }

  hasPermission(permission: string): boolean {
    return this.permissions.get(permission) == true || false;
  }

  canManageAgents(): boolean {
    return this.hasPermission(`organization.self_hosted_agents.manage`);
  }

  canSeeAgents(): boolean {
    return this.hasPermission(`organization.self_hosted_agents.view`);
  }

  canSeeOrganization(): boolean {
    return this.hasPermission(`organization.view`);
  }

  canSeeActivityMonitor(): boolean {
    return this.hasPermission(`organization.activity_monitor.view`);
  }
}
