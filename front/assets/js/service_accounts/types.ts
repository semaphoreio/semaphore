export interface ServiceAccount {
  id: string;
  name: string;
  description: string;
  created_at: string;
  updated_at: string;
  deactivated: boolean;
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

// Using toolbox.APIRequest.ApiResponse instead of custom type

export interface PaginatedResponse<T> {
  items: T[];
  next_page_token?: string;
}

export enum ModalState {
  Closed,
  Open,
  Loading,
  Success,
  Error
}

export interface AppState {
  serviceAccounts: ServiceAccount[];
  loading: boolean;
  error: string | null;
  selectedServiceAccount: ServiceAccount | null;
  modalState: ModalState;
  newToken: string | null;
  nextPageToken: string | null;
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
    update: (id: string) => string;
    delete: (id: string) => string;
    regenerateToken: (id: string) => string;
    assignRole?: string;
  };
}