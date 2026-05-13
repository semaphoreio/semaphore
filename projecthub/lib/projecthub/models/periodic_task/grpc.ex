defmodule Projecthub.Models.PeriodicTask.GRPC do
  @moduledoc """
  gRPC client handling new Periodic Task API for PeriodicScheduler
  """

  alias InternalApi.PeriodicScheduler, as: API
  alias API.PeriodicService.Stub, as: Stub

  @doc """
  Lists all tasks for a given project
  """
  @spec list(String.t()) :: {:ok, [API.Periodic.t()]} | {:error, any()}
  def list(project_id) do
    send(
      API.ListRequest.new(
        project_id: project_id,
        page: 1,
        page_size: 500
      )
    )
  end

  @doc """
  Creates or updates a task
  Note: This still uses ApplyRequest for YAML-based task creation
  """
  @spec upsert(String.t(), String.t(), String.t()) :: {:ok, String.t()} | {:error, any()}
  def upsert(yml_definition, organization_id, requester_id) do
    send(
      API.ApplyRequest.new(
        yml_definition: yml_definition,
        organization_id: organization_id,
        requester_id: requester_id
      )
    )
  end

  @doc """
  Deletes a task
  """
  @spec delete(String.t(), String.t()) :: {:ok, String.t()} | {:error, any()}
  def delete(scheduler_id, requester_id) do
    send(
      API.DeleteRequest.new(
        id: scheduler_id,
        requester: requester_id
      )
    )
  end

  @doc """
  Atomically reconciles the set of periodic tasks for a project: every entry in
  `definitions` is upserted, and any existing periodic on the project whose id is
  not in `definitions` is deleted. The remote handler runs the entire reconcile
  inside a single DB transaction — either everything succeeds or nothing is
  changed.
  """
  @spec bulk_upsert_and_prune(String.t(), String.t(), String.t(), [map()]) ::
          {:ok, %{upserted: [String.t()], deleted: [String.t()]}} | {:error, any()}
  def bulk_upsert_and_prune(project_id, organization_id, requester_id, definitions) do
    send(
      API.BulkUpsertAndPruneRequest.new(
        project_id: project_id,
        organization_id: organization_id,
        requester_id: requester_id,
        periodics: Enum.map(definitions, &build_periodic_definition/1)
      )
    )
  end

  defp build_periodic_definition(definition) do
    API.BulkUpsertAndPruneRequest.PeriodicDefinition.new(
      id: Map.get(definition, :id) || "",
      name: Map.get(definition, :name) || "",
      description: Map.get(definition, :description) || "",
      recurring: Map.get(definition, :recurring, true),
      reference: Map.get(definition, :reference) || "",
      at: Map.get(definition, :at) || "",
      pipeline_file: Map.get(definition, :pipeline_file) || "",
      parameters: Enum.map(Map.get(definition, :parameters) || [], &build_parameter/1),
      state: Map.get(definition, :state, :UNCHANGED)
    )
  end

  defp build_parameter(parameter) do
    API.Periodic.Parameter.new(
      name: Map.get(parameter, :name) || "",
      required: Map.get(parameter, :required, false),
      description: Map.get(parameter, :description) || "",
      default_value: Map.get(parameter, :default_value) || "",
      options: Map.get(parameter, :options) || []
    )
  end

  @interceptors [
    Projecthub.Util.GRPC.ClientRequestIdInterceptor,
    {Projecthub.Util.GRPC.ClientLoggerInterceptor, skip_logs_for: ~w(list)},
    Projecthub.Util.GRPC.ClientRunAsyncInterceptor
  ]
  @grpc_timeout 30_000

  defp send(request, meta \\ nil) do
    func = stub_func(request)

    with {:ok, channel} <- GRPC.Stub.connect(grpc_endpoint(), interceptors: @interceptors),
         {:ok, response} <- grpc_send(channel, func, request, meta) do
      parse_response(response.status, request, response)
    end
  end

  defp grpc_send(channel, func, request, meta),
    do: func.(channel, request, grpc_options(meta)),
    after: GRPC.Stub.disconnect(channel)

  defp stub_func(%API.ListRequest{}), do: &Stub.list/3
  defp stub_func(%API.ApplyRequest{}), do: &Stub.apply/3
  defp stub_func(%API.PersistRequest{}), do: &Stub.persist/3
  defp stub_func(%API.DeleteRequest{}), do: &Stub.delete/3
  defp stub_func(%API.BulkUpsertAndPruneRequest{}), do: &Stub.bulk_upsert_and_prune/3

  defp parse_response(%{code: :OK}, _request, %API.ListResponse{} = response),
    do: {:ok, response.periodics}

  defp parse_response(%{code: :OK}, _request, %API.ApplyResponse{} = response),
    do: {:ok, response.id}

  defp parse_response(%{code: :OK}, _request, %API.PersistResponse{} = response),
    do: {:ok, response.periodic.id}

  defp parse_response(%{code: :OK}, %API.DeleteRequest{} = request, _response),
    do: {:ok, request.id}

  defp parse_response(%{code: :OK}, _request, %API.BulkUpsertAndPruneResponse{} = response),
    do: {:ok, %{upserted: Enum.map(response.upserted, & &1.id), deleted: response.deleted_ids}}

  defp parse_response(%{code: code, message: message}, _request, _response)
       when is_atom(code) and is_binary(message),
       do: {:error, GRPC.RPCError.exception(Google.Rpc.Code.value(code), message)}

  defp parse_response(%{code: code, message: message}, _request, _response)
       when is_integer(code) and is_binary(message),
       do: {:error, GRPC.RPCError.exception(code, message)}

  defp grpc_endpoint, do: Application.fetch_env!(:projecthub, :periodic_scheduler_grpc_endpoint)
  defp grpc_options(metadata), do: [timeout: @grpc_timeout, metadata: metadata]
end
