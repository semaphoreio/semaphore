defmodule FrontWeb.SecretsView do
  use FrontWeb, :view

  def secret_name(nil), do: "[SECRET NAME]"
  def secret_name(secret), do: secret.name

  def project_options(selected, projects) do
    available_projects = MapSet.new(projects, &%{value: &1.id, key: &1.name})
    name_mapper = Map.new(available_projects, fn x -> {x.value, x.key} end)

    selected_projects =
      selected
      |> Enum.map(fn id -> %{key: Map.get(name_mapper, id, "deleted-project"), value: id} end)
      |> MapSet.new()

    stale_projects = MapSet.difference(selected_projects, available_projects)

    fresh_options = Enum.into(available_projects, [], &to_fresh_option/1)
    stale_options = Enum.into(stale_projects, [], &to_stale_option/1)
    fresh_options ++ stale_options
  end

  defp to_fresh_option(value), do: to_fresh_option(value.key, value.value)
  defp to_fresh_option(key, value), do: [key: key, value: value]

  defp to_stale_option(value), do: to_stale_option(value.key, value.value)
  defp to_stale_option(key, value), do: [key: key, value: value, disabled: true]

  def opt_name(name) when name in [:JOB_DEBUG_YES, :JOB_ATTACH_YES], do: "Yes"
  def opt_name(name) when name in [:JOB_DEBUG_NO, :JOB_ATTACH_NO], do: "No"
  def opt_name(:ALL), do: "All"
  def opt_name(:NONE), do: "None"
  def opt_name(:ALLOWED), do: "Whitelisted"
end
