defmodule JobPage.Models.Organization do
  defstruct [:id, :name, :username, :avatar_url]

  def find(id, tracing_headers) do
    case JobPage.Api.Organization.fetch(id, tracing_headers) do
      nil -> nil
      x -> construct(x)
    end
  end

  defp construct(raw) do
    %__MODULE__{
      id: raw.org_id,
      username: raw.org_username,
      name: raw.name,
      avatar_url: raw.avatar_url
    }
  end
end
