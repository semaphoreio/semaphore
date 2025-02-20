defmodule Front.Form.SecretParamsHelper do
  def parse_env_vars(params) do
    if params["env_vars"] do
      params["env_vars"]
      |> Enum.map(fn {_k, v} -> v end)
    else
      []
    end
  end

  def parse_files(params) do
    if params["files"] do
      params["files"]
      |> Enum.map(fn {_k, v} -> v end)
    else
      []
    end
  end

  def parse_env_vars_and_files(params) do
    env_vars =
      if params["env_vars"] do
        params["env_vars"]
        |> Enum.map(fn {_k, v} -> v end)
        |> Enum.reject(fn map ->
          map["name"] == "" || map["value"] == ""
        end)
      else
        []
      end

    files =
      if params["files"] do
        params["files"]
        |> Enum.map(fn {_k, v} -> v end)
        |> Enum.reject(fn map ->
          map["path"] == "" || map["content"] == ""
        end)
      else
        []
      end

    %{
      env_vars: env_vars,
      files: files
    }
  end

  def parse_params(params) do
    parse_env_vars_and_files(params)
    |> Map.merge(%{description: params["description"] || ""})
  end

  def parse_org_config(_new_params, permission) when permission in [false, nil], do: nil

  def parse_org_config(new_params, true) do
    if Map.has_key?(new_params, "projects_access") or Map.has_key?(new_params, "attach_access") do
      Map.take(new_params, ~w(projects_access attach_access debug_access))
      |> Map.new(fn {k, v} -> {String.to_existing_atom(k), String.to_existing_atom(v)} end)
      |> Map.put(:project_ids, Map.get(new_params, "projects", []))
    else
      %{
        projects_access: :ALL,
        project_ids: [],
        debug_access: :JOB_DEBUG_YES,
        attach_access: :JOB_ATTACH_YES
      }
    end
  end

  def construct_empty_inputs do
    %{
      env_vars: [],
      files: [],
      id: "",
      name: "",
      description: "",
      org_config: %{
        projects_access: :ALL,
        project_ids: [],
        debug_access: :JOB_DEBUG_YES,
        attach_access: :JOB_ATTACH_YES
      }
    }
  end
end
