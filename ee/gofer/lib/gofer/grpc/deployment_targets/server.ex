defmodule Gofer.Grpc.DeploymentTargets.Server do
  @moduledoc """
  Module implements gRPC server which exposes endpoints defined in InternalAPI
  proto definition.
  """

  alias Gofer.DeploymentTrigger.Model.HistoryPage
  alias InternalApi.Gofer.DeploymentTargets, as: API
  use GRPC.Server, service: API.DeploymentTargets.Service

  alias Gofer.DeploymentTrigger.Model.DeploymentTrigger, as: Trigger
  alias Gofer.Deployment.Model.DeploymentQueries
  alias Gofer.Deployment.Model.Deployment
  alias Gofer.Deployment.Guardian

  alias Gofer.Switch.Model.Switch
  alias Gofer.Deployment.Engine.Supervisor

  require Logger

  def describe(request = %API.DescribeRequest{target_id: ""}, _stream) do
    if empty?(request.project_id) || empty?(request.target_name) do
      raise_error(:invalid_argument, "Missing arguments: target_id or (project_id, target_name)")
    end

    case DeploymentQueries.find_by_project_and_name(request.project_id, request.target_name) do
      {:ok, deployment = %Deployment{}} ->
        API.DescribeResponse.new(target: target_from_model(deployment))

      {:error, :not_found} ->
        raise GRPC.RPCError, status: GRPC.Status.not_found(), message: "Not found"
    end
  end

  def describe(request = %API.DescribeRequest{}, _stream) do
    case DeploymentQueries.find_by_id(request.target_id) do
      {:ok, deployment = %Deployment{}} ->
        API.DescribeResponse.new(target: target_from_model(deployment))

      {:error, :not_found} ->
        raise GRPC.RPCError, status: GRPC.Status.not_found(), message: "Not found"
    end
  end

  def verify(request = %API.VerifyRequest{}, _stream) do
    if empty?(request.target_id) do
      raise_error(:invalid_argument, "Missing argument: target_id")
    end

    if empty?(request.triggerer) do
      raise_error(:invalid_argument, "Missing argument: triggerer")
    end

    if empty?(request.git_ref_label) do
      raise_error(:invalid_argument, "Missing argument: git_ref_label")
    end

    object = {request.git_ref_type, request.git_ref_label}
    triggerer = request.triggerer

    deployment =
      case DeploymentQueries.find_by_id(request.target_id) do
        {:ok, deployment = %Deployment{}} -> deployment
        {:error, :not_found} -> raise_error(:not_found, "Target #{request.target_id} not found")
      end

    status =
      case Guardian.verify(deployment, object, triggerer) do
        {:ok, _metadata} -> :ACCESS_GRANTED
        {:error, {reason, _metadata}} -> reason
      end

    API.VerifyResponse.new(status: status)
  end

  def history(request = %API.HistoryRequest{}, _stream) do
    if empty?(request.target_id) do
      raise_error(:invalid_argument, "Missing argument: target_id")
    end

    deployment =
      case DeploymentQueries.find_by_id(request.target_id) do
        {:ok, deployment = %Deployment{}} -> deployment
        {:error, :not_found} -> raise_error(:not_found, "Target #{request.target_id} not found")
      end

    history_page =
      HistoryPage.load(request.target_id,
        cursor_type: request.cursor_type,
        cursor_value: request.cursor_value,
        filters: parse_filters(request.filters)
      )

    extra = %{deployment: deployment, requester_id: request.requester_id}

    API.HistoryResponse.new(
      deployments: Enum.into(history_page.results, [], &deployment_from_model(&1, extra)),
      cursor_before: history_page.cursor_before || 0,
      cursor_after: history_page.cursor_after || 0
    )
  end

  def list(request = %API.ListRequest{}, _stream) do
    if empty?(request.project_id),
      do: raise_error(:invalid_argument, "Missing argument: project_id")

    targets = DeploymentQueries.list_by_project_with_last_triggers(request.project_id)
    extra = %{requester_id: request.requester_id}

    API.ListResponse.new(targets: Enum.map(targets, &target_from_model(&1, extra)))
  end

  def cordon(request = %API.CordonRequest{target_id: target_id}, _stream) do
    if empty?(target_id),
      do: raise_error(:invalid_argument, "Missing argument: target_id")

    with {:ok, deployment} <- DeploymentQueries.find_by_id(target_id),
         {:ok, deployment} <- DeploymentQueries.cordon(deployment, request.cordoned) do
      API.CordonResponse.new(target_id: deployment.id, cordoned: deployment.cordoned)
    else
      {:error, :not_found} ->
        raise_error(:not_found, "Target not found: #{target_id}")

      {:error, {:invalid_state, state}} ->
        raise_error(:failed_precondition, "Invalid state: #{state}")

      {:error, _changeset = %Ecto.Changeset{}} ->
        raise_error(:invalid_argument, "Changeset error")

      {:error, reason} ->
        Logger.error("Cordon deployment target failed",
          extra: log_meta(request),
          reason: reason
        )

        raise_error(:unknown, "Unable to cordon DT")
    end
  end

  def create(request = %API.CreateRequest{}, _stream) do
    if is_nil(request.target),
      do: raise_error(:invalid_argument, "Missing argument: target")

    if empty?(request.unique_token),
      do: raise_error(:invalid_argument, "Missing argument: unique_token")

    if empty?(request.requester_id),
      do: raise_error(:invalid_argument, "Missing argument: requester_id")

    with {:ok, deployment} <-
           DeploymentQueries.create(
             request.unique_token,
             to_target_params(request),
             to_secret_params(request)
           ),
         {:ok, _pid} <- Supervisor.start_worker(deployment.id) do
      API.CreateResponse.new(target: target_from_model(deployment))
    else
      {:error, {:already_done, deployment = %Deployment{}}} ->
        Supervisor.start_worker(deployment.id)
        API.CreateResponse.new(target: target_from_model(deployment))

      {:error, changeset = %Ecto.Changeset{}} ->
        Logger.debug("Create deployment target failed",
          extra: log_meta(request),
          reason: inspect(changeset)
        )

        raise_error(:invalid_argument, "Changeset error")

      {:error, reason} ->
        Logger.error("Create deployment target failed",
          extra: log_meta(request),
          reason: reason
        )

        raise_error(:unknown, "Unable to create DT")
    end
  end

  def update(request = %API.UpdateRequest{}, _stream) do
    if is_nil(request.target),
      do: raise_error(:invalid_argument, "Missing argument: target")

    if empty?(request.unique_token),
      do: raise_error(:invalid_argument, "Missing argument: unique_token")

    if empty?(request.requester_id),
      do: raise_error(:invalid_argument, "Missing argument: requester_id")

    with {:ok, deployment} <-
           DeploymentQueries.update(
             request.target.id,
             request.unique_token,
             to_target_params(request),
             to_secret_params(request)
           ),
         {:ok, _pid} <- Supervisor.start_worker(deployment.id) do
      API.UpdateResponse.new(target: target_from_model(deployment))
    else
      {:error, {:already_done, deployment = %Deployment{}}} ->
        Supervisor.start_worker(deployment.id)
        API.UpdateResponse.new(target: target_from_model(deployment))

      {:error, :not_found} ->
        target_id = if empty?(request.target.id), do: "empty target ID", else: request.target.id
        raise_error(:not_found, "Target not found: #{target_id}")

      {:error, {:invalid_state, state}} ->
        raise_error(:failed_precondition, "Invalid state: #{state}")

      {:error, changeset = %Ecto.Changeset{}} ->
        Logger.debug("Update deployment target failed",
          extra: log_meta(request),
          reason: inspect(changeset)
        )

        raise_error(:invalid_argument, "Changeset error")

      {:error, reason} ->
        Logger.error("Update deployment target failed",
          extra: log_meta(request),
          reason: reason
        )

        raise_error(:unknown, "Unable to update DT")
    end
  end

  def delete(request = %API.DeleteRequest{}, _stream) do
    if empty?(request.target_id),
      do: raise_error(:invalid_argument, "Missing argument: target_id")

    if empty?(request.requester_id),
      do: raise_error(:invalid_argument, "Missing argument: requester_id")

    if empty?(request.unique_token),
      do: raise_error(:invalid_argument, "Missing argument: unique_token")

    with {:ok, deployment} <-
           DeploymentQueries.delete(request.target_id, request.unique_token, %{
             requester_id: request.requester_id,
             unique_token: request.unique_token
           }),
         {:ok, _pid} <- Supervisor.start_worker(deployment.id) do
      API.DeleteResponse.new(target_id: deployment.id)
    else
      {:error, {:already_done, deployment = %Deployment{}}} ->
        Supervisor.start_worker(deployment.id)
        API.DeleteResponse.new(target_id: deployment.id)

      {:error, :not_found} ->
        API.DeleteResponse.new(target_id: request.target_id)

      {:error, {:invalid_state, state}} ->
        raise_error(:failed_precondition, "Invalid state: #{state}")

      {:error, changeset = %Ecto.Changeset{}} ->
        Logger.error("Delete deployment target failed",
          extra: log_meta(request),
          reason: inspect(changeset)
        )

        raise_error(:invalid_argument, "Changeset error")

      {:error, reason} ->
        Logger.error("Delete deployment target failed",
          extra: log_meta(request),
          reason: inspect(reason)
        )

        raise_error(:unknown, "Unable to delete DT")
    end
  end

  # helpers

  defp target_from_model(row = %{deployment: _, switch: _, last_trigger: _}, extra) do
    deployment_target = target_from_model(row.deployment)
    last_deployment = deployment_from_model(row, extra)

    Map.from_struct(deployment_target)
    |> Map.put(:last_deployment, last_deployment)
    |> API.DeploymentTarget.new()
  end

  defp target_from_model(row = %{deployment: _, switch: _, last_trigger: _}),
    do: target_from_model(row, %{})

  defp target_from_model(deployment = %Deployment{}) do
    API.DeploymentTarget.new(
      id: deployment.id,
      name: deployment.name,
      description: deployment.description,
      url: deployment.url,
      bookmark_parameter1: deployment.bookmark_parameter1,
      bookmark_parameter2: deployment.bookmark_parameter2,
      bookmark_parameter3: deployment.bookmark_parameter3,
      organization_id: deployment.organization_id,
      project_id: deployment.project_id,
      created_by: deployment.created_by,
      updated_by: deployment.updated_by,
      created_at: timestamp_from(deployment.inserted_at),
      updated_at: timestamp_from(deployment.updated_at),
      cordoned: deployment.cordoned,
      state: state_from_model(deployment),
      state_message: state_message_from_model(deployment),
      subject_rules: subject_rules_from_model(deployment),
      object_rules: object_rules_from_model(deployment),
      secret_name: deployment.secret_name
    )
  end

  defp state_from_model(%Deployment{state: :SYNCING}), do: :SYNCING
  defp state_from_model(%Deployment{state: :FINISHED, cordoned: true}), do: :CORDONED
  defp state_from_model(%Deployment{state: :FINISHED, result: :SUCCESS}), do: :USABLE
  defp state_from_model(%Deployment{state: :FINISHED, result: :FAILURE}), do: :UNUSABLE

  defp state_message_from_model(%Deployment{encrypted_secret: nil}), do: ""

  defp state_message_from_model(%Deployment{encrypted_secret: encrypted_secret}),
    do: encrypted_secret.error_message

  defp subject_rules_from_model(deployment = %Deployment{}) do
    Enum.map(deployment.subject_rules, &rule_from_model/1)
  end

  defp object_rules_from_model(deployment = %Deployment{}) do
    Enum.map(deployment.object_rules, &rule_from_model/1)
  end

  defp rule_from_model(rule = %Deployment.SubjectRule{}) do
    API.SubjectRule.new(
      type: rule.type,
      subject_id: rule.subject_id
    )
  end

  defp rule_from_model(rule = %Deployment.ObjectRule{}) do
    API.ObjectRule.new(
      type: rule.type,
      match_mode: rule.match_mode,
      pattern: rule.pattern
    )
  end

  defp deployment_from_model(row = %{deployment: _, switch: _, last_trigger: _}, extra) do
    deployment_from_model(Map.merge(extra, row))
  end

  defp deployment_from_model(trigger = %Trigger{switch: switch = %Switch{}}, extra),
    do: deployment_from_model(Map.merge(extra, %{trigger: trigger, switch: switch}))

  defp deployment_from_model(args) when is_map(args) do
    trigger = args[:trigger] || args[:last_trigger]
    requester_id = args[:requester_id]
    deployment = args[:deployment]
    switch = args[:switch]

    if trigger && deployment && switch && requester_id do
      can_requester_rerun? =
        case Guardian.verify(deployment, switch, requester_id, cached?: true) do
          {:ok, _metadata} -> true
          {:error, _reason} -> false
        end

      API.Deployment.new(
        id: trigger.id,
        target_id: trigger.deployment_id,
        prev_pipeline_id: switch.ppl_id,
        pipeline_id: trigger.pipeline_id,
        triggered_by: trigger.triggered_by,
        triggered_at: timestamp_from(trigger.triggered_at),
        state: deployment_state_from_model(trigger),
        state_message: trigger.reason || "",
        switch_id: trigger.switch_id,
        target_name: trigger.target_name,
        env_vars: env_vars_from_deployment_model(trigger),
        can_requester_rerun: can_requester_rerun?
      )
    end
  end

  defp deployment_state_from_model(%Trigger{state: :INITIALIZING}), do: :PENDING
  defp deployment_state_from_model(%Trigger{state: :TRIGGERING}), do: :PENDING
  defp deployment_state_from_model(%Trigger{state: :STARTING}), do: :PENDING
  defp deployment_state_from_model(%Trigger{state: :DONE, result: "passed"}), do: :STARTED
  defp deployment_state_from_model(%Trigger{state: :DONE, result: "failed"}), do: :FAILED

  defp env_vars_from_deployment_model(%Trigger{switch_trigger_params: params, target_name: target}) do
    mapper = &API.Deployment.EnvVar.new(name: &1["name"], value: &1["value"])
    Enum.into(get_in(params, ["env_vars_for_target", target]), [], mapper)
  end

  defp timestamp_from(ndt = %NaiveDateTime{}),
    do: ndt |> DateTime.from_naive!("Etc/UTC") |> timestamp_from()

  defp timestamp_from(dt = %DateTime{}),
    do: Google.Protobuf.Timestamp.new(seconds: DateTime.to_unix(dt))

  defp parse_filters(filters = %API.HistoryRequest.Filters{}) do
    filter_keys = ~w(git_ref_type git_ref_label triggered_by parameter1 parameter2 parameter3)a
    filters |> Map.take(filter_keys) |> Enum.reject(&empty?(elem(&1, 1))) |> Map.new()
  end

  defp parse_filters(_filters), do: %{}

  defp empty?(string) when is_binary(string),
    do: string |> String.trim() |> String.equivalent?("")

  defp to_target_params(request = %API.CreateRequest{}) do
    request.target
    |> Map.take(~w(name description url
      bookmark_parameter1 bookmark_parameter2 bookmark_parameter3
      organization_id project_id)a)
    |> Map.put(:created_by, request.requester_id)
    |> Map.put(:updated_by, request.requester_id)
    |> Map.put(:unique_token, request.unique_token)
    |> Map.put(:subject_rules, subject_rules_params(request.target))
    |> Map.put(:object_rules, object_rules_params(request.target))
  end

  defp to_target_params(request = %API.UpdateRequest{}) do
    request.target
    |> Map.take(~w(name description url
      bookmark_parameter1 bookmark_parameter2 bookmark_parameter3)a)
    |> Map.put(:updated_by, request.requester_id)
    |> Map.put(:unique_token, request.unique_token)
    |> Map.put(:subject_rules, subject_rules_params(request.target))
    |> Map.put(:object_rules, object_rules_params(request.target))
  end

  defp subject_rules_params(target) do
    Enum.into(target.subject_rules, [], &Map.take(&1, ~w(type subject_id)a))
  end

  defp object_rules_params(target) do
    Enum.into(target.object_rules, [], &Map.take(&1, ~w(type match_mode pattern)a))
  end

  defp to_secret_params(_request = %{secret: nil}), do: :no_secret_params

  defp to_secret_params(request) do
    request.secret
    |> Map.take(~w(key_id aes256_key init_vector payload)a)
    |> Map.put(:requester_id, request.requester_id)
    |> Map.put(:unique_token, request.unique_token)
  end

  defp raise_error(error, message) do
    raise GRPC.RPCError,
      status: apply(GRPC.Status, error, []),
      message: message
  end

  defp log_meta(request = %API.CordonRequest{}) do
    inspect(target_id: request.target_id)
  end

  defp log_meta(request = %API.CreateRequest{}) do
    inspect(
      org_id: request.target.organization_id,
      project_id: request.target.project_id,
      target_name: request.target.name
    )
  end

  defp log_meta(request = %API.UpdateRequest{}) do
    inspect(
      org_id: request.target.organization_id,
      project_id: request.target.project_id,
      target_id: request.target.id
    )
  end

  defp log_meta(request = %API.DeleteRequest{}) do
    inspect(target_id: request.target_id)
  end
end
