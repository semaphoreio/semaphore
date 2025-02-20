defmodule PublicAPI.Schemas.Notifications.Notification.Rule.Status do
  @moduledoc """
  Schema for a notification rule status
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "Notifications.Notification.Rule.Status",
    type: :string,
    enum: ["ACTIVE", "INACTIVE"]
  })
end
