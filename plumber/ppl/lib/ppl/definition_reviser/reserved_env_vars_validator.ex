defmodule Ppl.DefinitionReviser.ReservedEnvVarsValidator do
  @moduledoc """
  Rejects pipelines whose definition or request parameters set env vars whose names
  are not valid shell identifiers, are supplied by the platform, or are read by bash
  at startup (BASH_ENV, SHELLOPTS).
  """

  require Logger

  alias Util.ToTuple

  @reserved_prefix "Reserved environment variables cannot be set: "
  @invalid_prefix "Invalid environment variable names: "
  @max_listed 20

  def validate(definition, ppl_req) do
    names = Enum.uniq(definition_names(definition) ++ parameter_names(ppl_req))

    with :ok <- check(names, ppl_req), do: ToTuple.ok(definition)
  end

  @doc """
  Checks only the request parameters, for paths that run jobs before the
  definition is revised, such as the initialization job.
  """
  def validate_parameters(ppl_req),
    do: ppl_req |> parameter_names() |> Enum.uniq() |> check(ppl_req)

  defp check(names, ppl_req) do
    case Enum.reject(names, &valid_entry?/1) do
      [] ->
        names
        |> Enum.filter(fn {name, _location, _rule} -> EnvVarPolicy.reserved?(name) end)
        |> result(:reserved, ppl_req)

      invalid ->
        result(invalid, :invalid, ppl_req)
    end
  end

  defp valid_entry?({name, _location, :container}), do: EnvVarPolicy.valid_container_name?(name)
  defp valid_entry?({name, _location, :shell}), do: EnvVarPolicy.valid_name?(name)

  defp result([], _kind, _ppl_req), do: :ok

  defp result(violations, kind, ppl_req) do
    report(violations, kind, ppl_req)
    entries = Enum.map(violations, fn {name, location, _rule} -> entry(kind, name, location) end)
    {:error, {:malformed, prefix(kind) <> join(entries)}}
  end

  defp entry(:reserved, name, location), do: "#{display(name)} (#{location})"
  defp entry(:invalid, name, location), do: "'#{display(name)}' (#{location})"

  defp prefix(:reserved), do: @reserved_prefix
  defp prefix(:invalid), do: @invalid_prefix

  defp report(violations, kind, ppl_req) do
    Watchman.increment({"ppl.reserved_env_vars.rejected", [kind]})

    names =
      violations |> Enum.map(fn {name, _location, _rule} -> display(name) end) |> Enum.uniq()

    request_args = Map.get(ppl_req, :request_args) || %{}

    Logger.warning(
      "Env vars rejected kind=#{kind} ppl_id=#{Map.get(ppl_req, :id)} " <>
        "org_id=#{request_args["organization_id"]} names=#{inspect(names)}"
    )
  end

  defp join(entries) when length(entries) <= @max_listed,
    do: Enum.join(entries, ", ")

  defp join(entries) do
    listed = entries |> Enum.take(@max_listed) |> Enum.join(", ")
    listed <> " and #{length(entries) - @max_listed} more"
  end

  defp definition_names(definition) do
    env_var_names(get_in(definition, ["global_job_config", "env_vars"]), "global_job_config") ++
      container_names(get_in(definition, ["agent", "containers"]), "agent") ++
      promotion_names(definition["promotions"]) ++
      block_names(definition["blocks"], nil) ++
      block_names(definition["after_pipeline"], "after_pipeline")
  end

  defp parameter_names(%{request_args: %{"env_vars" => env_vars}}),
    do: env_var_names(env_vars, "parameters")

  defp parameter_names(_ppl_req), do: []

  defp promotion_names(promotions) when is_list(promotions) do
    Enum.flat_map(promotions, fn promotion ->
      env_var_names(
        get_in(promotion, ["parameters", "env_vars"]),
        "promotion '#{display(promotion["name"])}' parameters"
      )
    end)
  end

  defp promotion_names(_promotions), do: []

  defp block_names(blocks, default_name) when is_list(blocks) do
    Enum.flat_map(blocks, fn block ->
      block_label = "block '#{display(block["name"] || default_name)}'"
      build = block["build"] || %{}

      env_var_names(build["env_vars"], block_label) ++
        container_names(get_in(build, ["agent", "containers"]), block_label) ++
        job_names(build["jobs"], block_label)
    end)
  end

  defp block_names(_blocks, _default_name), do: []

  defp job_names(jobs, block_label) when is_list(jobs) do
    Enum.flat_map(jobs, fn job ->
      job_label = "#{block_label}, job '#{display(job["name"])}'"

      env_var_names(job["env_vars"], job_label) ++
        matrix_names(job["matrix"], "#{job_label} matrix")
    end)
  end

  defp job_names(_jobs, _block_label), do: []

  defp container_names(containers, label) when is_list(containers) do
    Enum.flat_map(containers, fn container ->
      env_var_names(
        container["env_vars"],
        "#{label} container '#{display(container["name"])}'",
        :container
      )
    end)
  end

  defp container_names(_containers, _label), do: []

  defp matrix_names(matrix, label) when is_list(matrix) do
    for %{"env_var" => name} <- matrix, do: {name, label, :shell}
  end

  defp matrix_names(_matrix, _label), do: []

  defp env_var_names(env_vars, label, rule \\ :shell)

  defp env_var_names(env_vars, label, rule) when is_list(env_vars) do
    for %{"name" => name} <- env_vars, do: {name, label, rule}
  end

  defp env_var_names(_env_vars, _label, _rule), do: []

  defp display(text) when is_binary(text), do: EnvVarPolicy.clip(text)

  defp display(nil), do: ""
  defp display(other), do: other |> inspect() |> display()
end
