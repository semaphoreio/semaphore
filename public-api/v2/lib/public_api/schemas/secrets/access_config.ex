defmodule PublicAPI.Schemas.Secrets.AccessConfig do
  @moduledoc """
  Schema for organization secret access policy configuration
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "Secrets.AccessConfig",
    type: :object,
    description:
      "Access configuration of the secret if the feature is enabled.
    More info: https://docs.semaphoreci.com/essentials/using-secrets/#organization-level-secrets-access-policy",
    properties: %{
      project_access: %Schema{
        type: :string,
        enum: ~w(ALL ALLOWED NONE),
        default: "ALL",
        description: "Field determining if projects can use the secret contents
         - ALL      = all projects can use this secret
         - ALLOWED  = oly projects whitelisted in project_ids will be able to read this secret
         - NONE     = no projects can access contents of the secret"
      },
      project_ids: %Schema{
        type: :array,
        description:
          "List of project ids that can use the secret contents if project_access is set to ALLOWED",
        default: [],
        items: PublicAPI.Schemas.Common.id("Project")
      },
      debug_access: %Schema{
        type: :string,
        enum: ~w(YES NO),
        default: "YES",
        description: "Field determining if secret can be used in debug jobs
         - YES = debug mode is enabled for this secret
         - NO  = debug mode is disabled for this secret"
      },
      attach_access: %Schema{
        type: :string,
        enum: ~w(YES NO),
        default: "YES",
        description: "Field determining if you can attach to a job using this secret
         - YES = attach mode is enabled for this secret
         - NO  = attach mode is disabled for this secret"
      }
    }
  })
end
