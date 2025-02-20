defmodule PipelinesAPI.Deployments.Secrets do
  @moduledoc """
  Utility functions needed to handle deployment targets operations, like getting project ID
  from the connection, process response, encode data, etc.
  """

  use Plug.Builder

  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.Validator

  alias PipelinesAPI.Deployments.Authorize
  alias PipelinesAPI.SecretClient
  alias Util.ToTuple

  def describe_targets_secrets(response = %{id: _target_id}, conn) do
    Metrics.benchmark("PipelinesAPI.deployments.secrets", ["describe_target_secrets"], fn ->
      if is_true(Map.get(conn.params, "include_secrets", false)) do
        describe_targets_secrets_(response, conn)
      else
        {:ok, response}
      end
    end)
  end

  def describe_targets_secrets({:ok, target = %{id: _target_id}}, conn),
    do: describe_targets_secrets(target, conn)

  def describe_targets_secrets(response, _conn), do: response

  defp describe_targets_secrets_(response = %{id: target_id}, conn, hash_secrets? \\ true) do
    with conn <- Authorize.authorize_manage_project(conn, []),
         {:ok, %{env_vars: env_vars, files: files}} <-
           SecretClient.describe(%{"target_id" => target_id}, conn) do
      response
      |> Map.put(:env_vars, if(hash_secrets?, do: hash_env_vars(env_vars), else: env_vars))
      |> Map.put(:files, if(hash_secrets?, do: hash_files(files), else: files))
      |> ToTuple.ok()
    else
      err -> err
    end
  end

  def inject_old_secrets(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.deployments.secrets", ["inject_old_secrets"], fn ->
      do_inject_old_secrets(conn)
    end)
  end

  def do_inject_old_secrets(conn = %{params: %{"target_id" => target_id}}),
    do: inject_old_secrets_(target_id, conn)

  def do_inject_old_secrets(conn = %{params: %{"id" => target_id}}),
    do: inject_old_secrets_(target_id, conn)

  def inject_old_secrets_(target_id, conn) do
    if Map.has_key?(conn.params, "env_vars") or Map.has_key?(conn.params, "files") do
      case describe_targets_secrets_(%{id: target_id}, conn, false) do
        {:ok, %{env_vars: env_vars, files: files}} ->
          Map.put(
            conn,
            :params,
            conn.params
            |> Map.put("old_env_vars", value_or_empty(env_vars))
            |> Map.put("old_files", value_or_empty(files))
          )

        {:error, {:not_found, message}} ->
          conn |> put_resp_content_type("text/plain") |> resp(404, message) |> halt

        _ ->
          conn |> put_resp_content_type("text/plain") |> resp(500, "internal error") |> halt
      end
    else
      conn
    end
  end

  defp hash_env_vars(env_vars) when is_list(env_vars) do
    Enum.into(
      env_vars,
      [],
      &%{name: &1.name, value: Validator.hide_secret(&1.value)}
    )
  end

  defp hash_env_vars(_), do: []

  defp hash_files(files) when is_list(files) do
    Enum.into(
      files,
      [],
      &%{path: &1.path, content: Validator.hide_secret(&1.content)}
    )
  end

  defp hash_files(_), do: []

  defp is_true(v) when is_atom(v), do: v
  defp is_true(v) when is_binary(v), do: String.downcase(v) in ["true", "yes"]
  defp is_true(_v), do: false

  defp value_or_empty(value), do: if(value == nil, do: [], else: value)
end
