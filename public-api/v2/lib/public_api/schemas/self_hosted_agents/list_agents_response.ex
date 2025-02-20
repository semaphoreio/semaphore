defmodule PublicAPI.Schemas.SelfHostedAgents.ListAgentsResponse do
  @moduledoc """
  Schema lising registered self-hosted agents
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "SelfHostedAgents.ListAgentsResponse",
    type: :array,
    items: PublicAPI.Schemas.SelfHostedAgents.Agent.schema()
  })
end
