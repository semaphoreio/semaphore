defmodule JobPage.Models.User do
  defstruct [:id, :name, :avatar_url, :url]

  @spec find(String.t()) :: JobPage.Models.User | nil
  def find(id) do
    case JobPage.Api.User.fetch(id) do
      nil -> nil
      x -> construct(x)
    end
  end

  def construct(raw) do
    %__MODULE__{
      name: raw.name,
      avatar_url: raw.avatar_url,
      url: "me.#{Application.get_env(:front, :domain)}"
    }
  end
end
