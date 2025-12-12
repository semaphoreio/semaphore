defmodule FrontWeb.PeopleView do
  use FrontWeb, :view
  require Logger

  def render("sync.json", %{collaborators: collaborators}) do
    collaborators =
      collaborators
      |> Enum.map(fn collaborator ->
        provider =
          collaborator.repository_provider.type
          |> InternalApi.User.RepositoryProvider.Type.key()
          |> Atom.to_string()
          |> String.downcase()

        %{
          avatar_url: collaborator.avatar_url,
          display_name: collaborator.display_name,
          login: collaborator.repository_provider.login,
          uid: collaborator.repository_provider.uid,
          provider: provider
        }
      end)

    %{
      collaborators: collaborators
    }
  end

  def add_people_config(conn) do
    %{
      users: %{
        providers: available_user_providers(conn.assigns.organization_id),
        create_url: url(:post, people_path(conn, :create_member, format: "json")),
        invite_url: url(:post, people_path(conn, :create, format: "json")),
        collaborators_url: url(:get, people_path(conn, :sync, format: "json"))
      }
    }
  end

  def sync_people_config(conn) do
    %{
      users: %{
        sync_url: url(:post, people_path(conn, :refresh))
      }
    }
  end

  def service_accounts_config(conn) do
    org_id = conn.assigns.organization_id
    permissions = conn.assigns.permissions

    {:ok, all_roles} = Front.RBAC.RoleManagement.list_possible_roles(org_id, "org_scope")

    # Filter roles - exclude Owner unless user has change_owner permission
    filtered_roles =
      all_roles
      |> Enum.filter(fn
        %{name: "Owner"} -> permissions["organization.change_owner"] || false
        _role -> true
      end)
      |> Enum.map(fn role ->
        %{
          id: role.id,
          name: role.name,
          description: role.description
        }
      end)

    %{
      organization_id: org_id,
      project_id: conn.assigns[:project_id],
      permissions: %{
        view: permissions["organization.service_accounts.view"] || false,
        manage: permissions["organization.service_accounts.manage"] || false
      },
      roles: filtered_roles
    }
  end

  @spec available_user_providers(org_id :: String.t()) :: [String.t()]
  defp available_user_providers(org_id) do
    [
      {"email", FeatureProvider.feature_enabled?(:email_members, param: org_id)},
      {"github",
       Front.saas?() || FeatureProvider.feature_enabled?(:github_user_provider, param: org_id)},
      {"gitlab",
       (FeatureProvider.feature_enabled?(:gitlab, param: org_id) && Front.saas?()) ||
         FeatureProvider.feature_enabled?(:gitlab_user_provider, param: org_id)},
      {"bitbucket",
       (FeatureProvider.feature_enabled?(:bitbucket, param: org_id) && Front.saas?()) ||
         FeatureProvider.feature_enabled?(:bitbucket_user_provider, param: org_id)}
    ]
    |> Enum.map(fn
      {name, true} ->
        name

      _ ->
        nil
    end)
    |> Enum.filter(& &1)
  end

  def edit_person_config(conn, member, member_type, roles, permissions) do
    filtered_roles =
      roles
      |> Enum.filter(fn
        %{name: "Owner"} -> permissions["organization.change_owner"]
        role -> role
      end)

    %{
      user: %{
        id: member.id,
        avatar: member.avatar,
        name: member.name,
        email: member.email,
        member_type: member_type,
        roles: build_roles(member, filtered_roles),
        reset_password_url:
          url(:post, people_path(conn, :reset_password, member.id, format: "json")),
        assign_role_url: url(:post, people_path(conn, :assign_role, format: "json")),
        change_email_url: url(:post, people_path(conn, :change_email, member.id, format: "json"))
      },
      meta: %{
        features: %{},
        permissions: permissions
      }
    }
  end

  defp url(method, path) do
    %{
      method: method,
      path: path
    }
  end

  def member_is_owner?(%{organization_role: "owner"}), do: true
  def member_is_owner?(_), do: false

  def member_is_admin?(%{organization_role: "admin"}), do: true
  def member_is_admin?(_), do: false

  def member_is_project_owner?(%{project_role: "owner"}), do: true
  def member_is_project_owner?(_), do: false

  def member_registered?(%{user_id: user_id}) when not is_nil(user_id), do: true
  def member_registered?(_), do: false

  def member_not_yet_registered?(%{invited_at: invited_at}) when not is_nil(invited_at), do: true
  def member_not_yet_registered?(_), do: false

  def invited_info(member) do
    if member.invited_at do
      "(Invited on #{present_invite_date(member.invited_at.seconds)})"
    else
      "(Invited)"
    end
  end

  defp present_invite_date(seconds) do
    Timex.format!(Timex.from_unix(seconds), "%b %d, %Y, %I:%M%p", :strftime)
  end

  def people_management_permissions?(org_scope?, permissions) do
    (org_scope? && permissions["organization.people.manage"]) ||
      (!org_scope? && permissions["project.access.manage"])
  end

  def show_people_management_buttons?(conn, org_scope?, permissions) do
    org_id = conn.assigns[:organization_id]

    user_has_permissions? = people_management_permissions?(org_scope?, permissions)

    feature_enabled? =
      org_scope? || FeatureProvider.feature_enabled?(:rbac__project_roles, param: org_id) ||
        Front.ce?()

    user_has_permissions? and feature_enabled?
  end

  def show_service_account_management_buttons?(conn, org_scope?, permissions) do
    # Service accounts bypass the rbac__project_roles feature flag at project level
    if org_scope? do
      show_people_management_buttons?(conn, org_scope?, permissions)
    else
      people_management_permissions?(org_scope?, permissions)
    end
  end

  def roles_action_message do
    if Front.ce?(), do: "View", else: "Manage"
  end

  def construct_role_label(role_binding) do
    binding_source = InternalApi.RBAC.RoleBindingSource.key(role_binding.source)

    case binding_source do
      source
      when source in [
             :ROLE_BINDING_SOURCE_GITHUB,
             :ROLE_BINDING_SOURCE_GITLAB,
             :ROLE_BINDING_SOURCE_BITBUCKET
           ] ->
        """
          <span class= "f6 normal ml1 ph1 br2 bg-#{map_role_to_colour(role_binding.role.name)} white bg-pattern-wave flex items-center"
            data-tippy-content="This role is automatically assigned through sync with Git repository.">
              #{git_icon(binding_source)}
              <span class="ml1">#{escape_unsafe_string(role_binding.role.name)}</span>
          </span>
        """

      :ROLE_BINDING_SOURCE_SCIM ->
        """
          <span class= "f6 normal ml1 ph1 br2 bg-#{map_role_to_colour(role_binding.role.name)} white bg-pattern-wave flex items-center"
            data-tippy-content="This role is automatically assigned through sync with your SCIM provider.">
              <span class="ml1">#{escape_unsafe_string(role_binding.role.name)}</span>
          </span>
        """

      :ROLE_BINDING_SOURCE_SAML_JIT ->
        """
          <span class= "f6 normal ml1 ph1 br2 bg-#{map_role_to_colour(role_binding.role.name)} white bg-pattern-wave flex items-center"
            data-tippy-content="This role is automatically assigned through SAML JIT provisioning settings.">
              <span class="ml1">#{escape_unsafe_string(role_binding.role.name)}</span>
          </span>
        """

      :ROLE_BINDING_SOURCE_INHERITED_FROM_ORG_ROLE ->
        """
          <span class= "f6 normal ml1 ph1 br2 bg-#{map_role_to_colour(role_binding.role.name)} white bg-pattern-wave flex items-center"
            data-tippy-content="The role was inherited through the organization role this user has.">
              <span class="ml1">#{escape_unsafe_string(role_binding.role.name)}</span>
          </span>
        """

      _ ->
        """
          <span class= "f6 normal ml1 ph1 br2 bg-#{map_role_to_colour(role_binding.role.name)} white">#{escape_unsafe_string(role_binding.role.name)}</span>
        """
    end
    |> raw()
  end

  def map_role_to_colour("Admin"), do: "blue"
  def map_role_to_colour("Contributor"), do: "green"
  def map_role_to_colour("Reader"), do: "yellow"
  def map_role_to_colour("Owner"), do: "red"
  def map_role_to_colour("Member"), do: "green"
  def map_role_to_colour("Viewer"), do: "orange"
  def map_role_to_colour("Billing Admin"), do: "purple"
  def map_role_to_colour(_), do: "cyan"

  def construct_member_avatar(member) do
    # Check if this is a service account
    is_service_account = member.subject_type == "service_account"

    if is_service_account do
      """
        <div class="w2 h2 br-100 mr2 ba b--black-50 flex items-center justify-center bg-light-gray">
          <span class="material-symbols-outlined f6 gray">smart_toy</span>
        </div>
      """
      |> raw()
    else
      avatar_url =
        if member.has_avatar do
          member.avatar
        else
          first_letter = member.name |> String.first() |> String.downcase()
          "#{assets_path()}/images/org-#{first_letter}.svg"
        end

      """
        <img src="#{avatar_url}" class="w2 h2 br-100 mr2 ba b--black-50">
      """
      |> raw()
    end
  end

  def build_roles(member, roles) do
    roles
    |> Enum.map(fn role ->
      selected? = role.name in Enum.map(member.subject_role_bindings, & &1.role.name)

      %{
        id: role.id,
        is_selected: selected?,
        role_name: role.name,
        role_description: role.description
      }
    end)
  end

  def construct_role_dropdown_option(role, member, member_type) do
    role_selected? = role.name in Enum.map(member.subject_role_bindings, & &1.role.name)

    binding_source =
      if role_selected? do
        Enum.find(member.subject_role_bindings, &(&1.role.name == role.name))
        |> Map.get(:source)
        |> InternalApi.RBAC.RoleBindingSource.key()
      else
        nil
      end

    """
    <div role_id="#{role.id}" user_id="#{member.id}" member_type="#{member_type}" name="role_button" class="#{extrapolate_role_div_class(role_selected?, binding_source)}", style="#{extrapolate_role_div_style(binding_source)}">
      <div style="flex-direction: column; display: flex;">
        #{if role_selected?,
      do: '<span class="material-symbols-outlined mr1">done</span>#{git_icon(binding_source)}',
      else: '<span class="material-symbols-outlined mr1">&nbsp;</span>'}
      </div>
      <div>
        <p class="b f5 mb0">#{escape_unsafe_string(role.name)}</p>
        <p class="f6 gray mb0 measure">#{escape_unsafe_string(role.description)}</p>
      </div>
    </div>
    """
    |> raw()
  end

  defp extrapolate_role_div_class(false, _), do: "not-selected"

  defp extrapolate_role_div_class(true, :ROLE_BINDING_SOURCE_MANUALLY),
    do: "selected can-be-retracted"

  defp extrapolate_role_div_class(true, _), do: "selected bg-pattern-wave"

  defp extrapolate_role_div_style(nil), do: ""
  defp extrapolate_role_div_style(:ROLE_BINDING_SOURCE_MANUALLY), do: ""
  defp extrapolate_role_div_style(_), do: "background-color: gray;"

  defp git_icon(:ROLE_BINDING_SOURCE_GITHUB),
    do: """
      <svg class="ml1" width="16" height="16" xmlns="http://www.w3.org/2000/svg"><path xmlns="http://www.w3.org/2000/svg" d="M8 0a8 8 0 00-2.53 15.59c.4.075.546-.172.546-.385 0-.19-.007-.693-.01-1.36-2.226.483-2.695-1.073-2.695-1.073-.364-.924-.889-1.17-.889-1.17-.726-.496.055-.486.055-.486.803.056 1.225.824 1.225.824.714 1.223 1.873.87 2.329.665.073-.517.28-.87.508-1.07-1.777-.201-3.644-.888-3.644-3.953 0-.873.311-1.588.823-2.147-.082-.202-.357-1.016.079-2.117 0 0 .671-.215 2.2.82A7.662 7.662 0 018 3.868a7.67 7.67 0 012.003.27c1.527-1.035 2.198-.82 2.198-.82.436 1.101.162 1.915.08 2.117.513.559.822 1.274.822 2.147 0 3.073-1.87 3.75-3.652 3.947.286.247.542.736.542 1.482 0 1.07-.01 1.932-.01 2.194 0 .215.145.463.55.385A8 8 0 008 0" fill="#FFF" fill-rule="evenodd"></path></svg>
    """

  defp git_icon(:ROLE_BINDING_SOURCE_BITBUCKET),
    do: """
      <svg class="ml1" width="16" height="16" xmlns="http://www.w3.org/2000/svg"><path xmlns="http://www.w3.org/2000/svg" d="m.75 1.03245833c-.14770886-.00186341-.28870022.06164481-.38515321.17353028-.096453.11188547-.13849446.26069532-.11484679.40651139l2.1225 12.885c.05458753.3254738.33499161.564766.665.567542h10.1825c.2476964.003146.4603858-.1755131.5-.420042l2.1225-13.03c.0236477-.14581607-.0183938-.29462592-.1148468-.40651139s-.2374443-.17539369-.3851532-.17348861zm8.9375 9.31254167h-3.25l-.88-4.5975h4.9175z" fill="#FFF" fill-rule="evenodd"></path></svg>
    """

  defp git_icon(:ROLE_BINDING_SOURCE_GITLAB),
    do: """
      <svg class="ml1" width="16" height="16" xmlns="http://www.w3.org/2000/svg"><path xmlns="http://www.w3.org/2000/svg" d="M5.868 2.75L8 10h8l2.132-7.25a.4.4 0 0 1 .765-.01l3.495 10.924a.5.5 0 0 1-.173.55L12 22 1.78 14.214a.5.5 0 0 1-.172-.55L5.103 2.74a.4.4 0 0 1 .765.009z" fill="#FFF" fill-rule="evenodd"></path></svg>
    """

  defp git_icon(_), do: ""

  @spec feature_state(Plug.Conn.t(), atom()) :: String.t()
  def feature_state(conn, feature) do
    cond do
      FeatureProvider.feature_enabled?(feature, param: conn.assigns.organization_id) ->
        "enabled"

      FeatureProvider.feature_zero_state?(feature, param: conn.assigns.organization_id) ->
        "zero"

      true ->
        "disabled"
    end
  end
end
