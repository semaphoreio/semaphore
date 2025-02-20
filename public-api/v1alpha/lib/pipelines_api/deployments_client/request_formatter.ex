defmodule PipelinesAPI.DeploymentTargetsClient.RequestFormatter do
  @moduledoc """
  Module formats the request using data received from API client via HTTP into protobuf
  messages suitable for gRPC communication with Gofer/DeploymentTarget service.
  """

  alias PipelinesAPI.UserApiClient
  alias PipelinesAPI.RBACClient
  alias PipelinesAPI.Secrets
  alias PipelinesAPI.Validator

  alias Support.Stubs.Secret
  alias Plug.Conn

  alias PipelinesAPI.Util.ToTuple

  alias InternalApi.Gofer.DeploymentTargets.{
    ListRequest,
    CreateRequest,
    UpdateRequest,
    DeleteRequest,
    DescribeRequest,
    HistoryRequest,
    CordonRequest
  }

  alias InternalApi.Secrethub.Secret

  alias PipelinesAPI.Util.VerifyData, as: VD

  @create_secret_fields ~w(env_vars files key)a
  @create_target_fields ~w(project_id name description url subject_rules object_rules bookmark_parameter1 bookmark_parameter2 bookmark_parameter3)a

  @update_secret_fields ~w(env_vars files key old_env_vars old_files)a
  @update_target_fields ~w(project_id id target_id name description url subject_rules object_rules bookmark_parameter1 bookmark_parameter2 bookmark_parameter3)a

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

  def form_list_request(params = %{"project_id" => _}) when is_map(params) do
    params = convert_keys_to_atoms(params)

    case verify_list_request(params) do
      error = {:error, _} ->
        error

      :ok ->
        form_list_request_(params)
    end
  end

  def form_list_request(error = {:error, _}), do: error

  def form_list_request(_),
    do: ToTuple.user_error("project_id is required to list deployment targets")

  defp form_list_request_(params = %{project_id: project_id}) when is_map(params) do
    %{
      project_id: project_id
    }
    |> Util.Proto.deep_new(ListRequest)
  catch
    error -> error
  end

  # Create

  def form_create_request(
        params = %{"unique_token" => unique_token, "name" => name, "project_id" => project_id},
        conn
      )
      when is_binary(unique_token) and is_binary(name) and is_binary(project_id) do
    LogTee.debug(conn, "DeploymentsClient.form_create_request received request")
    params = convert_keys_to_atoms(params)

    case verify_create_request(params) do
      error = {:error, _} ->
        error

      :ok ->
        form_create_request_(params, conn)
    end
  end

  def form_create_request(error = {:error, _}, _), do: error

  def form_create_request(_, _),
    do:
      ToTuple.user_error(
        "unique_token, name and project_id are required to create a deployment target"
      )

  defp form_create_request_(
         params = %{unique_token: unique_token, name: _, project_id: _},
         conn
       ) do
    processed =
      %{
        requester_id: Conn.get_req_header(conn, "x-semaphore-user-id") |> Enum.at(0, ""),
        unique_token: unique_token
      }
      |> create_secret(params |> Map.take(@create_secret_fields))
      |> create_deployment_target(
        params
        |> Map.take(@create_target_fields),
        conn
      )
      |> check_subject_rules

    case processed do
      {:ok, request} -> Util.Proto.deep_new(request, CreateRequest, string_keys_to_atoms: true)
      error -> error
    end
  catch
    error -> error
  end

  def form_update_request(
        params = %{
          "unique_token" => unique_token,
          "target_id" => id,
          "old_target" => old_target
        },
        conn
      ),
      do: form_update_request_(unique_token, id, old_target, params, conn)

  def form_update_request(
        params = %{
          "unique_token" => unique_token,
          "id" => id,
          "old_target" => old_target
        },
        conn
      ),
      do: form_update_request_(unique_token, id, old_target, params, conn)

  def form_update_request(error = {:error, _}, _), do: error

  def form_update_request(_, _) do
    ToTuple.user_error("target_id and unique_token are required to update a deployment target")
  end

  defp form_update_request_(unique_token, id, old_target, params, conn) do
    LogTee.debug(conn, "DeploymentsClient.form_update_request_ received request")
    params = convert_keys_to_atoms(params)

    case verify_update_request(params) do
      error = {:error, _} ->
        error

      :ok ->
        do_form_update_request_(unique_token, id, old_target, params, conn)
    end
  end

  defp do_form_update_request_(unique_token, id, old_target, params, conn) do
    target = params |> Map.take(@update_target_fields)
    old_target = old_target |> Map.take(@update_target_fields)

    processed =
      %{
        requester_id: Conn.get_req_header(conn, "x-semaphore-user-id") |> Enum.at(0, ""),
        unique_token: unique_token
      }
      |> update_secret(params |> Map.take(@update_secret_fields))
      |> update_deployment_target(old_target |> Map.merge(target) |> Map.put(:id, id), conn)
      |> check_subject_rules

    LogTee.debug(processed, "DeploymentsClient.form_update_request_ processed request")

    case processed do
      {:ok, request} ->
        Util.Proto.deep_new(request, UpdateRequest)

      error ->
        LogTee.error(error, "DeploymentsClient.form_update_request_ error processing request")
        error
    end
  catch
    error ->
      LogTee.error(error, "DeploymentsClient.form_update_request_ error caught during processing")
      error
  end

  def form_delete_request(
        params = %{"unique_token" => _unique_token, "target_id" => _target_id},
        conn
      ) do
    params = convert_keys_to_atoms(params)

    case verify_delete_request(params) do
      error = {:error, _} ->
        error

      :ok ->
        form_delete_request_(params, conn)
    end
  end

  def form_delete_request(_, _),
    do:
      ToTuple.user_error("target_id and unique_token are required to delete a deployment target")

  defp form_delete_request_(
         params = %{unique_token: unique_token, target_id: target_id},
         conn
       ) do
    params = convert_keys_to_atoms(params)

    case verify_delete_request(params) do
      error = {:error, _} ->
        error

      :ok ->
        %{
          requester_id: Conn.get_req_header(conn, "x-semaphore-user-id") |> Enum.at(0, ""),
          unique_token: unique_token,
          target_id: target_id
        }
        |> Util.Proto.deep_new(DeleteRequest, string_keys_to_atoms: true)
    end
  catch
    error -> error
  end

  def form_describe_request(params) do
    params = convert_keys_to_atoms(params)

    case verify_describe_request(params) do
      error = {:error, _} ->
        error

      :ok ->
        form_describe_request_(params)
    end
  catch
    error -> error
  end

  defp form_describe_request_(%{project_id: project_id, target_name: target_name} = params)
       when is_map(params) do
    %{
      project_id: project_id,
      target_name: target_name
    }
    |> Util.Proto.deep_new(DescribeRequest, string_keys_to_atoms: true)
  end

  defp form_describe_request_(params = %{target_id: target_id})
       when is_map(params) do
    %{
      target_id: target_id
    }
    |> Util.Proto.deep_new(DescribeRequest, string_keys_to_atoms: true)
  end

  defp form_describe_request_(params = %{id: target_id})
       when is_map(params) do
    %{
      target_id: target_id
    }
    |> Util.Proto.deep_new(DescribeRequest, string_keys_to_atoms: true)
  end

  defp form_describe_request_(_),
    do:
      ToTuple.user_error(
        "target_name and project_id or target_id is required to describe a deployment target"
      )

  def form_history_request(params = %{"target_id" => _target_id}) do
    params = convert_keys_to_atoms(params)

    case verify_history_request(params) do
      error = {:error, _} ->
        error

      :ok ->
        form_history_request_(params)
    end
  catch
    error -> error
  end

  def form_history_request(_),
    do: ToTuple.user_error("target_id is required to get deployments history")

  defp form_history_request_(params = %{target_id: target_id})
       when is_map(params) do
    LogTee.debug(
      params,
      "DeploymentsClient.form_history_request"
    )

    %{
      target_id: target_id,
      cursor_type: format_cursor_type(params),
      cursor_value: (params[:cursor_value] || 0) |> to_int("cursor_value"),
      filters: %{
        git_ref_type: params[:git_ref_type] || "",
        git_ref_label: params[:git_ref_label] || "",
        triggered_by: params[:triggered_by] || "",
        parameter1: params[:parameter1] || "",
        parameter2: params[:parameter2] || "",
        parameter3: params[:parameter3] || ""
      }
    }
    |> Util.Proto.deep_new(HistoryRequest, string_keys_to_atoms: true)
  catch
    error -> error
  end

  def form_cordon_request(params = %{"target_id" => target_id, "cordoned" => cordoned})
      when is_map(params) do
    %{
      target_id: target_id,
      cordoned: is_cordoned(cordoned)
    }
    |> Util.Proto.deep_new(CordonRequest, string_keys_to_atoms: true)
  catch
    error -> error
  end

  def form_cordon_request(_),
    do: ToTuple.user_error("target_id is required to activate/deactivate a deployment target")

  # private functions

  defp create_deployment_target(request, params, conn) do
    LogTee.debug(
      conn,
      "DeploymentsClient.create_deployment_target, request=#{inspect(request)}, params=#{inspect(params)}"
    )

    request
    |> Map.put(
      :target,
      params
      |> Map.put(
        :organization_id,
        Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, "")
      )
      |> format_subject_rules(true)
      |> format_object_rules(true)
    )
  end

  defp update_deployment_target(request, params, conn) do
    LogTee.debug(
      conn,
      "DeploymentsClient.update_deployment_target, request=#{inspect(request)}, params=#{inspect(params)}"
    )

    request
    |> Map.put(
      :target,
      params
      |> Map.put(
        :organization_id,
        Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, "")
      )
      |> format_subject_rules(false)
      |> format_object_rules(false)
    )
  end

  defp create_secret(request, params) do
    Map.put(request, :secret, encode_secret_data(params))
  end

  defp encode_secret_data(params) do
    LogTee.debug(
      params,
      "DeploymentsClient.encode_secret_data"
    )

    encoded_payload =
      %{
        env_vars: params[:env_vars] || [],
        files: params[:files] || []
      }
      |> Util.Proto.deep_new!(Secret.Data, string_keys_to_atoms: true)
      |> Secret.Data.encode()

    with {:ok, {key_id, public_key}} <- Secrets.Key.process_key(params[:key]),
         {:ok, aes256_key} <-
           ExCrypto.generate_aes_key(:aes_256, :bytes),
         {:ok, {init_vector, encrypted_payload}} <-
           ExCrypto.encrypt(aes256_key, encoded_payload),
         {:ok, encrypted_aes256_key} <-
           ExPublicKey.encrypt_public(aes256_key, public_key),
         {:ok, encrypted_init_vector} <-
           ExPublicKey.encrypt_public(init_vector, public_key) do
      %{
        key_id: to_string(key_id),
        aes256_key: to_string(encrypted_aes256_key),
        init_vector: to_string(encrypted_init_vector),
        payload: Base.encode64(encrypted_payload)
      }
    else
      {:error, _} ->
        ToTuple.internal_error("encryption failed")
    end
  end

  defp update_secret(request, params) do
    LogTee.debug(
      params,
      "DeploymentsClient.update_secret, request=#{inspect(request)}"
    )

    if params[:env_vars] || params[:files] do
      old_env_vars = Map.new(params.old_env_vars, &{&1.name, &1.value})
      old_files = Map.new(params.old_files, &{&1.path, &1.content})

      updated_env_vars = Map.new(params[:env_vars] || [], &{&1[:name] || "", &1[:value] || ""})
      updated_files = Map.new(params[:files] || [], &{&1[:path] || "", &1[:content] || ""})

      encoded =
        params
        |> Map.put(
          :env_vars,
          Enum.into(updated_env_vars, [], &check_env_var(&1, old_env_vars))
        )
        |> Map.put(:files, Enum.into(updated_files, [], &check_file(&1, old_files)))
        |> encode_secret_data

      Map.put(request, :secret, encoded)
    else
      request
    end
  end

  defp format_subject_rules(params = %{subject_rules: subject_rules}, _is_create)
       when not is_nil(subject_rules) do
    Map.put(
      params,
      :subject_rules,
      subject_rules |> Enum.map(fn rule -> format_subject_rule(rule) end)
    )
  end

  defp format_subject_rules(params, _is_create = true),
    do: Map.put(params, :subject_rules, default_subject_rules())

  defp format_subject_rules(params, _is_create = false), do: params

  defp default_subject_rules() do
    [%{type: :ANY, subject_id: ""}]
  end

  defp format_subject_rule(subject_rule = %{type: _}) do
    subject_rule
    |> Map.update(:type, :USER, fn value -> to_atom(value) end)
  end

  defp format_object_rules(params = %{object_rules: object_rules}, _is_create)
       when not is_nil(object_rules) do
    Map.put(
      params,
      :object_rules,
      object_rules |> Enum.map(fn rule -> format_object_rule(rule) end)
    )
  end

  defp format_object_rules(params, true) do
    Map.put(
      params,
      :object_rules,
      default_object_rules()
    )
  end

  defp format_object_rules(params, false), do: params

  defp default_object_rules() do
    [
      %{
        type: :BRANCH,
        pattern: "",
        match_mode: :ALL
      },
      %{
        type: :TAG,
        pattern: "",
        match_mode: :ALL
      },
      %{
        type: :PR,
        pattern: "",
        match_mode: :ALL
      }
    ]
  end

  defp format_object_rule(object_rule = %{type: _}) do
    object_rule
    |> Map.update(:type, :BRANCH, fn value -> to_atom(value) end)
    |> Map.update(:match_mode, :ALL, fn value -> to_atom(value) end)
  end

  defp format_cursor_type(params), do: to_atom(params[:cursor_type] || :FIRST)

  defp check_subject_rules(
         request = %{
           target:
             target = %{
               organization_id: org_id,
               project_id: project_id
             }
         }
       ) do
    LogTee.debug(
      request,
      "DeploymentsClient.check_subject_rules 1"
    )

    if target[:subject_rules],
      do: check_subject_rules_(request, target.subject_rules, org_id, project_id),
      else: {:ok, request}
  end

  defp check_subject_rules(
         _request = %{
           target: %{
             subject_rules: _subject_rules
           }
         }
       ),
       do: ToTuple.user_error("invalid request, missing project or organization id")

  defp check_subject_rules(request), do: request

  defp check_subject_rules_(request = %{target: _target}, subject_rules, org_id, project_id) do
    LogTee.debug(
      request,
      "DeploymentsClient.check_subject_rules_ subject_rules=#{inspect(subject_rules)}"
    )

    with subject_rules <- verify_subject_rules(subject_rules),
         {:ok, subject_rules} <- check_subject_rules_roles(subject_rules, org_id),
         {:ok, subject_rules} <- check_subject_rules_users(subject_rules, org_id, project_id) do
      ToTuple.ok(replace_target_subject_rules(request, subject_rules))
    else
      error -> error
    end
  end

  defp replace_target_subject_rules(
         request = %{target: target = %{subject_rules: _}},
         subject_rules
       ) do
    request |> Map.put(:target, Map.put(target, :subject_rules, subject_rules))
  end

  defp verify_subject_rules(subject_rules) do
    LogTee.debug(
      subject_rules,
      "DeploymentsClient.verify_subject_rules"
    )

    try do
      subject_rules
      |> Enum.into([], &verify_subject_rule(&1))
    catch
      error ->
        LogTee.error(error, "DeploymentsClient.verify_subject_rules error caught")
        error
    end
  end

  defp verify_subject_rule(rule) do
    case {rule[:type], rule[:subject_id], rule[:git_login]} do
      {nil, _, _} ->
        raise ToTuple.user_error("invalid subject rule")

      {:USER, nil, nil} ->
        raise ToTuple.user_error("invalid subject rule, user missing both id and git login")

      {:ROLE, nil, _} ->
        raise ToTuple.user_error("invalid subject rule, role missing subject_id")

      {:GROUP, nil, _} ->
        raise ToTuple.user_error("invalid subject rule, group missing subject_id")

      _ ->
        rule
    end
  end

  defp check_subject_rules_roles(subject_rules, org_id) when is_list(subject_rules) do
    LogTee.debug(
      subject_rules,
      "DeploymentsClient.check_subject_rules_roles"
    )

    subject_rules
    |> Enum.filter(fn subject_rule -> subject_rule.type == :ROLE end)
    |> Enum.into(%{}, fn subject_rule ->
      {String.downcase(subject_rule.subject_id), true}
    end)
    |> check_role_subject_ids(org_id, subject_rules)
  end

  defp check_subject_rules_roles(subject_rules, _org_id), do: ToTuple.ok(subject_rules)

  defp check_role_subject_ids(roles = %{}, org_id, subject_rules) when map_size(roles) > 0 do
    LogTee.debug(
      subject_rules,
      "DeploymentsClient.check_role_subject_ids, roles=#{inspect(roles)}"
    )

    with {:ok, project_scope_roles} <- RBACClient.list_project_scope_roles(%{org_id: org_id}),
         project_scope_roles_map <- role_name_to_role_map(project_scope_roles) do
      normalize_role_names(subject_rules, roles, project_scope_roles_map)
    else
      error ->
        LogTee.error(
          error,
          "DeploymentsClient.check_role_subject_ids error caught"
        )

        error
    end
  end

  defp check_role_subject_ids(_roles = %{}, _org_id, subject_rules), do: ToTuple.ok(subject_rules)

  defp check_role_subject_ids(error, _org_id, _subject_rules), do: error

  defp role_name_to_role_map(project_scope_roles) do
    Enum.into(project_scope_roles, %{}, fn role ->
      {String.downcase(role.name), role.name}
    end)
  end

  defp normalize_role_names(subject_rules, roles, project_scope_roles_map) do
    case Enum.find(roles, fn {role_name, _v} ->
           not Map.has_key?(project_scope_roles_map, role_name)
         end) do
      nil -> normalize_roles(subject_rules, project_scope_roles_map) |> ToTuple.ok()
      {role_name, _} -> ToTuple.user_error("role #{inspect(role_name)} is not valid")
      _ -> ToTuple.internal_error("internal error")
    end
  end

  defp normalize_roles(subject_rules, roles_map) do
    subject_rules
    |> Enum.into([], fn subject_rule ->
      case subject_rule do
        %{type: :ROLE, subject_id: subject_id} ->
          %{type: :ROLE, subject_id: roles_map[String.downcase(subject_id)] || subject_id}

        rule ->
          rule
      end
    end)
  end

  defp check_subject_rules_users(subject_rules, org_id, project_id)
       when is_list(subject_rules) and length(subject_rules) > 0 do
    LogTee.debug(
      subject_rules,
      "DeploymentsClient.check_subject_rules_users"
    )

    with {:ok, subject_rules} <- translate_user_handles(subject_rules, org_id, project_id),
         {:ok, members} <-
           RBACClient.list_project_members(%{org_id: org_id, project_id: project_id}),
         member_id_map <- member_id_to_member_map(members) do
      normalize_subject_rules_users(subject_rules, member_id_map, project_id, org_id)
    else
      error ->
        LogTee.error(
          error,
          "DeploymentsClient.check_subject_rules_users error caught"
        )

        error
    end
  end

  defp check_subject_rules_users(subject_rules, _org_id, _project_id),
    do: ToTuple.ok(subject_rules)

  defp member_id_to_member_map(members) do
    Enum.into(members, %{}, fn member ->
      {String.downcase(member.subject.subject_id), member}
    end)
  end

  defp normalize_subject_rules_users(subject_rules, member_id_map, project_id, org_id) do
    find_missing_id = Enum.find(subject_rules, &is_missing_user_id(&1, member_id_map))

    case find_missing_id do
      nil ->
        ToTuple.ok(normalize_users(subject_rules, member_id_map))

      %{type: :USER, subject_id: subject_id} ->
        ToTuple.user_error(
          "user #{inspect(subject_id)} can't be added to subject rules for project #{inspect(project_id)} and organization #{inspect(org_id)}"
        )

      %{type: :USER} ->
        ToTuple.user_error("invalid subject rule")

      error = {:error, {:user, _}} ->
        LogTee.error(
          error,
          "DeploymentsClient.check_subject_rules_users invalid subject rule"
        )

        error

      error ->
        LogTee.error(
          error,
          "DeploymentsClient.check_subject_rules_users unexpected error"
        )

        error
    end
  end

  defp is_missing_user_id(rule, member_id_map) do
    rule[:type] == :USER and
      (rule[:subject_id] == nil or
         member_id_map[String.downcase(rule.subject_id)] == nil)
  end

  defp translate_user_handles(subject_rules, org_id, project_id) do
    rule_missing_user_identification =
      Enum.find(subject_rules, fn rule -> subject_rule_missing_user_identifier(rule) end)

    case rule_missing_user_identification do
      nil ->
        translate_user_handles_(subject_rules, org_id, project_id)

      _ ->
        ToTuple.user_error("subject_id or git_login must be provided for USER type subject rule")
    end
  end

  defp subject_rule_missing_user_identifier(rule) do
    to_atom(rule[:type]) == :USER and rule[:subject_id] == nil and rule[:git_login] == nil
  end

  defp translate_user_handles_(subject_rules, org_id, project_id) do
    subject_rules
    |> Enum.filter(fn rule ->
      to_atom(rule[:type]) == :USER and rule[:subject_id] == nil
    end)
    |> Enum.into(%{}, fn rule -> {rule[:git_login], nil} end)
    |> populate_user_handles(subject_rules, org_id, project_id)
  end

  defp populate_user_handles(git_logins, subject_rules, org_id, project_id)
       when map_size(git_logins) > 0 do
    with {:ok, members} <-
           RBACClient.list_project_members(%{org_id: org_id, project_id: project_id}),
         login_to_member_map <- create_login_to_member_map(members) do
      populate_user_handles_(subject_rules, login_to_member_map, git_logins)
    else
      error ->
        error
    end
  end

  defp populate_user_handles(_git_logins, subject_rules, _org_id, _project_id),
    do: ToTuple.ok(subject_rules)

  defp populate_user_handles_(subject_rules, login_to_member_map, git_logins) do
    case Enum.find(git_logins, fn {login, _} ->
           not Map.has_key?(login_to_member_map, login)
         end) do
      nil ->
        Enum.into(subject_rules, [], &normalize_rule(&1, login_to_member_map)) |> ToTuple.ok()

      {login, _} ->
        ToTuple.user_error("handle #{login} can't be used as subject id")
    end
  end

  defp normalize_rule(rule, login_to_member_map) do
    case {rule[:type], rule[:subject_id], rule[:git_login]} do
      {nil, _, _} ->
        rule

      {:USER, nil, nil} ->
        raise ToTuple.user_error("invalid subject rule")

      {:USER, nil, git_login} ->
        Map.put(
          rule,
          :subject_id,
          login_to_member_map[git_login]
        )

      {_, nil, _} ->
        rule

      {_, _, _} ->
        rule
    end
  end

  defp create_login_to_member_map(members) do
    LogTee.debug(
      members,
      "DeploymentsClient.create_login_to_member_map"
    )

    Enum.reduce(members_to_users(members), %{}, fn user, acc ->
      try do
        case {user[:id], Enum.find(user[:repository_providers], &(&1[:login] != nil))} do
          {user_id, %{login: login}} ->
            Map.put(acc, login, user_id)

          _ ->
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

  defp normalize_users(subject_rules, members_id_map) do
    LogTee.debug(
      subject_rules,
      "DeploymentsClient.normalize_users, members_id_map=#{inspect(members_id_map)}"
    )

    subject_rules
    |> Enum.into([], fn subject_rule ->
      case subject_rule do
        %{type: :USER, subject_id: subject_id} ->
          %{
            type: :USER,
            subject_id: members_id_map[String.downcase(subject_id)].subject.subject_id
          }

        rule ->
          rule
      end
    end)
  end

  defp to_atom(value) when is_atom(value), do: value
  defp to_atom(value) when is_integer(value), do: value

  defp to_atom(value) when is_binary(value) do
    case Integer.parse(value) do
      {val, _} ->
        val

      _ ->
        value |> String.upcase() |> String.to_existing_atom()
    end
  end

  defp to_int(val, _field) when is_integer(val), do: val

  defp to_int(val, field) do
    case Integer.parse(val) do
      {val, _} ->
        val

      _ ->
        "Invalid value of '#{field}' param: #{inspect(val)} - needs to be integer."
        |> ToTuple.user_error()
        |> throw()
    end
  end

  defp is_cordoned(mode) when is_boolean(mode) do
    mode
  end

  defp is_cordoned(mode) when is_binary(mode) do
    case String.downcase(mode) do
      m when m in ["true", "on", "block", "cordon"] -> true
      m when m in ["false", "off", "unblock", "uncordon"] -> false
    end
  end

  defp check_env_var({name, value}, old_env_vars) do
    with true <- Map.has_key?(old_env_vars, name),
         old_value_md5 <- md5_checksum(old_env_vars[name]),
         true <- String.downcase(value) == old_value_md5 do
      %{name: name, value: old_env_vars[name]}
    else
      _ -> %{name: name, value: value}
    end
  end

  defp check_file({path, content}, old_files) do
    with true <- Map.has_key?(old_files, path),
         old_value_md5 <- md5_checksum(old_files[path]),
         true <- String.downcase(content) == old_value_md5 do
      %{path: path, content: old_files[path]}
    else
      _ -> %{path: path, content: content}
    end
  end

  defp md5_checksum(secret) when is_binary(secret), do: Validator.hide_secret(secret)

  defp md5_checksum(secret), do: secret

  def convert_keys_to_atoms(map) when is_map(map) do
    Enum.into(map, %{}, fn {key, value} ->
      if is_binary(key),
        do: {String.to_atom(key), convert_keys_to_atoms(value)},
        else: {key, convert_keys_to_atoms(value)}
    end)
  end

  def convert_keys_to_atoms(list) when is_list(list) do
    Enum.into(list, [], fn value ->
      convert_keys_to_atoms(value)
    end)
  end

  def convert_keys_to_atoms(value), do: value

  ### Data Verification

  defp verify_list_request(params) do
    VD.verify(VD.is_valid_uuid?(params[:project_id]), "project id must be a valid UUID")
  end

  defp verify_create_request(params) do
    VD.verify(VD.is_valid_uuid?(params[:unique_token]), "unique_token must be a valid UUID")
    |> VD.verify(
      VD.is_string_length?(params[:name], 1, 255),
      "name must be string with length between 1 and 255"
    )
    |> VD.verify(VD.is_valid_uuid?(params[:project_id]), "project id must be a valid UUID")
  end

  defp verify_update_request(params) do
    VD.verify(VD.is_valid_uuid?(params[:unique_token]), "unique_token must be a valid UUID")
    |> VD.verify(
      VD.is_string_length?(params[:name], 1, 255),
      "name must be string with length between 1 and 255"
    )
    |> VD.verify(VD.is_valid_uuid?(params[:project_id]), "project id must be a valid UUID")
    |> VD.verify(VD.is_valid_uuid?(params[:id]), "target id must be a valid UUID")
    |> VD.verify(VD.is_valid_uuid?(params[:target_id]), "target id must be a valid UUID")
  end

  defp verify_delete_request(params) do
    VD.verify(VD.is_valid_uuid?(params[:unique_token]), "unique_token must be a valid UUID")
    |> VD.verify(VD.is_valid_uuid?(params[:target_id]), "target_id must be a valid UUID")
  end

  defp verify_describe_request(params) do
    VD.verify(VD.is_valid_uuid?(params[:project_id]), "project_id must be a valid UUID")
    |> VD.verify(
      VD.is_string_length?(params[:target_name], 1, 255),
      "target_name must be string with length between 1 and 255"
    )
    |> VD.verify(VD.is_valid_uuid?(params[:target_id]), "target_id must be a valid UUID")
    |> VD.verify(VD.is_valid_uuid?(params[:id]), "target_id must be a valid UUID")
  end

  defp verify_history_request(params) do
    VD.verify(VD.is_valid_uuid?(params[:target_id]), "target_id must be a valid UUID")
  end
end
