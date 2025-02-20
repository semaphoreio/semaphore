defmodule PublicAPI.Schemas.Notifications.Notification do
  @moduledoc """
  Schema for a notification

  format:
  apiVersion: (v1)
  kind: Notification
  metadata: (id, org_id, project_id, timestamps)*readonly
  spec: duplication of metadata + resource-specific stuff
  """
  use PublicAPI.SpecHelpers.Schema

  use PublicAPI.Schemas.Common.Kind, kind: "Notification"

  OpenApiSpex.schema(%{
    title: "Notifications.Notification",
    type: :object,
    required: [:apiVersion, :kind, :metadata, :spec],
    properties: %{
      apiVersion: PublicAPI.Schemas.Common.ApiVersion.schema(),
      kind: ResourceKind.schema(),
      metadata: %Schema{
        type: :object,
        description: "Metadata of the notification, all fields are read only",
        properties: %{
          id: PublicAPI.Schemas.Common.id("Notification"),
          name: %Schema{
            type: :string,
            description: "Name of the notification"
          },
          org_id: PublicAPI.Schemas.Common.id("Organization"),
          created_at: PublicAPI.Schemas.Common.timestamp(),
          updated_at: %{PublicAPI.Schemas.Common.timestamp() | nullable: true},
          status: PublicAPI.Schemas.Notifications.Notification.Status.schema()
        },
        readOnly: true,
        required: [:id, :name]
      },
      spec: %Schema{
        type: :object,
        description: "Specification of the notification",
        required: [:name],
        properties: %{
          name: %Schema{
            type: :string,
            description: "Name of the notification"
          },
          rules: %Schema{
            type: :array,
            description: "Rules must have at least one element. Maximal number of rules: 20.",
            maxLength: 20,
            minLength: 1,
            items: PublicAPI.Schemas.Notifications.Notification.Rule.schema()
          }
        }
      }
    }
  })
end
