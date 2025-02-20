defmodule Gofer.RBAC.Client do
  @moduledoc """
  gRPC client for role-based access control

  Checks roles assigned to a particular user.
  """
  alias InternalApi.RBAC.SubjectsHaveRolesRequest, as: Request
  alias InternalApi.RBAC.SubjectsHaveRolesResponse, as: Response
  alias InternalApi.RBAC

  alias Gofer.RBAC.Subject

  @metric_prefix "Gofer.deployments.rbac"
  @default_timeout 3_000

  def check_roles(_subject, []), do: {:ok, %{}}

  def check_roles(subject = %Subject{}, role_ids) do
    result =
      Watchman.benchmark(duration_metric("check_roles"), fn ->
        Wormhole.capture(__MODULE__, :do_check_roles, [subject, Enum.to_list(role_ids)],
          timeout: config()[:timeout] || @default_timeout,
          stacktrace: true
        )
      end)

    case result do
      {:ok, {:ok, result}} ->
        Watchman.increment(success_metric("check_roles"))
        {:ok, result}

      {:ok, {:error, reason}} ->
        Watchman.increment(failure_metric("check_roles"))
        {:error, reason}

      error ->
        Watchman.increment(failure_metric("check_roles"))
        error
    end
  end

  def do_check_roles(subject = %Subject{}, role_ids) do
    request = Request.new(role_assignments: to_assignments(subject, role_ids))
    func = &RBAC.RBAC.Stub.subjects_have_roles/2

    with {:ok, channel} <- GRPC.Stub.connect(config()[:endpoint]),
         {:ok, response} <- grpc_send(channel, func, request) do
      parse_response(response)
    else
      {:error, _reason} = error -> error
    end
  end

  defp grpc_send(channel, func, request),
    do: func.(channel, request),
    after: GRPC.Stub.disconnect(channel)

  defp parse_response(%Response{has_roles: data}),
    do: {:ok, Enum.into(data, %{}, &{&1.role_assignment.role_id, &1.has_role})}

  defp to_assignments(subject, role_ids) do
    Enum.map(role_ids, fn role_id ->
      RBAC.RoleAssignment.new(
        org_id: subject.organization_id,
        project_id: subject.project_id,
        role_id: role_id,
        subject:
          RBAC.Subject.new(
            subject_type: :USER,
            subject_id: subject.triggerer
          )
      )
    end)
  end

  defp config, do: Application.get_env(:gofer, __MODULE__)

  defp duration_metric(metric_name), do: "#{@metric_prefix}.#{metric_name}"
  defp success_metric(metric_name), do: "#{@metric_prefix}.#{metric_name}.success"
  defp failure_metric(metric_name), do: "#{@metric_prefix}.#{metric_name}.failure"
end
