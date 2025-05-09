defmodule PublicAPI.ApiSpec do
  @moduledoc """
  Entrypoint for defining and generating OpenAPI specification for the Public API.
  """
  alias OpenApiSpex.{Info, OpenApi, Server, Components, SecurityScheme, ServerVariable}
  @behaviour OpenApi

  @impl OpenApi
  def spec do
    %OpenApi{
      info: %Info{
        title: "Semaphore Public API",
        version: "v2",
        description: """
        The Semaphore Public API is a RESTful API that allows you to interact with Semaphore CI/CD.
        ## Authorization
        Authorization is done via bearer token. You can obtain a token by visiting your [account settings](https://me.semaphoreci.com/account).

        ## Pagination with link headers
        Each list request supports pagination. List responses include a [link header](https://datatracker.ietf.org/doc/html/rfc5988#section-5) with the pagination URLs.
        Link headers contain next, previous, first relative URLs.
        """
      },
      servers: [
        %Server{
          url: "https://{org_name}.semaphoreci.com/api/v2",
          variables: %{
            org_name: %ServerVariable{
              default: "me",
              description: "Organization name"
            }
          }
        }
      ],
      components: %Components{
        securitySchemes: %{
          "authorization" => %SecurityScheme{
            type: "http",
            scheme: "bearer",
            name: "authorization",
            description:
              "Token that you get from semaphore [account settings](https://me.semaphoreci.com/account)."
          }
        }
      },
      security: [%{"authorization" => []}],
      paths: %{
        "/workflows" =>
          OpenApiSpex.PathItem.from_routes([
            %{verb: :get, plug: PublicAPI.Handlers.Workflows.List, opts: []},
            %{verb: :post, plug: PublicAPI.Handlers.Workflows.Schedule, opts: []}
          ]),
        "/workflows/{wf_id}" =>
          OpenApiSpex.PathItem.from_routes([
            %{verb: :get, plug: PublicAPI.Handlers.Workflows.Describe, opts: []}
          ]),
        "/workflows/{wf_id}/reschedule" =>
          OpenApiSpex.PathItem.from_routes([
            %{verb: :post, plug: PublicAPI.Handlers.Workflows.Reschedule, opts: []}
          ]),
        "/workflows/{wf_id}/terminate" =>
          OpenApiSpex.PathItem.from_routes([
            %{verb: :post, plug: PublicAPI.Handlers.Workflows.Terminate, opts: []}
          ]),
        "/pipelines" =>
          OpenApiSpex.PathItem.from_routes([
            %{verb: :get, plug: PublicAPI.Handlers.Pipelines.List, opts: []}
          ]),
        "/pipelines/{pipeline_id}" =>
          OpenApiSpex.PathItem.from_routes([
            %{verb: :get, plug: PublicAPI.Handlers.Pipelines.Describe, opts: []}
          ]),
        "/pipelines/{pipeline_id}/terminate" =>
          OpenApiSpex.PathItem.from_routes([
            %{verb: :post, plug: PublicAPI.Handlers.Pipelines.Terminate, opts: []}
          ]),
        "/pipelines/{pipeline_id}/describe_topology" =>
          OpenApiSpex.PathItem.from_routes([
            %{verb: :get, plug: PublicAPI.Handlers.Pipelines.DescribeTopology, opts: []}
          ]),
        "/pipelines/{pipeline_id}/partial_rebuild" =>
          OpenApiSpex.PathItem.from_routes([
            %{verb: :post, plug: PublicAPI.Handlers.Pipelines.PartialRebuild, opts: []}
          ]),
        "/projects/{project_id_or_name}/tasks" =>
          OpenApiSpex.PathItem.from_routes([
            %{verb: :get, plug: PublicAPI.Handlers.Tasks.List, opts: []},
            %{verb: :post, plug: PublicAPI.Handlers.Tasks.Create, opts: []}
          ]),
        "/projects/{project_id_or_name}/tasks/{task_id}" =>
          OpenApiSpex.PathItem.from_routes([
            %{verb: :get, plug: PublicAPI.Handlers.Tasks.Describe, opts: []},
            %{verb: :put, plug: PublicAPI.Handlers.Tasks.Replace, opts: []},
            %{verb: :patch, plug: PublicAPI.Handlers.Tasks.Update, opts: []},
            %{verb: :delete, plug: PublicAPI.Handlers.Tasks.Delete, opts: []}
          ]),
        "/projects/{project_id_or_name}/tasks/{task_id}/triggers" =>
          OpenApiSpex.PathItem.from_routes([
            %{verb: :post, plug: PublicAPI.Handlers.Tasks.Trigger, opts: []}
          ]),
        "/yaml" =>
          OpenApiSpex.PathItem.from_routes([
            %{verb: :post, plug: PublicAPI.Handlers.Pipelines.ValidateYaml, opts: []}
          ]),
        "/secrets" =>
          OpenApiSpex.PathItem.from_routes([
            %{verb: :get, plug: PublicAPI.Handlers.Secrets.List, opts: []},
            %{verb: :post, plug: PublicAPI.Handlers.Secrets.Create, opts: []}
          ]),
        "/secrets/{id_or_name}" =>
          OpenApiSpex.PathItem.from_routes([
            %{verb: :get, plug: PublicAPI.Handlers.Secrets.Describe, opts: []},
            %{verb: :delete, plug: PublicAPI.Handlers.Secrets.Delete, opts: []},
            %{verb: :put, plug: PublicAPI.Handlers.Secrets.Update, opts: []}
          ]),
        "/projects/{project_id_or_name}/secrets" =>
          OpenApiSpex.PathItem.from_routes([
            %{verb: :get, plug: PublicAPI.Handlers.ProjectSecrets.List, opts: []},
            %{verb: :post, plug: PublicAPI.Handlers.ProjectSecrets.Create, opts: []}
          ]),
        "/projects/{project_id_or_name}/secrets/{id_or_name}" =>
          OpenApiSpex.PathItem.from_routes([
            %{verb: :get, plug: PublicAPI.Handlers.ProjectSecrets.Describe, opts: []},
            %{verb: :delete, plug: PublicAPI.Handlers.ProjectSecrets.Delete, opts: []},
            %{verb: :put, plug: PublicAPI.Handlers.ProjectSecrets.Update, opts: []}
          ]),
        "/self_hosted_agent_types" =>
          OpenApiSpex.PathItem.from_routes([
            %{verb: :post, plug: PublicAPI.Handlers.SelfHostedAgentTypes.Create, opts: []},
            %{verb: :get, plug: PublicAPI.Handlers.SelfHostedAgentTypes.List, opts: []}
          ]),
        "/self_hosted_agent_types/{agent_type_name}" =>
          OpenApiSpex.PathItem.from_routes([
            %{verb: :get, plug: PublicAPI.Handlers.SelfHostedAgentTypes.Describe, opts: []},
            %{verb: :delete, plug: PublicAPI.Handlers.SelfHostedAgentTypes.Delete, opts: []},
            %{verb: :put, plug: PublicAPI.Handlers.SelfHostedAgentTypes.Update, opts: []}
          ]),
        "/self_hosted_agent_types/{agent_type_name}/disable_all" =>
          OpenApiSpex.PathItem.from_routes([
            %{verb: :post, plug: PublicAPI.Handlers.SelfHostedAgentTypes.DisableAll, opts: []}
          ]),
        "/agents" =>
          OpenApiSpex.PathItem.from_routes([
            %{verb: :get, plug: PublicAPI.Handlers.SelfHostedAgents.List, opts: []}
          ]),
        "/agents/{agent_name}" =>
          OpenApiSpex.PathItem.from_routes([
            %{verb: :get, plug: PublicAPI.Handlers.SelfHostedAgents.Describe, opts: []}
          ]),
        "/notifications" =>
          OpenApiSpex.PathItem.from_routes([
            %{verb: :get, plug: PublicAPI.Handlers.Notifications.List, opts: []},
            %{verb: :post, plug: PublicAPI.Handlers.Notifications.Create, opts: []}
          ]),
        "/notifications/{id_or_name}" =>
          OpenApiSpex.PathItem.from_routes([
            %{verb: :get, plug: PublicAPI.Handlers.Notifications.Describe, opts: []},
            %{verb: :delete, plug: PublicAPI.Handlers.Notifications.Delete, opts: []},
            %{verb: :put, plug: PublicAPI.Handlers.Notifications.Update, opts: []}
          ]),
        "/projects" =>
          OpenApiSpex.PathItem.from_routes([
            %{verb: :get, plug: PublicAPI.Handlers.Projects.List, opts: []},
            %{verb: :post, plug: PublicAPI.Handlers.Projects.Create, opts: []}
          ]),
        "/projects/{project_id_or_name}" =>
          OpenApiSpex.PathItem.from_routes([
            %{verb: :get, plug: PublicAPI.Handlers.Projects.Describe, opts: []},
            %{verb: :put, plug: PublicAPI.Handlers.Projects.Update, opts: []},
            %{verb: :delete, plug: PublicAPI.Handlers.Projects.Delete, opts: []}
          ]),
        "/dashboards" =>
          OpenApiSpex.PathItem.from_routes([
            %{verb: :get, plug: PublicAPI.Handlers.Dashboards.List, opts: []},
            %{verb: :post, plug: PublicAPI.Handlers.Dashboards.Create, opts: []}
          ]),
        "/dashboards/{id_or_name}" =>
          OpenApiSpex.PathItem.from_routes([
            %{verb: :get, plug: PublicAPI.Handlers.Dashboards.Describe, opts: []},
            %{verb: :post, plug: PublicAPI.Handlers.Dashboards.Update, opts: []},
            %{verb: :delete, plug: PublicAPI.Handlers.Dashboards.Delete, opts: []}
          ]),
        "/projects/{project_id_or_name}/deployment_targets" =>
          OpenApiSpex.PathItem.from_routes([
            %{verb: :get, plug: PublicAPI.Handlers.DeploymentTargets.List, opts: []},
            %{verb: :post, plug: PublicAPI.Handlers.DeploymentTargets.Create, opts: []}
          ]),
        "/projects/{project_id_or_name}/deployment_targets/{id_or_name}" =>
          OpenApiSpex.PathItem.from_routes([
            %{verb: :get, plug: PublicAPI.Handlers.DeploymentTargets.Describe, opts: []},
            %{verb: :delete, plug: PublicAPI.Handlers.DeploymentTargets.Delete, opts: []},
            %{verb: :patch, plug: PublicAPI.Handlers.DeploymentTargets.Update, opts: []}
          ]),
        "/projects/{project_id_or_name}/deployment_targets/{id_or_name}/history" =>
          OpenApiSpex.PathItem.from_routes([
            %{verb: :get, plug: PublicAPI.Handlers.DeploymentTargets.History, opts: []}
          ]),
        "/projects/{project_id_or_name}/deployment_targets/{id_or_name}/deactivate" =>
          OpenApiSpex.PathItem.from_routes([
            %{verb: :patch, plug: PublicAPI.Handlers.DeploymentTargets.Cordon, opts: []}
          ]),
        "/projects/{project_id_or_name}/deployment_targets/{id_or_name}/activate" =>
          OpenApiSpex.PathItem.from_routes([
            %{verb: :patch, plug: PublicAPI.Handlers.DeploymentTargets.Uncordon, opts: []}
          ]),
        "/canvases" =>
          OpenApiSpex.PathItem.from_routes([
            %{verb: :post, plug: PublicAPI.Handlers.Canvases.Create, opts: []}
          ]),
        "/canvases/{id_or_name}" =>
          OpenApiSpex.PathItem.from_routes([
            %{verb: :get, plug: PublicAPI.Handlers.Canvases.Describe, opts: []}
          ]),
        "/canvases/{id_or_name}/sources" =>
          OpenApiSpex.PathItem.from_routes([
            %{verb: :get, plug: PublicAPI.Handlers.EventSources.List, opts: []},
            %{verb: :post, plug: PublicAPI.Handlers.EventSources.Create, opts: []}
          ]),
        "/canvases/{canvas_id_or_name}/sources/{id_or_name}" =>
          OpenApiSpex.PathItem.from_routes([
            %{verb: :get, plug: PublicAPI.Handlers.EventSources.Describe, opts: []}
          ]),
        "/canvases/{canvas_id_or_name}/stages" =>
          OpenApiSpex.PathItem.from_routes([
            %{verb: :get, plug: PublicAPI.Handlers.Stages.List, opts: []},
            %{verb: :post, plug: PublicAPI.Handlers.Stages.Create, opts: []}
          ]),
        "/canvases/{canvas_id_or_name}/stages/{id_or_name}" =>
          OpenApiSpex.PathItem.from_routes([
            %{verb: :get, plug: PublicAPI.Handlers.Stages.Describe, opts: []},
            %{verb: :put, plug: PublicAPI.Handlers.Stages.Update, opts: []}
          ]),
        "/canvases/{canvas_id_or_name}/stages/{id_or_name}/events" =>
          OpenApiSpex.PathItem.from_routes([
            %{verb: :get, plug: PublicAPI.Handlers.Stages.ListEvents, opts: []}
          ]),
        "/canvases/{canvas_id_or_name}/stages/{id_or_name}/approve" =>
          OpenApiSpex.PathItem.from_routes([
            %{verb: :patch, plug: PublicAPI.Handlers.Stages.ApproveEvent, opts: []}
          ])
      }
    }
    |> OpenApiSpex.resolve_schema_modules()
    |> OpenApiSpex.add_schemas([
      PublicAPI.Schemas.Secrets.Secret.EnvVar,
      PublicAPI.Schemas.Secrets.Secret.File,
      PublicAPI.Schemas.DeploymentTargets.DeploymentTarget,
      PublicAPI.Schemas.DeploymentTargets.CreateRequest,
      PublicAPI.Schemas.DeploymentTargets.HistoryItem,
      PublicAPI.Schemas.Pipelines.Result,
      PublicAPI.Schemas.Pipelines.Block,
      PublicAPI.Schemas.Secrets.Secret,
      PublicAPI.Schemas.Secrets.AccessConfig,
      PublicAPI.Schemas.SelfHostedAgents.AgentType.NameSettings,
      PublicAPI.Schemas.SelfHostedAgents.AgentTypeListResponse,
      PublicAPI.Schemas.ProjectSecrets.Secret
    ])
  end
end
