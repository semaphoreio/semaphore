defmodule PreFlightChecks.GRPC.Server do
  @moduledoc """
  gRPC for PreFlightChecks service
  """

  alias InternalApi.PreFlightChecksHub, as: API
  alias InternalApi.Status, as: APIStatus
  alias GRPC.Server.Stream, as: GRPCStream

  alias PreFlightChecks.OrganizationPFC.Model.{OrganizationPFCQueries, OrganizationPFC}
  alias PreFlightChecks.ProjectPFC.Model.{ProjectPFCQueries, ProjectPFC}
  alias PreFlightChecks.DestroyTraces.DestroyTraceQueries
  alias PreFlightChecks.GRPC.{Request, Response}

  use GRPC.Server, service: API.PreFlightChecksService.Service
  require Logger

  @doc """
  Describes pre-flight checks for given organization and/or project

  ## Levels
  * `LEVEL = ORGANIZATION` - describes organization PFC
  * `LEVEL = PROJECT` - describes project PFC
  * `LEVEL = EVERYTHING` - describes both organization and project PFCs
  """
  @spec describe(API.DescribeRequest.t(), GRPCStream.t()) :: API.DescribeResponse.t()
  def describe(request, _stream), do: watch("PFCHub.describe", fn -> describe(request) end)

  defp describe(%API.DescribeRequest{level: :ORGANIZATION, organization_id: ""}),
    do: Response.invalid_argument(API.DescribeResponse, "organization_id can't be blank")

  defp describe(%API.DescribeRequest{level: :ORGANIZATION} = request) do
    case OrganizationPFCQueries.find(request.organization_id) do
      {:ok, %OrganizationPFC{} = org_pfc} ->
        Response.success(API.DescribeResponse, org_pfc: org_pfc)

      {:error, {:not_found, organization_id}} ->
        Response.not_found(API.DescribeResponse, :organization, organization_id)
    end
  end

  defp describe(%API.DescribeRequest{level: :PROJECT, project_id: ""}),
    do: Response.invalid_argument(API.DescribeResponse, "project_id can't be blank")

  defp describe(%API.DescribeRequest{level: :PROJECT} = request) do
    case ProjectPFCQueries.find(request.project_id) do
      {:ok, %ProjectPFC{} = proj_pfc} ->
        Response.success(API.DescribeResponse, proj_pfc: proj_pfc)

      {:error, {:not_found, project_id}} ->
        Response.not_found(API.DescribeResponse, :project, project_id)
    end
  end

  defp describe(%API.DescribeRequest{level: :EVERYTHING, organization_id: ""}),
    do: Response.invalid_argument(API.DescribeResponse, "organization_id can't be blank")

  defp describe(%API.DescribeRequest{level: :EVERYTHING, project_id: ""}),
    do: Response.invalid_argument(API.DescribeResponse, "project_id can't be blank")

  defp describe(%API.DescribeRequest{level: :EVERYTHING} = request) do
    {_, maybe_org_pfc} = OrganizationPFCQueries.find(request.organization_id)
    {_, maybe_proj_pfc} = ProjectPFCQueries.find(request.project_id)

    case {maybe_org_pfc, maybe_proj_pfc} do
      {{:not_found, _}, {:not_found, _}} ->
        Response.not_found(API.DescribeResponse, :project, request.project_id)

      {%OrganizationPFC{} = org_pfc, {:not_found, _}} ->
        Response.success(API.DescribeResponse, org_pfc: org_pfc)

      {{:not_found, _}, %ProjectPFC{} = proj_pfc} ->
        Response.success(API.DescribeResponse, proj_pfc: proj_pfc)

      {%OrganizationPFC{} = org_pfc, %ProjectPFC{} = proj_pfc} ->
        Response.success(API.DescribeResponse, org_pfc: org_pfc, proj_pfc: proj_pfc)
    end
  end

  @doc """
  Applies pre-flight check for given organization or project

  ## Levels
  * `LEVEL = ORGANIZATION` - applies PFC to organization
  * `LEVEL = PROJECT` - applies PFC to project
  * `LEVEL = EVERYTHING` - non applicable
  """
  @spec apply(API.ApplyRequest.t(), GRPCStream.t()) :: API.ApplyResponse.t()
  def apply(request, _stream), do: watch("PFCHub.apply", fn -> apply(request) end)

  defp apply(%API.ApplyRequest{level: :ORGANIZATION} = request) do
    case OrganizationPFCQueries.upsert(Request.to_params(request)) do
      {:ok, %OrganizationPFC{} = org_pfc} ->
        Response.success(API.ApplyResponse, org_pfc: org_pfc)

      {:error, %Ecto.Changeset{} = changeset} ->
        Response.invalid_argument(API.ApplyResponse, changeset)
    end
  end

  defp apply(%API.ApplyRequest{level: :PROJECT} = request) do
    case ProjectPFCQueries.upsert(Request.to_params(request)) do
      {:ok, %ProjectPFC{} = proj_pfc} ->
        Response.success(API.DescribeResponse, proj_pfc: proj_pfc)

      {:error, %Ecto.Changeset{} = changeset} ->
        Response.invalid_argument(API.ApplyResponse, changeset)
    end
  end

  defp apply(%API.ApplyRequest{level: :EVERYTHING}),
    do: Response.invalid_argument(API.ApplyResponse, "level EVERYTHING is not supported")

  @doc """
  Destroys pre-flight check for given organization or project

  ## Levels
  * `LEVEL = ORGANIZATION` - destroys PFC of organization
  * `LEVEL = PROJECT` - destroys PFC of project
  * `LEVEL = EVERYTHING` - non applicable
  """
  @spec destroy(API.DestroyRequest.t(), GRPCStream.t()) :: API.DestroyResponse.t()
  def destroy(request, _stream), do: watch("PFCHub.destroy", fn -> destroy(request) end)

  defp destroy(%API.DestroyRequest{level: :ORGANIZATION, organization_id: ""}),
    do: Response.invalid_argument(API.DestroyResponse, "organization_id can't be blank")

  defp destroy(%API.DestroyRequest{level: :ORGANIZATION, requester_id: ""}),
    do: Response.invalid_argument(API.DestroyResponse, "requester_id can't be blank")

  defp destroy(%API.DestroyRequest{level: :ORGANIZATION} = request) do
    {:ok, request_trace} = DestroyTraceQueries.register(request)
    organization_id = request.organization_id

    case OrganizationPFCQueries.remove(organization_id) do
      {:ok, ^organization_id} ->
        DestroyTraceQueries.resolve_success(request_trace)
        %API.DestroyResponse{status: %APIStatus{}}

      {:error, %Ecto.Changeset{}} ->
        DestroyTraceQueries.resolve_failure(request_trace)
        msg = "Unable to destroy pre-flight check for organization #{organization_id}"
        Response.invalid_argument(API.DestroyResponse, msg)
    end
  end

  defp destroy(%API.DestroyRequest{level: :PROJECT, project_id: ""}),
    do: Response.invalid_argument(API.DestroyResponse, "project_id can't be blank")

  defp destroy(%API.DestroyRequest{level: :PROJECT, requester_id: ""}),
    do: Response.invalid_argument(API.DestroyResponse, "requester_id can't be blank")

  defp destroy(%API.DestroyRequest{level: :PROJECT} = request) do
    {:ok, request_trace} = DestroyTraceQueries.register(request)
    project_id = request.project_id

    case ProjectPFCQueries.remove(project_id) do
      {:ok, ^project_id} ->
        DestroyTraceQueries.resolve_success(request_trace)
        %API.DestroyResponse{status: %APIStatus{}}

      {:error, %Ecto.Changeset{}} ->
        DestroyTraceQueries.resolve_failure(request_trace)
        msg = "Unable to destroy pre-flight check for project #{project_id}"
        Response.invalid_argument(API.DestroyResponse, msg)
    end
  end

  defp destroy(%API.DestroyRequest{level: :EVERYTHING}),
    do: Response.invalid_argument(API.ApplyResponse, "level EVERYTHING is not supported")

  #
  # Watchman callbacks
  #
  defp watch(prefix_key, request_fn) do
    response = Watchman.benchmark(prefix_key, request_fn)
    Watchman.increment(counted_key(prefix_key, response))
    response
  end

  defp counted_key(prefix, %{status: %APIStatus{code: :OK}}), do: "#{prefix}.success"
  defp counted_key(prefix, %{status: %APIStatus{code: :NOT_FOUND}}), do: "#{prefix}.success"
  defp counted_key(prefix, %{status: %APIStatus{code: _code}}), do: "#{prefix}.failure"
end
