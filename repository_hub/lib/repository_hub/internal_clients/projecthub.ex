defmodule RepositoryHub.ProjecthubClient do
  @moduledoc """
  Wrapper for Projecthub API Calls
  """
  import RepositoryHub.Toolkit
  alias Util.Proto
  alias RepositoryHub.Toolkit

  alias InternalApi.Projecthub.{
    ProjectService,
    ListKeysetRequest,
    DescribeRequest,
    RequestMeta
  }

  @type opts() :: [
          timeout: non_neg_integer()
        ]

  @doc """
  List projects for given organization
  """
  def list_keyset(organization_id, opts) do
    opts = with_defaults(opts, page_token: "", page_size: 50, timeout: 3000)

    channel()
    |> unwrap(fn connection ->
      request = %ListKeysetRequest{
        metadata: %RequestMeta{org_id: organization_id},
        page_size: opts[:page_size] || 50,
        page_token: opts[:page_token] || ""
      }

      opts = Keyword.drop(opts, [:page_size, :page_token])

      try do: ProjectService.Stub.list_keyset(connection, request, opts),
          after: GRPC.Stub.disconnect(connection)
    end)
    |> unwrap(fn response ->
      response
      |> Proto.to_map()
      |> unwrap(fn response ->
        response.metadata.status.code
        |> case do
          :OK ->
            %{projects: response.projects, next_page_token: response.next_page_token}

          code when code in [:NOT_FOUND, :FAILED_PRECONDITION] ->
            error(response.metadata.status.message)

          code ->
            error("Projecthub call to List returned invalid status code: #{inspect(code)}")
        end
      end)
    end)
    |> unwrap_error(fn
      %{message: message} -> error(message)
      message when is_bitstring(message) -> error(message)
      other -> error(inspect(other))
    end)
  end

  @doc """
  Returns owner_id for given project
  """
  @spec describe(project_id :: Ecto.UUID.t(), opts()) ::
          Toolkit.tupled_result(InternalApi.Projecthub.Project.t(), String.t())
  def describe(project_id, opts \\ []) do
    opts = with_defaults(opts, timeout: 3000)

    channel()
    |> unwrap(fn connection ->
      request = %DescribeRequest{id: project_id, metadata: %RequestMeta{}}

      ProjectService.Stub.describe(connection, request, opts)
    end)
    |> unwrap(&extract_project/1)
    |> unwrap_error(fn
      %{message: message} -> error(message)
      message when is_bitstring(message) -> error(message)
      other -> error(inspect(other))
    end)
  end

  defp extract_project(response) do
    response.metadata.status.code
    |> case do
      :OK ->
        response.project

      code when code in [:NOT_FOUND, :FAILED_PRECONDITION] ->
        error(response.metadata.status.message)

      code ->
        error("Projecthub call to Describe returned invalid status code: #{inspect(code)}")
    end
  end

  defp channel do
    Application.fetch_env!(:repository_hub, :projecthub_grpc_server)
    |> GRPC.Stub.connect(
      interceptors: [
        RepositoryHub.Client.RequestIdInterceptor,
        {RepositoryHub.Client.LoggerInterceptor, skip_logs_for: ~w(describe)},
        RepositoryHub.Client.MetricsInterceptor,
        RepositoryHub.Client.RunAsyncInterceptor
      ]
    )
  end
end
