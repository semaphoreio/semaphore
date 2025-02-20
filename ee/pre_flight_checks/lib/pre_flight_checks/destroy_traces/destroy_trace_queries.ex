defmodule PreFlightChecks.DestroyTraces.DestroyTraceQueries do
  @moduledoc """
  Database operation for monitoring DestroyRequests for PFCs

  Each time DestroyRequest is sent, or event announcing delettion of
  organization or project, its trace is stored in presignated table
  (`destroy_request_traces`) for potential future debugging purpose.

  Upon the arrival, trace is inserted with temporary RECEIVED status.
  If request is processed successfully, it is marked with SUCCESS status.
  Otherwise, it is marked with FAILURE status.
  """
  alias PreFlightChecks.DestroyTraces.DestroyTrace, as: Trace
  alias PreFlightChecks.EctoRepo

  alias InternalApi.PreFlightChecksHub.DestroyRequest, as: Request
  alias InternalApi.Organization.OrganizationDeleted, as: OrganizationDeletedEvent
  alias InternalApi.Projecthub.ProjectDeleted, as: ProjectDeletedEvent

  @doc """
  Registers DestroyRequest with RECEIVED status
  """
  @spec register(Request.t() | OrganizationDeletedEvent.t() | ProjectDeletedEvent.t()) ::
          {:ok, Trace.t()} | {:error, Ecto.Changeset.t()}
  def register(request_or_event) do
    request_or_event
    |> to_changeset()
    |> EctoRepo.insert()
  end

  @doc """
  Resolves DestroyRequest with SUCCESS status
  """
  @spec resolve_success(Trace.t()) :: {:ok, Trace.t()} | {:error, Ecto.Changeset.t()}
  def resolve_success(%Trace{} = trace), do: resolve(trace, :SUCCESS)

  @doc """
  Resolves DestroyRequest with FAILURE status
  """
  @spec resolve_failure(Trace.t()) :: {:ok, Trace.t()} | {:error, Ecto.Changeset.t()}
  def resolve_failure(%Trace{} = trace), do: resolve(trace, :FAILURE)

  defp resolve(%Trace{} = trace, status) do
    trace
    |> put_status(status)
    |> EctoRepo.update()
  end

  defp to_changeset(%Request{} = request) do
    %Trace{}
    |> Trace.changeset(Map.from_struct(request))
    |> put_status(:RECEIVED)
  end

  defp to_changeset(%OrganizationDeletedEvent{} = event) do
    params = %{
      level: :ORGANIZATION,
      organization_id: event.org_id,
      project_id: "",
      requester_id: "organization_deleted_event"
    }

    %Trace{} |> Trace.changeset(params) |> put_status(:RECEIVED)
  end

  defp to_changeset(%ProjectDeletedEvent{} = event) do
    params = %{
      level: :PROJECT,
      organization_id: event.org_id,
      project_id: event.project_id,
      requester_id: "project_deleted_event"
    }

    %Trace{} |> Trace.changeset(params) |> put_status(:RECEIVED)
  end

  defp put_status(trace, status),
    do: Trace.changeset(trace, %{status: status})
end
