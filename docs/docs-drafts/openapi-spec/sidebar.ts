import type { SidebarsConfig } from "@docusaurus/plugin-content-docs";

const sidebar: SidebarsConfig = {
  apisidebar: [
    {
      type: "doc",
      id: "openapi-spec/semaphore-public-api",
    },
    {
      type: "category",
      label: "Projects",
      items: [
        {
          type: "doc",
          id: "openapi-spec/projects-delete",
          label: "Delete a project",
          className: "api-method delete",
        },
        {
          type: "doc",
          id: "openapi-spec/projects-describe",
          label: "Describe a project",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "openapi-spec/projects-update",
          label: "Update a project settings",
          className: "api-method put",
        },
        {
          type: "doc",
          id: "openapi-spec/projects-list",
          label: "List projects",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "openapi-spec/projects-create",
          label: "Create a project",
          className: "api-method post",
        },
      ],
    },
    {
      type: "category",
      label: "Notifications",
      items: [
        {
          type: "doc",
          id: "openapi-spec/notifications-delete",
          label: "Delete a notification",
          className: "api-method delete",
        },
        {
          type: "doc",
          id: "openapi-spec/notifications-describe",
          label: "Describe a notification",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "openapi-spec/notifications-update",
          label: "Update a notification",
          className: "api-method put",
        },
        {
          type: "doc",
          id: "openapi-spec/notifications-list",
          label: "List notifications",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "openapi-spec/notifications-create",
          label: "Create a notification",
          className: "api-method post",
        },
      ],
    },
    {
      type: "category",
      label: "Workflows",
      items: [
        {
          type: "doc",
          id: "openapi-spec/workflows-reschedule",
          label: "Rerun a workflow",
          className: "api-method post",
        },
        {
          type: "doc",
          id: "openapi-spec/workflows-terminate",
          label: "Stopping a workflow",
          className: "api-method post",
        },
        {
          type: "doc",
          id: "openapi-spec/workflows-list",
          label: "List workflows",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "openapi-spec/workflows-schedule",
          label: "Schedule a workflow",
          className: "api-method post",
        },
        {
          type: "doc",
          id: "openapi-spec/workflows-describe",
          label: "Describe a workflow",
          className: "api-method get",
        },
      ],
    },
    {
      type: "category",
      label: "SelfHostedAgentTypes",
      items: [
        {
          type: "doc",
          id: "openapi-spec/self-hosted-agent-types-disable-all",
          label: "Disable agents for an agent type",
          className: "api-method post",
        },
        {
          type: "doc",
          id: "openapi-spec/self-hosted-agent-types-delete",
          label: "Delete self-hosted agent type",
          className: "api-method delete",
        },
        {
          type: "doc",
          id: "openapi-spec/self-hosted-agent-types-describe",
          label: "Describe self-hosted agent type",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "openapi-spec/self-hosted-agent-types-update",
          label: "Update a self-hosted agent type",
          className: "api-method put",
        },
        {
          type: "doc",
          id: "openapi-spec/self-hosted-agent-types-list",
          label: "List self-hosted agent types",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "openapi-spec/self-hosted-agent-types-create",
          label: "Create self-hosted agent type",
          className: "api-method post",
        },
      ],
    },
    {
      type: "category",
      label: "Pipelines",
      items: [
        {
          type: "doc",
          id: "openapi-spec/pipelines-describe",
          label: "Describe a pipeline and blocks within it",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "openapi-spec/pipelines-validate-yaml",
          label: "Validate passed yaml definition against yaml schema.",
          className: "api-method post",
        },
        {
          type: "doc",
          id: "openapi-spec/pipelines-list",
          label: "List pipelines",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "openapi-spec/pipelines-partial-rebuild",
          label: "Rebuild failed blocks of a pipeline",
          className: "api-method post",
        },
        {
          type: "doc",
          id: "openapi-spec/pipelines-describe-topology",
          label: "Describe a pipeline topology",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "openapi-spec/pipelines-terminate",
          label: "Terminate a pipeline",
          className: "api-method post",
        },
      ],
    },
    {
      type: "category",
      label: "DeploymentTargets",
      items: [
        {
          type: "doc",
          id: "openapi-spec/deployment-targets-activate",
          label: "Activate a project deployment targets",
          className: "api-method patch",
        },
        {
          type: "doc",
          id: "openapi-spec/deployment-targets-delete",
          label: "Delete a project deployment targets",
          className: "api-method delete",
        },
        {
          type: "doc",
          id: "openapi-spec/deployment-targets-describe",
          label: "Describe a project deployment targets",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "openapi-spec/deployment-targets-update",
          label: "Update a project deployment target",
          className: "api-method patch",
        },
        {
          type: "doc",
          id: "openapi-spec/deployment-targets-history",
          label: "History of a project deployment target",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "openapi-spec/deployment-targets-list",
          label: "List project deployment targets",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "openapi-spec/deployment-targets-create",
          label: "Create a project deployment targets",
          className: "api-method post",
        },
        {
          type: "doc",
          id: "openapi-spec/deployment-targets-deactivate",
          label: "Deactivate a project deployment targets",
          className: "api-method patch",
        },
      ],
    },
    {
      type: "category",
      label: "SelfHostedAgents",
      items: [
        {
          type: "doc",
          id: "openapi-spec/self-hosted-agents-list",
          label: "List registered self-hosted agents",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "openapi-spec/self-hosted-agents-describe",
          label: "Describe registered self-hosted agent",
          className: "api-method get",
        },
      ],
    },
    {
      type: "category",
      label: "Tasks",
      items: [
        {
          type: "doc",
          id: "openapi-spec/tasks-list",
          label: "List tasks",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "openapi-spec/tasks-create",
          label: "Create a task",
          className: "api-method post",
        },
        {
          type: "doc",
          id: "openapi-spec/tasks-delete",
          label: "Delete a task",
          className: "api-method delete",
        },
        {
          type: "doc",
          id: "openapi-spec/tasks-describe",
          label: "Describe a task",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "openapi-spec/tasks-update",
          label: "Update a task",
          className: "api-method patch",
        },
        {
          type: "doc",
          id: "openapi-spec/tasks-replace",
          label: "Replace a task",
          className: "api-method put",
        },
        {
          type: "doc",
          id: "openapi-spec/tasks-trigger",
          label: "Trigger a task",
          className: "api-method post",
        },
      ],
    },
    {
      type: "category",
      label: "ProjectSecrets",
      items: [
        {
          type: "doc",
          id: "openapi-spec/project-secrets-list",
          label: "List project level secrets",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "openapi-spec/project-secrets-create",
          label: "Create a project secret",
          className: "api-method post",
        },
        {
          type: "doc",
          id: "openapi-spec/project-secrets-delete",
          label: "Delete a project secret",
          className: "api-method delete",
        },
        {
          type: "doc",
          id: "openapi-spec/project-secrets-describe",
          label: "Describe a project scoped secret",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "openapi-spec/project-secrets-update",
          label: "Update a project secret",
          className: "api-method put",
        },
      ],
    },
    {
      type: "category",
      label: "Secrets",
      items: [
        {
          type: "doc",
          id: "openapi-spec/secrets-delete",
          label: "Delete an organization secret",
          className: "api-method delete",
        },
        {
          type: "doc",
          id: "openapi-spec/secrets-describe",
          label: "Describe an organization secret",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "openapi-spec/secrets-update",
          label: "Update an organization secret",
          className: "api-method put",
        },
        {
          type: "doc",
          id: "openapi-spec/secrets-list",
          label: "List organization level secrets",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "openapi-spec/secrets-create",
          label: "Create an organization secret",
          className: "api-method post",
        },
      ],
    },
    {
      type: "category",
      label: "Dashboards",
      items: [
        {
          type: "doc",
          id: "openapi-spec/dashboards-delete",
          label: "Delete a dashboard",
          className: "api-method delete",
        },
        {
          type: "doc",
          id: "openapi-spec/dashboards-describe",
          label: "Describe a dashboard",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "openapi-spec/dashboards-update",
          label: "Update a dashboard",
          className: "api-method put",
        },
        {
          type: "doc",
          id: "openapi-spec/dashboards-list",
          label: "List organization level dashboards",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "openapi-spec/dashboards-create",
          label: "Create a dashboard",
          className: "api-method post",
        },
      ],
    },
  ],
};

export default sidebar.apisidebar;
