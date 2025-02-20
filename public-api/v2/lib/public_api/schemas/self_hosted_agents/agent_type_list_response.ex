defmodule PublicAPI.Schemas.SelfHostedAgents.AgentTypeListResponse do
  @moduledoc """
  Schema for a secret list response
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "SelfHostedAgents.AgentTypeListResponse",
    type: :array,
    items: PublicAPI.Schemas.SelfHostedAgents.AgentType.schema()
  })
end
