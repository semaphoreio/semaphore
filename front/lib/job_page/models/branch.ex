defmodule JobPage.Models.Branch do
  defstruct [:id, :name]

  def find(id, tracing_headers) do
    case JobPage.Api.Branch.fetch(id, tracing_headers) do
      nil -> nil
      x -> construct(x)
    end
  end

  defp construct(raw) do
    %__MODULE__{
      id: raw.branch_id,
      name: raw.branch_name
    }
  end
end
