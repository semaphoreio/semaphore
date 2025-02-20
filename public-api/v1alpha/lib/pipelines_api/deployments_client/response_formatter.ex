defmodule PipelinesAPI.DeploymentTargetsClient.ResponseFormatter do
  @moduledoc """
  Module parses the response from Gofer/Deployment Targets service and transforms it
  from protobuf messages into more suitable format for HTTP communication with
  API clients.
  """

  alias PipelinesAPI.UserApiClient
  alias PipelinesAPI.RBACClient
  alias Util.Proto
  alias Google.Protobuf.Timestamp

  @response_target_fields ~w(id name description url organization_id project_id created_by created_at updated_by updated_at state state_message subject_rules object_rules last_deployment active bookmark_parameter1 bookmark_parameter2 bookmark_parameter3)a

  def process_list_response({:ok, list_response}) do
    case to_map(list_response) do
      {:ok, %{targets: targets}} ->
        {:ok, process_targets(targets)}

      error ->
        error
    end
  end

  def process_list_response(error), do: error

  @spec process_create_response({:ok, any}) :: {:ok, any} | {:error, String.t()}
  def process_create_response({:ok, create_response}) do
    LogTee.debug(
      create_response,
      "DeploymentsClient.process_create_response"
    )

    case to_map(create_response) do
      {:ok, %{target: target}} ->
        {:ok, process_target(target)}

      error ->
        error
    end
  end

  def process_create_response(error) do
    LogTee.error(
      error,
      "DeploymentsClient.process_create_response"
    )

    error
  end

  @spec process_update_response(any) :: any
  def process_update_response({:ok, update_response}) do
    LogTee.debug(
      update_response,
      "DeploymentsClient.process_update_response"
    )

    case to_map(update_response) do
      {:ok, %{target: target}} -> {:ok, process_target(target)}
      error -> error
    end
  end

  def process_update_response(error) do
    LogTee.error(
      error,
      "DeploymentsClient.process_update_response"
    )

    error
  end

  def process_delete_response({:ok, delete_response}) do
    case to_map(delete_response) do
      {:ok, response} -> {:ok, response}
      error -> error
    end
  end

  def process_delete_response(error), do: error

  def process_describe_response({:ok, describe_response}) do
    case to_map(describe_response) do
      {:ok, %{target: target}} -> {:ok, process_target(target)}
      error -> error
    end
  end

  def process_describe_response(error), do: error

  def process_history_response({:ok, history_response}) do
    case to_map(history_response) do
      {:ok, response} ->
        {:ok,
         response
         |> Map.update(:deployments, [], fn deployments -> process_deployments(deployments) end)}

      error ->
        error
    end
  end

  def process_history_response(error), do: error

  def process_cordon_response({:ok, cordon_response}) do
    case to_map(cordon_response) do
      {:ok, response} -> {:ok, response}
      error -> error
    end
  end

  def process_cordon_response(error), do: error

  defp process_targets(targets) do
    targets |> Enum.map(fn target -> process_target(target) end)
  end

  defp process_target(target) do
    target
    |> Map.update(:state, nil, fn state -> to_string(state) end)
    |> Map.update(:last_deployment, nil, fn deployment -> process_deployment(deployment) end)
    |> replace_cordon_state
    |> update_subject_rules
    |> Map.take(@response_target_fields)
  end

  defp replace_cordon_state(target = %{cordoned: is_cordoned}) do
    target |> Map.delete(:cordoned) |> Map.put(:active, not is_cordoned)
  end

  defp replace_cordon_state(target), do: target

  defp update_subject_rules(
         target = %{organization_id: org_id, subject_rules: subject_rules, project_id: project_id}
       )
       when length(subject_rules) > 0 do
    case Enum.find(subject_rules, &has_user_subject_rule?/1) do
      nil ->
        target

      _ ->
        target |> Map.put(:subject_rules, populate_git_logins(subject_rules, org_id, project_id))
    end
  end

  defp update_subject_rules(target), do: target

  defp has_user_subject_rule?(_rule = %{type: :USER}), do: true

  defp has_user_subject_rule?(_rule), do: false

  defp populate_git_logins(subject_rules, org_id, project_id) do
    with {:ok, members} <-
           RBACClient.list_project_members(%{org_id: org_id, project_id: project_id}),
         id_to_login_map <- create_id_to_login_map(members) do
      Enum.into(subject_rules, [], &normalize_subject_rule(&1, id_to_login_map))
    else
      _ -> subject_rules
    end
  end

  defp create_id_to_login_map(members) do
    LogTee.debug(
      members,
      "DeploymentsClient.create_id_to_login_map"
    )

    Enum.reduce(members_to_users(members), %{}, fn user, acc ->
      try do
        case {user.id,
              Enum.find(user.repository_providers, fn p ->
                Map.has_key?(p, :login)
              end)} do
          {nil, _} ->
            acc

          {user_id, %{login: login}} ->
            Map.put(acc, user_id, login)

          {_, _} ->
            acc
        end
      rescue
        _err ->
          acc
      end
    end)
  end

  defp members_to_users(members) do
    members
    |> Enum.map(fn m -> m.subject.subject_id end)
    |> UserApiClient.describe_many()
    |> case do
      {:ok, response} ->
        response.users

      error ->
        LogTee.error(error, "Error mapping members to users")
        []
    end
  end

  defp normalize_subject_rule(rule = %{type: :USER, subject_id: subject_id}, id_to_login_map) do
    if Map.has_key?(id_to_login_map, subject_id),
      do: rule |> Map.put(:git_login, Map.get(id_to_login_map, subject_id)),
      else: rule
  end

  defp normalize_subject_rule(rule, _id_to_login_map), do: rule

  defp process_deployments(deployments) do
    deployments |> Enum.map(fn deployment -> process_deployment(deployment) end)
  end

  defp process_deployment(nil), do: nil

  defp process_deployment(deployment) do
    deployment |> Map.update(:state, nil, fn state -> to_string(state) end)
  end

  @spec to_map(any) ::
          {:error, %{:__exception__ => true, :__struct__ => atom, optional(atom) => any}}
          | {:ok, any}
  def to_map(response) do
    Proto.to_map(response,
      transformations: %{
        Timestamp => {__MODULE__, :timestamp_to_datetime_string}
      }
    )
  end

  def timestamp_to_datetime_string(_name, %{nanos: 0, seconds: 0}), do: ""

  def timestamp_to_datetime_string(_name, %{nanos: nanos, seconds: seconds}) do
    ts_in_microseconds = seconds * 1_000_000 + Integer.floor_div(nanos, 1_000)
    {:ok, ts_date_time} = DateTime.from_unix(ts_in_microseconds, :microsecond)
    ts_date_time |> DateTime.to_iso8601()
  end
end
