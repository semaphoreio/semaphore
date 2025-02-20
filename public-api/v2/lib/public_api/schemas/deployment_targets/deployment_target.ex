defmodule PublicAPI.Schemas.DeploymentTargets.DeploymentTarget do
  @moduledoc """
  Schema for a deployment target

  format:
  apiVersion: (v1)
  kind: DeploymentTarget
  metadata: (id, org_id, project_id, timestamps)*readonly
  spec: duplication of metadata + resource-specific stuff
  """
  use PublicAPI.SpecHelpers.Schema

  use PublicAPI.Schemas.Common.Kind, kind: "DeploymentTarget"
  use PublicAPI.Schemas.DeploymentTargets.DeploymentTarget.ObjectRule, object: "branch"
  use PublicAPI.Schemas.DeploymentTargets.DeploymentTarget.ObjectRule, object: "tag"
  @subject_rules_desc ~s(
  Configure who can trigger a deployment.
  **If left empty all users can trigger a deployment.**
)

  OpenApiSpex.schema(%{
    title: "DeploymentTargets.DeploymentTarget",
    type: :object,
    required: [:apiVersion, :kind, :spec],
    properties: %{
      apiVersion: PublicAPI.Schemas.Common.ApiVersion.schema(),
      kind: ResourceKind.schema(),
      metadata: %Schema{
        type: :object,
        description: "Metadata of the deployment targets, all fields are read only",
        properties: %{
          id: PublicAPI.Schemas.Common.id("DeploymentTarget"),
          project_id: PublicAPI.Schemas.Common.id("Project"),
          org_id: PublicAPI.Schemas.Common.id("Organization"),
          name: PublicAPI.Schemas.DeploymentTargets.Name.schema(),
          created_at: PublicAPI.Schemas.Common.timestamp(),
          updated_at: PublicAPI.Schemas.Common.timestamp(),
          created_by: PublicAPI.Schemas.Common.User.schema(),
          updated_by: PublicAPI.Schemas.Common.User.schema(),
          description: %Schema{
            type: :string,
            description: "Description of the deployment target"
          },
          state: %Schema{
            type: :string,
            enum: ~w(SYNCING USABLE UNUSABLE CORDONED),
            description: "State of the deployment target.
 - `SYNCING` - Deployment Target secret is synchronizing
 - `USABLE` - Deployment Target is active and can be used or modified
 - `UNUSABLE` - Deployment Target is corrupted and cannot be used or modified
 - `CORDONED` - Deployment Target has been cordoned and deactivated
 "
          },
          last_deployment: %OpenApiSpex.Reference{
            "$ref": "#/components/schemas/DeploymentTargets.HistoryItem"
          }
        },
        readOnly: true,
        required: [:id, :name, :project_id]
      },
      spec: %Schema{
        type: :object,
        description: "Specification of the deployment target",
        required: [:name],
        properties: %{
          name: PublicAPI.Schemas.DeploymentTargets.Name.schema(),
          description: %Schema{
            type: :string,
            description: "Description of the deployment target"
          },
          url: %Schema{
            type: :string,
            description: "The URL of the target"
          },
          bookmark_parameters: %Schema{
            type: :array,
            description:
              "The names of the promotion parameters. You can later use values of these parameters to filter deployments in deployment history.",
            minItems: 0,
            maxItems: 3,
            items: %Schema{
              type: :string,
              description: "The name of the promotion parameter"
            }
          },
          subject_rules: %Schema{
            description: @subject_rules_desc,
            type: :object,
            properties: %{
              any: %Schema{
                type: :boolean,
                description:
                  "Allows any user or auto-promotion to trigger a deployment, if true all other rules are ignored and all users can trigger a deployment",
                default: false
              },
              auto: %Schema{
                type: :boolean,
                description: "Allows auto-promotions to be triggered"
              },
              roles: %Schema{
                type: :array,
                description: "The list of roles of users that are allowed to trigger a deployment,
                 by default project roles are `Reader`, `Contributor` and `Admin`, read more [here](https://docs.semaphoreci.com/security/default-roles/#project-roles).
                 Role names are case insensitive.",
                items: %Schema{
                  example: "Contributor",
                  type: :string,
                  description: "The name of the role."
                }
              },
              users: %Schema{
                type: :array,
                description: "The list of users that are allowed to trigger a deployment",
                items: %Schema{
                  anyOf: [
                    %Schema{
                      type: :string,
                      format: :uuid,
                      description: "The uuid of the user"
                    },
                    %Schema{
                      type: :string,
                      description: "The git handle of the user"
                    }
                  ],
                  description: "The git handle or id of the user"
                }
              }
            }
          },
          object_rules: %Schema{
            type: :object,
            description: ~s(Configure which branches, tags or PRs can trigger a deployment.
            **If left empty all branches, tags or PRs can trigger a deployment.**),
            properties: %{
              branches: :ObjectRuleBranch.schema(),
              tags: :ObjectRuleTag.schema(),
              prs: %Schema{
                type: :string,
                enum: ~w(ALL NONE),
                default: "NONE",
                description: ~s(Allows all or none of the PRs to trigger a deployment)
              }
            }
          },
          active: %Schema{
            type: :boolean,
            description:
              "The state of the deployment target, true if the deployment is not cordoned"
          },
          env_vars: %Schema{
            type: :array,
            description:
              "Environment variables of the deployment target, only in create requests.",
            items: %OpenApiSpex.Reference{
              "$ref": "#/components/schemas/Secrets.Secret.EnvVar"
            }
          },
          files: %Schema{
            type: :array,
            description: "Files of the deployment target, only in create requests.",
            items: %OpenApiSpex.Reference{
              "$ref": "#/components/schemas/Secrets.Secret.File"
            }
          }
        }
      }
    }
  })
end
