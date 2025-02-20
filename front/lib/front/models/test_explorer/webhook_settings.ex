defmodule Front.Models.TestExplorer.WebhookSettings do
  alias __MODULE__

  defstruct [
    :id,
    :org_id,
    :project_id,
    :webhook_url,
    :branches,
    :enabled,
    :greedy
  ]

  @type t :: %WebhookSettings{
          id: String.t(),
          org_id: String.t(),
          project_id: String.t(),
          webhook_url: String.t(),
          branches: [String.t()],
          enabled: boolean(),
          greedy: boolean()
        }

  def new(params), do: struct(WebhookSettings, params)

  def from_proto(p) do
    %WebhookSettings{
      id: Map.get(p, :id, ""),
      org_id: Map.get(p, :org_id, ""),
      project_id: Map.get(p, :project_id, ""),
      webhook_url: Map.get(p, :webhook_url, ""),
      branches: Map.get(p, :branches, []),
      enabled: Map.get(p, :enabled, false),
      greedy: Map.get(p, :greedy, false)
    }
  end
end
