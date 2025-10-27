export interface ServiceAccount {
  id: string;
  name: string;
  description: string;
  created_at: string;
  updated_at: string;
  deactivated: boolean;
  roles: Role[];
}

export interface Role {
  id: string;
  name: string;
  source: string;
  color: string;
}

export interface ServiceAccountWithToken extends ServiceAccount {
  api_token: string;
}

export interface Role {
  id: string;
  name: string;
  description: string;
  scope: `organization` | `project`;
}

export interface Permission {
  id: string;
  name: string;
  description: string;
}

export interface PaginatedResponse<T> {
  items: T[];
  totalPages?: number;
}

export interface AppState {
  serviceAccounts: ServiceAccount[];
  loading: boolean;
  error?: string;
  selectedServiceAccount?: ServiceAccount;
  newToken?: string;
  page?: number;
  totalPages?: number;
}

export interface Config {
  organizationId: string;
  projectId?: string;
  isOrgScope: boolean;
  permissions: {
    canView: boolean;
    canManage: boolean;
  };
  roles: Role[];
  urls: {
    list: string;
    create: string;
    export: string;
    update: (id: string) => string;
    delete: (id: string) => string;
    regenerateToken: (id: string) => string;
    assignRole?: string;
  };
}
