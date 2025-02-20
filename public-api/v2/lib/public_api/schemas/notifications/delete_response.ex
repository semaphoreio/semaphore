defmodule PublicAPI.Schemas.Notifications.DeleteResponse do
  @moduledoc """
  Schema for delete action response
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    type: :object,
    title: "Notifications.DeleteResponse",
    properties: %{
      id: PublicAPI.Schemas.Common.id("Notification")
    }
  })
end
