defmodule PublicAPI.Schemas.Notifications.Notification.Status do
  @moduledoc """
  Schema for a notification failures
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "Notifications.Notification.Status",
    type: :object,
    required: [],
    properties: %{
      failures: %Schema{
        type: :array,
        description: "A failure contains a timestamp and a description of a failure",
        items: %Schema{
          type: :object,
          properties: %{
            timestamp: PublicAPI.Schemas.Common.timestamp(),
            description: %Schema{
              type: :string,
              description: "Description of the failure"
            }
          }
        }
      }
    }
  })
end
