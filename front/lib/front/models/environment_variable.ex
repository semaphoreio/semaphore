defmodule Front.Models.EnvironmentVariable do
  defstruct [:name, :value, :md5]

  def construct_list(nil), do: []

  def construct_list(data) do
    data.env_vars
    |> Enum.map(fn var ->
      %__MODULE__{
        name: var.name,
        value: var.value,
        md5: value_md5(var.value)
      }
    end)
  end

  def serialize_for_frontend(env_var) do
    %{name: env_var.name, md5: env_var.md5}
  end

  defp value_md5(value) do
    :erlang.md5(value)
    |> Base.encode16(case: :lower)
  end
end
