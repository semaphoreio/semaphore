defmodule InternalClients.DeploymentTargetsClient.RequestFormatter do
  @moduledoc """
  Module formats the request using data received from API client via HTTP into protobuf
  messages suitable for gRPC communication with Gofer/DeploymentTarget service.
  """

  alias InternalClients.RBAC, as: RBACClient
  alias InternalClients.UserApi, as: UserApiClient

  alias PublicAPI.Util.ToTuple

  alias InternalApi.Gofer.DeploymentTargets, as: API

  alias API.{
    DeploymentTarget,
    ListRequest,
    CreateRequest,
    UpdateRequest,
    DeleteRequest,
    DescribeRequest,
    HistoryRequest,
    CordonRequest
  }

  import InternalClients.Common

  @on_load :load_atoms

  defp load_atoms() do
    [
      InternalApi.Gofer.DeploymentTargets.ObjectRule.Mode,
      InternalApi.Gofer.DeploymentTargets.ObjectRule.Type,
      InternalApi.Gofer.DeploymentTargets.SubjectRule.Type,
      InternalApi.Gofer.DeploymentTargets.HistoryRequest.CursorType
    ]
    |> Enum.each(&Code.ensure_loaded/1)
  end

  # List

  def form_request({ListRequest, params}) do
    %ListRequest{project_id: params.project_id, requester_id: params.user_id}
    |> ToTuple.ok()
  end

  # Create

  def form_request({CreateRequest, params}) do
    %CreateRequest{
      requester_id: params.user_id,
      unique_token: params.unique_token,
      secret: encode_secret_data!(params.deployment_target.spec, params.secrets_encryption_key),
      target: create_deployment_target(params)
    }
    |> ToTuple.ok()
  end

  # Describe

  def form_request({DescribeRequest, params}) do
    %DescribeRequest{
      project_id: params.project_id,
      target_id: params.target_id,
      target_name: params.target_name
    }
    |> ToTuple.ok()
  end

  def form_request({DeleteRequest, params}) do
    %DeleteRequest{
      target_id: params.target_id,
      requester_id: params.user_id,
      unique_token: params.unique_token
    }
    |> ToTuple.ok()
  end

  def form_request({UpdateRequest, params}) do
    old_dt = params.old_target
    new_dt = params.new_target
    new_spec = Map.merge(from_params(old_dt, :spec), from_params(new_dt, :spec))
    params = Map.put(params, :deployment_target, %{spec: new_spec})

    %UpdateRequest{
      unique_token: from_params!(params, :unique_token),
      requester_id: from_params!(params, :user_id),
      target:
        create_deployment_target(params)
        |> Map.put(:id, from_params!(params, :deployment_target_id)),
      secret: encode_secret_data!(params.deployment_target.spec, params.secrets_encryption_key)
    }
    |> ToTuple.ok()
  end

  def form_request({HistoryRequest, params}) do
    %HistoryRequest{
      target_id: from_params!(params, :target_id),
      cursor_type: from_params(params, :cursor_type, "FIRST") |> String.to_existing_atom(),
      cursor_value: from_params(params, :cursor_value),
      requester_id: from_params!(params, :user_id),
      filters: history_filters(params)
    }
    |> ToTuple.ok()
  end

  def form_request({CordonRequest, params}) do
    %CordonRequest{
      target_id: from_params!(params, :target_id),
      cordoned: from_params(params, :cordon, false)
    }
    |> ToTuple.ok()
  end

  # private functions

  defp create_deployment_target(params = %{deployment_target: dt}) do
    bookmarks = from_params(dt.spec, :bookmark_parameters, [])

    %DeploymentTarget{
      name: from_params!(dt.spec, :name),
      url: from_params(dt.spec, :url, ""),
      description: from_params(dt.spec, :description, ""),
      organization_id: from_params!(params, :organization_id),
      project_id: from_params!(params, :project_id),
      subject_rules:
        subject_rules_from_spec(
          from_params(dt.spec, :subject_rules, %{}),
          from_params(params, :project_id),
          from_params(params, :organization_id)
        ),
      object_rules: object_rules_from_spec(dt.spec),
      bookmark_parameter1: Enum.at(bookmarks, 0, ""),
      bookmark_parameter2: Enum.at(bookmarks, 1, ""),
      bookmark_parameter3: Enum.at(bookmarks, 2, "")
    }
  end

  defp object_rules_from_spec(spec_object_rules) do
    branches =
      from_params(spec_object_rules, :branch, "ALL")
      |> object_rules_for_type(:BRANCH)

    tags =
      from_params(spec_object_rules, :tag, "ALL")
      |> object_rules_for_type(:TAG)

    prs =
      from_params(spec_object_rules, :pr, "NONE")
      |> object_rules_for_type(:PR)

    branches ++ tags ++ prs
  end

  def object_rules_for_type("ALL", type),
    do: [%API.ObjectRule{type: type, match_mode: :ALL, pattern: ""}]

  def object_rules_for_type("NONE", _type),
    do: []

  def object_rules_for_type(object_rule, type) when is_list(object_rule) do
    Enum.map(object_rule, fn rule ->
      %API.ObjectRule{
        type: type,
        match_mode: from_params(rule, :match_mode, "ALL") |> String.to_existing_atom(),
        pattern: from_params(rule, :pattern, "")
      }
    end)
  end

  defp subject_rules_from_spec(%{any: true}, _project_id, _org_id) do
    [%API.SubjectRule{type: :ANY}]
  end

  defp subject_rules_from_spec(spec_subject_rules, project_id, org_id) do
    auto_rules =
      subject_rules_for_type(
        :auto,
        from_params(spec_subject_rules, :auto, false),
        org_id,
        project_id
      )

    user_rules =
      subject_rules_for_type(
        :users,
        from_params(spec_subject_rules, :users, []),
        org_id,
        project_id
      )

    role_rules =
      subject_rules_for_type(
        :roles,
        from_params(spec_subject_rules, :roles, []),
        org_id,
        project_id
      )

    auto_rules ++ user_rules ++ role_rules
  end

  def subject_rules_for_type(:auto, true, _, _), do: [%API.ObjectRule{type: :AUTO}]
  def subject_rules_for_type(:auto, false, _, _), do: []

  def subject_rules_for_type(:roles, roles, org_id, _) do
    project_rules_to_uuids(org_id)
    |> case do
      {:ok, role_name_to_uuid} ->
        Enum.map(roles, &role_rule!(&1, role_name_to_uuid))

      {:error, _msg} ->
        raise ArgumentError, "error fetching roles for the project"
    end
  end

  def subject_rules_for_type(:users, user_handles_or_ids, org_id, project_id) do
    project_handles_to_uuids(org_id, project_id)
    |> case do
      {:ok, handle_to_uuid} ->
        Enum.map(user_handles_or_ids, &user_rule!(&1, handle_to_uuid))

      {:error, _} ->
        raise ArgumentError, "error fetching git handles for the project members"
    end
  end

  # fetching git handles for project members and mapping them to user ids
  defp project_handles_to_uuids(org_id, project_id) do
    with {:ok, members} <-
           RBACClient.list_project_members(%{org_id: org_id, project_id: project_id}),
         login_to_user_id_map <- login_to_user_id_map(members) do
      {:ok, login_to_user_id_map}
    else
      error ->
        error
    end
  end

  defp login_to_user_id_map(members) do
    LogTee.debug(
      members,
      "DeploymentsClient.login_to_user_id_map"
    )

    Enum.reduce(members_to_users(members), %{}, fn user, acc ->
      Enum.find(user.repository_providers, &(!is_nil(&1.login)))
      |> case do
        %{login: login} ->
          Map.put(acc, login, user.id)

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

  defp user_rule!(id_or_handle, handle_to_uuid) do
    case UUID.info(id_or_handle) do
      {:ok, _} ->
        %API.SubjectRule{type: :USER, subject_id: id_or_handle}

      _ ->
        case Map.get(handle_to_uuid, id_or_handle) do
          nil ->
            raise ArgumentError,
                  "User #{id_or_handle} does not exist or is not a member of the project"

          user_id ->
            %API.SubjectRule{type: :USER, subject_id: user_id}
        end
    end
  end

  # fetching roles in project
  defp project_rules_to_uuids(org_id) do
    RBACClient.list_project_scope_roles(%{org_id: org_id})
    |> case do
      {:ok, project_scope_roles} ->
        {:ok, role_name_to_role_map(project_scope_roles)}

      error ->
        error
    end
  end

  defp role_name_to_role_map(project_scope_roles) do
    Enum.into(project_scope_roles, %{}, fn role ->
      {String.downcase(role.name), role.name}
    end)
  end

  defp role_rule!(role_name, role_name_to_uuid) do
    case Map.get(role_name_to_uuid, String.downcase(role_name)) do
      nil ->
        raise ArgumentError, "Role #{role_name} does not exist in the project."

      role_id ->
        %API.SubjectRule{type: :ROLE, subject_id: role_id}
    end
  end

  ### Secret Data
  defp encode_secret_data!(params, key) do
    PublicAPI.Handlers.DeploymentTargets.Util.Encrypt.encrypt_data(params, process_key(key))
    |> case do
      {:ok, data} -> data
      {:error, msg} -> raise ArgumentError, msg
    end
  end

  def process_key(%{id: key_id, key: key}) do
    with {:ok, base_decoded_key} <- Base.decode64(key),
         {:ok, rsa_public_key} <- ExPublicKey.RSAPublicKey.decode_der(base_decoded_key) do
      {:ok, {key_id, rsa_public_key}}
    else
      _ -> ToTuple.internal_error("Error processing key map to key pair")
    end
  end

  def process_key(_value), do: ToTuple.error("invalid key")

  defp history_filters(params) do
    %API.HistoryRequest.Filters{
      git_ref_label: from_params(params, :git_ref_label, ""),
      git_ref_type: from_params(params, :git_ref_type, ""),
      triggered_by: from_params(params, :triggered_by, ""),
      parameter1: from_params(params, :parameter1, ""),
      parameter2: from_params(params, :parameter2, ""),
      parameter3: from_params(params, :parameter3, "")
    }
  end
end
