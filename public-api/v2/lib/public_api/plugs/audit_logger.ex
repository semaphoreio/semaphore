defmodule PublicAPI.Plugs.AuditLogger do
  @behaviour Plug
  @moduledoc """
  Plug for submitting audit logs with JSON logs
  Plug has to be placed before the handler plug

  fields that are logged:
  - operation_id: operation id defined by OpenAPI spec
  - permissions: permissions that were checked before performing the operation
  - authorized: boolean indicating if the request was authorized
  - user_id: user id from the request header
  - org_id: organization id from the request header
  - project_id: project id from either the request or resolved from `pipeline_id` or `project_name`
  - user_agent: user agent from the request header
  - response: contains the error message if the response is an error, otherwise empty
  - metadata: contains request parameters
  """

  alias Plug.Conn
  import PublicAPI.Util.PlugContextHelper
  require Logger

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, opts) do
    operation =
      if Keyword.has_key?(opts, :operation_id) do
        Keyword.get(opts, :operation_id)
      else
        "unknown"
      end

    log = %{
      type: "AuditLog",
      operation: operation,
      ip: ip(conn),
      metadata: metadata(conn)
    }

    Conn.register_before_send(conn, fn conn ->
      log
      |> Map.merge(%{
        permissions: conn.assigns[:permissions],
        authorized_permissions: conn.assigns[:authorized],
        authorized_project: conn.assigns[:authorized_project],
        project_id: conn.assigns[:project_id],
        user_id: conn.assigns[:user_id],
        org_id: conn.assigns[:organization_id],
        user_agent: conn.assigns[:user_agent],
        response: response_err(conn)
      })
      |> Logger.info()

      conn
    end)
  end

  # a map containing any potentially useful metadata
  defp metadata(conn) do
    req_params =
      conn.params
      |> Map.take(~w[wf_id pipeline_id task_id id_or_name agent_type_name agent_name]a)

    req_body_params = request_body_metadata(conn)

    %{request_params: req_params, request_body: req_body_params}
    |> Enum.reject(fn {_, v} -> v == nil end)
  end

  defp request_body_metadata(conn) do
    case conn.body_params do
      nil -> nil
      body_params -> body_params(body_params)
    end
  end

  defp body_params(%{kind: kind, spec: spec})
       when kind not in ~w(Secret ProjectSecret DeploymentTarget) do
    spec
  end

  defp body_params(%{kind: kind, spec: spec}) when kind in ~w(Secret ProjectSecret) do
    data = redact_secret(spec |> Map.get(:data))
    access_config = spec |> Map.get(:access_config)

    %{
      name: spec.name,
      data: data,
      access_config: access_config
    }
  end

  defp body_params(%{kind: "DeploymentTarget", spec: spec}) do
    secret_data = redact_secret(spec)

    Map.merge(spec, secret_data)
  end

  defp body_params(body_params), do: body_params

  defp response_err(conn), do: conn |> get_resource() |> response_metadata()
  defp response_metadata(nil), do: nil
  defp response_metadata({:ok, _response}), do: nil

  defp response_metadata({:error, error}), do: error

  defp redact_secret(spec) do
    env_vars = spec |> Map.get(:env_vars) |> Enum.map(& &1.name)
    files = spec |> Map.get(:files) |> Enum.map(& &1.path)
    %{env_vars: env_vars, files: files}
  end

  defp ip(conn) do
    case conn.remote_ip do
      {:ok, ip} -> ip
      _ -> "unknown"
    end
  end
end
