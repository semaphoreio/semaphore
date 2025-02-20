defmodule InternalClients.DeploymentTargetsClient.ResponseFormatter do
  @moduledoc """
  Module parses the response from Gofer/Deployment Targets service and transforms it
  from protobuf messages into more suitable format for HTTP communication with
  API clients.
  """

  require Logger
  alias InternalClients.UserApi, as: UserApiClient
  alias InternalClients.RBAC, as: RBACClient
  alias InternalApi.Gofer.DeploymentTargets, as: API

  def process_response({:ok, %API.ListResponse{targets: targets}}),
    do: {:ok, process_targets(targets)}

  def process_response({:ok, %API.CreateResponse{target: target}}) do
    {:ok, target_from_pb(target)}
  end

  def process_response({:ok, %API.DescribeResponse{target: target}}) do
    {:ok, target_from_pb(target)}
  end

  def process_response({:ok, %API.DeleteResponse{target_id: target_id}}) do
    {:ok, %{id: target_id}}
  end

  def process_response({:ok, %API.UpdateResponse{target: target}}) do
    {:ok, target_from_pb(target)}
  end

  def process_response({:ok, r = %API.HistoryResponse{deployments: deployments}}) do
    {:ok,
     %{
       next_page_token: r.cursor_before |> Integer.to_string(),
       prev_page_token: r.cursor_after |> Integer.to_string(),
       page_size: 20,
       with_direction: true,
       entries: process_deployments(deployments)
     }}
  end

  def process_response({:ok, %API.CordonResponse{target_id: id, cordoned: cordoned?}}) do
    {:ok,
     %{
       id: id,
       state: if(cordoned?, do: "CORDONED", else: "USABLE")
     }}
  end

  def process_response({:error, %GRPC.RPCError{status: status, message: message}})
      when status in [5, :not_found] do
    {:error, {:not_found, message}}
  end

  def process_response({:error, %GRPC.RPCError{status: status, message: message}})
      when status in [9, :failed_precondition] do
    {:error, {:user, "#{message}"}}
  end

  def process_response({:error, error}), do: {:error, error}

  defp process_targets(targets) do
    targets |> Enum.map(fn target -> target_from_pb(target) end)
  end

  defp target_from_pb(t = %API.DeploymentTarget{}) do
    %{
      apiVersion: "v2",
      kind: "DeploymentTarget",
      metadata: %{
        id: t.id,
        project_id: t.project_id,
        org_id: t.organization_id,
        name: t.name,
        description: t.description,
        created_at: PublicAPI.Util.Timestamps.to_timestamp(t.created_at),
        updated_at: PublicAPI.Util.Timestamps.to_timestamp(t.updated_at),
        created_by: InternalClients.Common.User.from_id(t.created_by),
        updated_by: InternalClients.Common.User.from_id(t.updated_by),
        state: Atom.to_string(t.state),
        last_deployment: deployment_from_pb(t.last_deployment)
      },
      spec: %{
        name: t.name,
        description: t.description,
        url: t.url,
        bookmark_parameters: bookmark_parameters_from_pb(t),
        subject_rules: subject_rules_from_pb(t),
        active: not t.cordoned,
        object_rules: object_rules_from_pb(t)
      }
    }
  end

  defp bookmark_parameters_from_pb(t = %API.DeploymentTarget{}) do
    [t.bookmark_parameter1, t.bookmark_parameter2, t.bookmark_parameter3]
    |> Enum.reject(fn p -> is_nil(p) or p == "" end)
  end

  defp subject_rules_from_pb(%API.DeploymentTarget{
         organization_id: org_id,
         subject_rules: subject_rules,
         project_id: project_id
       })
       when length(subject_rules) > 0 do
    any? = Enum.any?(subject_rules, &(&1.type == :ANY))
    auto? = Enum.any?(subject_rules, &(&1.type == :AUTO))
    roles = Enum.filter(subject_rules, &(&1.type == :ROLE)) |> Enum.map(& &1.subject_id)

    git_handles = get_git_logins!(org_id, project_id)

    users =
      Enum.filter(subject_rules, &(&1.type == :USER))
      |> Enum.map(fn rule -> normalize_subject_rule(rule, git_handles) end)

    if any? do
      %{
        any: true
      }
    else
      %{any: false, auto: auto?, roles: roles, users: users}
    end
  end

  defp subject_rules_from_pb(_),
    do: %{
      any: true
    }

  defp object_rules_from_pb(%API.DeploymentTarget{object_rules: object_rules}) do
    branches_rules = Enum.filter(object_rules, fn rule -> rule.type == :BRANCH end)
    tags_rules = Enum.filter(object_rules, fn rule -> rule.type == :TAG end)
    prs_rules = Enum.filter(object_rules, fn rule -> rule.type == :PR end)

    branches =
      if Enum.any?(branches_rules, &(&1.match_mode == :ALL)) do
        "ALL"
      else
        Enum.map(branches_rules, &%{match_mode: &1.match_mode, pattern: &1.pattern})
      end

    tags =
      if Enum.any?(tags_rules, &(&1.match_mode == :ALL)) do
        "ALL"
      else
        Enum.map(tags_rules, &%{match_mode: &1.match_mode, pattern: &1.pattern})
      end

    prs = if length(prs_rules) > 0, do: "ALL", else: "NONE"

    %{
      branches: branches,
      tags: tags,
      prs: prs
    }
  end

  defp get_git_logins!(org_id, project_id) do
    RBACClient.list_project_members(%{org_id: org_id, project_id: project_id})
    |> case do
      {:ok, members} ->
        create_id_to_login_map(members)

      error ->
        Logger.error("Failed to get project members: #{inspect(error)}")
        raise ArgumentError, "Failed to get project members, please try again later."
    end
  end

  defp create_id_to_login_map(members) do
    LogTee.debug(
      members,
      "DeploymentsClient.create_id_to_login_map"
    )

    Enum.reduce(members_to_users(members), %{}, fn user, acc ->
      case Enum.find(user.repository_providers, &(!is_nil(&1.login))) do
        %{login: login} ->
          Map.put(acc, user.id, login)

        _ ->
          acc
      end
    end)
  end

  defp members_to_users(members) do
    members
    |> Enum.map(fn m -> m.subject.subject_id end)
    |> UserApiClient.describe_many()
    |> case do
      {:ok, users} ->
        users

      error ->
        LogTee.error(error, "Error mapping members to users")
        []
    end
  end

  defp normalize_subject_rule(%{type: :USER, subject_id: subject_id}, git_handles) do
    Map.get(git_handles, subject_id, subject_id)
  end

  defp process_deployments(deployments) do
    deployments |> Enum.map(&deployment_from_pb/1)
  end

  defp deployment_from_pb(nil), do: nil

  defp deployment_from_pb(d = %API.Deployment{}) do
    %{
      id: d.id,
      target_name: d.target_name,
      origin_pipeline_id: d.prev_pipeline_id,
      state: Atom.to_string(d.state),
      pipeline_id: pipeline_id(d.pipeline_id),
      triggered_by: InternalClients.Common.User.from_id(d.triggered_by),
      triggered_at: PublicAPI.Util.Timestamps.to_timestamp(d.triggered_at),
      target_id: d.target_id,
      state_message: d.state_message
    }
  end

  defp pipeline_id(""), do: nil
  defp pipeline_id(pipeline_id), do: pipeline_id
end
