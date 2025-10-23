defmodule Front.RBAC.Members do
  use TypedStruct
  require Logger

  @type subject_role_bindings :: InternalApi.RBAC.SubjectRoleBinding

  typedstruct do
    field(:id, String.t(), enforce: true)
    field(:subject_type, String.t(), enforce: true)
    field(:name, String.t(), enforce: true)

    field(:has_email, boolean(), enforce: true)
    field(:email, String.t())

    field(:has_avatar, boolean(), enforce: true)
    field(:avatar, String.t())

    field(:github_login, String.t(), default: nil)
    field(:bitbucket_login, String.t(), default: nil)
    field(:gitlab_login, String.t(), default: nil)

    field(:subject_role_bindings, list(subject_role_bindings()), enforce: true)

    field(:okta_connected, boolean(), default: false)
  end

  def list_org_members(org_id, opts \\ []), do: list_members(org_id, "", opts)
  def list_project_members(org_id, proj_id, opts \\ []), do: list_members(org_id, proj_id, opts)

  def count(org_id) do
    req = build_count_members_request(org_id)

    grpc_response =
      Front.RBAC.Client.channel()
      |> InternalApi.RBAC.RBAC.Stub.count_members(req, timeout: 30_000)

    case grpc_response do
      {:ok, resp} -> {:ok, resp.members}
      {:error, error} -> {:error, error.message}
    end
  end

  def is_org_member?(org_id, user_id),
    do: Front.RBAC.Permissions.has?(user_id, org_id, "organization.view")

  def list_accessible_orgs(user_id) do
    req = InternalApi.RBAC.ListAccessibleOrgsRequest.new(user_id: user_id)

    Front.RBAC.Client.channel()
    |> InternalApi.RBAC.RBAC.Stub.list_accessible_orgs(req)
    |> case do
      {:ok, resp} -> {:ok, resp.org_ids}
      e -> e
    end
  end

  def list_accessible_projects(org_id, user_id) do
    alias InternalApi.RBAC.ListAccessibleProjectsRequest
    alias InternalApi.RBAC.RBAC.Stub

    request =
      ListAccessibleProjectsRequest.new(
        user_id: user_id,
        org_id: org_id
      )

    endpoint = Application.fetch_env!(:front, :rbac_grpc_endpoint)

    with {:ok, channel} <- GRPC.Stub.connect(endpoint),
         {:ok, response} <- Stub.list_accessible_projects(channel, request, timeout: 30_000) do
      {:ok, response.project_ids}
    else
      e ->
        Logger.error(
          "Error listing accessible projects for org=#{org_id}, user=#{user_id}: #{inspect(e)}"
        )

        e
    end
  end

  def filter_projects(projects, org_id, user_id) do
    case list_accessible_projects(org_id, user_id) do
      {:ok, accessible_project_ids} ->
        Enum.filter(projects, fn project ->
          Enum.any?(accessible_project_ids, fn id ->
            id == project.id
          end)
        end)

      _e ->
        []
    end
  end

  defp list_members(org_id, project_id, opts) do
    Watchman.benchmark("list_members.duration", fn ->
      with(
        {:ok, {members, total_pages}} <-
          fetch_members(org_id, project_id, opts),
        {:ok, members} <- construct_members_structs(members),
        {:ok, members} <- inject_user_data(members),
        {:ok, members} <- inject_okta_data(members, org_id)
      ) do
        {:ok, {members, total_pages}}
      end
    end)
  end

  @default_page_size 20
  defp fetch_members(org_id, project_id, opts) do
    alias InternalApi.RBAC.SubjectType, as: Type

    member_type =
      opts[:member_type]
      |> case do
        "group" -> Type.value(:GROUP)
        "service_account" -> Type.value(:SERVICE_ACCOUNT)
        # assume user if not specified
        _ -> Type.value(:USER)
      end

    req =
      build_list_members_request(org_id, project_id,
        username: opts[:username],
        role_id: opts[:role_id],
        page_no: opts[:page_no],
        page_size: opts[:page_size],
        member_type: member_type
      )

    Front.RBAC.Client.channel()
    |> InternalApi.RBAC.RBAC.Stub.list_members(req)
    |> case do
      {:ok, resp} -> {:ok, {resp.members, resp.total_pages}}
      e -> e
    end
  end

  defp build_list_members_request(org_id, project_id, opts) do
    InternalApi.RBAC.ListMembersRequest.new(
      org_id: org_id,
      project_id: project_id,
      member_type: opts[:member_type],
      member_name_contains: opts[:username] || "",
      member_has_role: opts[:role_id] || "",
      page:
        InternalApi.RBAC.ListMembersRequest.Page.new(
          page_no: opts[:page_no] || 0,
          page_size: opts[:page_size] || @default_page_size
        )
    )
  end

  defp build_count_members_request(org_id),
    do: InternalApi.RBAC.CountMembersRequest.new(org_id: org_id)

  defp construct_members_structs(members) do
    alias InternalApi.RBAC.SubjectType, as: Type

    members =
      Enum.map(members, fn member ->
        subject_type =
          member.subject.subject_type
          |> Type.key()
          |> Atom.to_string()
          |> String.downcase()

        struct!(__MODULE__,
          id: member.subject.subject_id,
          subject_type: subject_type,
          name: member.subject.display_name,
          has_email: false,
          has_avatar: false,
          subject_role_bindings: member.subject_role_bindings
        )
      end)

    {:ok, members}
  end

  defp inject_user_data(members) do
    ids = members |> Enum.map(fn m -> m.id end)
    users = Front.Models.User.find_many(ids)

    members =
      Enum.map(members, fn member ->
        user = Enum.find(users, fn user -> user.id == member.id end)

        if user do
          Map.merge(member, %{
            has_email: true,
            email: user.email,
            has_avatar: true,
            avatar: user.avatar_url,
            github_login: user.github_login,
            bitbucket_login: user.bitbucket_login,
            gitlab_login: user.gitlab_login
          })
        else
          member
        end
      end)

    {:ok, members}
  end

  defp inject_okta_data(members, org_id) do
    if FeatureProvider.feature_enabled?(:rbac__saml, param: org_id) do
      case Front.Models.OktaIntegration.get_okta_members(org_id) do
        {:ok, user_ids} ->
          members =
            members
            |> Enum.map(fn member ->
              if member.id in user_ids do
                member |> Map.put(:okta_connected, true)
              else
                member
              end
            end)

          {:ok, members}

        {:error, _} ->
          {:ok, members}
      end
    else
      {:ok, members}
    end
  end
end
