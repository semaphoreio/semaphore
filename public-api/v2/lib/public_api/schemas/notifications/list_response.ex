defmodule PublicAPI.Schemas.Notifications.ListResponse do
  @moduledoc """
  Schema for a notifications list response
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "Notifications.ListResponse",
    type: :array,
    items: PublicAPI.Schemas.Notifications.Notification.schema()
  })
end
