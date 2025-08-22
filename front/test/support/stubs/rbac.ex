defmodule Support.Stubs.RBAC do
  alias Support.Stubs.{
    DB,
    Feature,
    UUID
  }

  require Logger

  @nil_uuid "00000000-0000-0000-0000-000000000000"
  @default_org_id "92be62c2-9cf4-4dad-b168-d6efa6aa5e21"

  @organization_permissions [
    "organization.okta.view",
    "organization.okta.manage",
    "organization.contact_support",
    "organization.delete",
    "organization.view",
    "organization.instance_git_integration.manage",
    "organization.secrets_policy_settings.manage",
    "organization.secrets_policy_settings.view",
    "organization.activity_monitor.view",
    "organization.projects.create",
    "organization.audit_logs.view",
    "organization.audit_logs.manage",
    "organization.people.view",
    "organization.people.invite",
    "organization.people.manage",
    "organization.change_owner",
    "organization.groups.view",
    "organization.groups.manage",
    "organization.custom_roles.manage",
    "organization.self_hosted_agents.view",
    "organization.self_hosted_agents.manage",
    "organization.general_settings.view",
    "organization.general_settings.manage",
    "organization.secrets.view",
    "organization.secrets.manage",
    "organization.ip_allow_list.view",
    "organization.ip_allow_list.manage",
    "organization.notifications.view",
    "organization.notifications.manage",
    "organization.pre_flight_checks.view",
    "organization.pre_flight_checks.manage",
    "organization.plans_and_billing.view",
    "organization.plans_and_billing.manage",
    "organization.repo_to_role_mappers.manage",
    "organization.dashboards.view",
    "organization.dashboards.manage",
    "organization.service_accounts.view",
    "organization.service_accounts.manage"
  ]

  @project_permissions [
    "project.view",
    "project.delete",
    "project.access.view",
    "project.access.manage",
    "project.secrets.view",
    "project.secrets.manage",
    "project.notifications.view",
    "project.notifications.manage",
    "project.insights.view",
    "project.insights.manage",
    "project.flaky_tests.view",
    "project.flaky_tests.manage",
    "project.artifacts.view",
    "project.artifacts.delete",
    "project.artifacts.view_settings",
    "project.artifacts.modify_settings",
    "project.scheduler.view",
    "project.scheduler.manage",
    "project.scheduler.run_manually",
    "project.general_settings.view",
    "project.general_settings.manage",
    "project.repository_info.view",
    "project.repository_info.manage",
    "project.deployment_targets.view",
    "project.deployment_targets.manage",
    "project.pre_flight_checks.view",
    "project.pre_flight_checks.manage",
    "project.workflow.manage",
    "project.job.rerun",
    "project.job.stop",
    "project.job.attach"
  ]

  def init do
    DB.add_table(:rbac_roles, [
      :id,
      :name,
      :org_id,
      :scope_id,
      :description,
      :maps_to_id,
      :permission_ids,
      :readonly
    ])

    DB.add_table(:scopes, [:id, :scope_name])

    DB.add_table(:subject_role_bindings, [:id, :subject_id, :org_id, :role_id, :project_id])

    DB.add_table(:subjects, [:id, :name, :type])

    DB.add_table(:permissions, [:id, :name, :description, :scope_id])

    seed_data()
    __MODULE__.Grpc.init()
  end

  def seed_data do
    org_scope_entity =
      DB.insert(:scopes, %{
        id: UUID.gen(),
        scope_name: "org_scope"
      })

    project_scope_entity =
      DB.insert(:scopes, %{
        id: UUID.gen(),
        scope_name: "project_scope"
      })

    # Insert permissions

    Enum.each(@organization_permissions, fn permission_name ->
      DB.insert(:permissions, %{
        id: UUID.gen(),
        name: permission_name,
        description: "Mock description",
        scope_id: org_scope_entity.id
      })
    end)

    Enum.each(@project_permissions, fn permission_name ->
      DB.insert(:permissions, %{
        id: UUID.gen(),
        name: permission_name,
        description: "Mock description",
        scope_id: project_scope_entity.id
      })
    end)

    org_view_permission_id = DB.find_by(:permissions, :name, "organization.view").id
    project_view_permission_id = DB.find_by(:permissions, :name, "project.view").id

    # Insert default roles

    default_project_roles = [
      %{
        name: "Admin",
        description:
          "Admins have the authority to modify any setting within the projects, including the ability to add new individuals, remove them, or even delete the entire project."
      },
      %{
        name: "Contributor",
        description:
          "Can view, rerun, change workflows and ssh into jobs. Can promote and view insights, schedulers, etc."
      },
      %{
        name: "Reader",
        description:
          "Readers can access the project page, view workflows, their results, and job logs. However, they cannot make any modifications within the project."
      }
    ]

    default_org_roles = [
      %{
        name: "Owner",
        description:
          "Owners have access to all functionalities within the organization and any of its projects. They cannot be removed from the organization."
      },
      %{
        name: "Member",
        description:
          "Members can access the organization's homepage and the projects they are assigned to. However, they are not able to modify any settings."
      },
      %{
        name: "Admin",
        description:
          "Admins can modify settings within the organization or any of its projects. However, they do not have access to billing information, and they cannot change general organization details, such as the organization name and URL."
      }
    ]

    Enum.each(default_project_roles, fn role ->
      DB.insert(:rbac_roles, %{
        id: UUID.gen(),
        name: role.name,
        org_id: @nil_uuid,
        description: role.description,
        scope_id: project_scope_entity.id,
        maps_to_id: nil,
        permission_ids: [project_view_permission_id],
        readonly: true
      })
    end)

    Enum.each(default_org_roles, fn role ->
      DB.insert(:rbac_roles, %{
        id: UUID.gen(),
        name: role.name,
        org_id: @nil_uuid,
        description: role.description,
        scope_id: org_scope_entity.id,
        maps_to_id: nil,
        permission_ids: [org_view_permission_id],
        readonly: true
      })
    end)

    users = [
      "Test Test the 3rd",
      "Test Test the 4th",
      "Test Test the 5th",
      "Test Test the 6th",
      "Jacob Bannon",
      "Dimitri Minakakis"
    ]

    # Assign member roles within the default org
    for user <- users do
      u = Support.Stubs.User.create(name: user, username: user)

      add_member(@default_org_id, u.id, nil)
    end

    service_accounts = [
      "Robot #1",
      "Robot #2",
      "Robot #3"
    ]

    for service_account_name <- service_accounts do
      {:ok, {service_account, _}} =
        Front.ServiceAccount.create(
          @default_org_id,
          service_account_name,
          "Service account for testing",
          ""
        )

      add_service_account(@default_org_id, service_account)
    end

    # Enable okta (includes rbac as well) for rtx
    Feature.enable_feature(@default_org_id, "rbac__saml")
  end

  def add_role(org_id, name, scope_arg, params \\ []) do
    view_permission_id =
      case scope_arg do
        "org_scope" -> DB.find_by(:permissions, :name, "organization.view").id
        "project_scope" -> DB.find_by(:permissions, :name, "project.view").id
      end

    other_permission_ids = Enum.map(params[:permissions] || [], &permission_id_from_arg/1)
    readonly = if is_boolean(params[:readonly]), do: params[:readonly], else: false

    DB.insert(:rbac_roles, %{
      id: UUID.gen(),
      name: name,
      org_id: org_id,
      scope_id: scope_id_from_arg(scope_arg),
      description: params[:description] || "",
      maps_to_id: params[:maps_to] || nil,
      permission_ids: [view_permission_id | other_permission_ids],
      readonly: readonly
    })
  end

  def add_permission(name, description, scope_arg) do
    DB.insert(:permissions, %{
      id: UUID.gen(),
      name: name,
      description: description,
      scope_id: scope_id_from_arg(scope_arg)
    })
  end

  defp permission_id_from_arg(permission) when is_map(permission) do
    if Map.has_key?(permission, :id),
      do: permission.id,
      else: raise("Permission id not found")
  end

  defp permission_id_from_arg(permission) when is_binary(permission) do
    case Elixir.UUID.info(permission) do
      {:ok, _info} -> permission
      {:error, _msg} -> permission_id_from_name(permission)
    end
  end

  defp permission_id_from_name(permission_name) do
    case DB.find_by(:permissions, :name, permission_name) do
      nil -> raise "Permission not found"
      permission -> permission.id
    end
  end

  defp scope_id_from_arg(scope_arg) do
    case Elixir.UUID.info(scope_arg) do
      {:ok, _info} -> scope_arg
      {:error, _msg} -> scope_id_from_name(scope_arg)
    end
  end

  def scope_id_from_name(scope_name) do
    case DB.find_by(:scopes, :scope_name, scope_name) do
      nil -> raise "Scope not found"
      scope -> scope.id
    end
  end

  def delete_member(org_id, user_id) do
    case DB.filter(:subject_role_bindings, subject_id: user_id, org_id: org_id) do
      [] ->
        :ok

      [binding] ->
        Support.Stubs.DB.delete(:subject_role_bindings, binding.id)
    end
  end

  def add_member(org_id, user_id, project_id \\ nil)

  def add_member(org_id, user_id, nil) do
    DB.insert(:subject_role_bindings, %{
      id: UUID.gen(),
      org_id: org_id,
      subject_id: user_id,
      role_id: member_role_id(),
      project_id: nil
    })
  end

  def add_member(org_id, user_id, project_id) do
    DB.insert(:subject_role_bindings, %{
      id: UUID.gen(),
      org_id: org_id,
      subject_id: user_id,
      role_id: contributor_role_id(),
      project_id: project_id
    })
  end

  def add_owner(org_id, user_id) do
    DB.insert(:subject_role_bindings, %{
      id: UUID.gen(),
      org_id: org_id,
      subject_id: user_id,
      role_id: owner_role_id(),
      project_id: nil
    })
  end

  def add_service_account(org_id, service_account) do
    DB.insert(:subjects, %{
      id: service_account.id,
      name: service_account.name,
      type: "service_account"
    })

    DB.insert(:subject_role_bindings, %{
      id: UUID.gen(),
      org_id: org_id,
      subject_id: service_account.id,
      role_id: member_role_id(),
      project_id: nil
    })
  end

  def member_role_id do
    DB.find_all_by(:rbac_roles, :name, "Member") |> List.first() |> Map.get(:id)
  end

  def owner_role_id do
    DB.find_all_by(:rbac_roles, :name, "Owner") |> List.first() |> Map.get(:id)
  end

  def contributor_role_id do
    DB.find_all_by(:rbac_roles, :name, "Contributor") |> List.first() |> Map.get(:id)
  end

  def add_group(org_id, group_name, group_id) do
    DB.insert(:subjects, %{
      type: "group",
      id: group_id,
      name: group_name
    })

    DB.insert(:subject_role_bindings, %{
      id: UUID.gen(),
      org_id: org_id,
      subject_id: group_id,
      role_id: member_role_id(),
      project_id: nil
    })
  end

  defmodule Grpc do
    def init do
      GrpcMock.stub(RBACMock, :list_roles, &__MODULE__.list_roles/2)
      GrpcMock.stub(RBACMock, :assign_role, &__MODULE__.assign_role/2)
      GrpcMock.stub(RBACMock, :list_members, &__MODULE__.list_members/2)
      GrpcMock.stub(RBACMock, :count_members, &__MODULE__.count_members/2)
      GrpcMock.stub(RBACMock, :retract_role, &__MODULE__.retract_role/2)
      GrpcMock.stub(RBACMock, :describe_role, &__MODULE__.describe_role/2)
      GrpcMock.stub(RBACMock, :modify_role, &__MODULE__.modify_role/2)
      GrpcMock.stub(RBACMock, :destroy_role, &__MODULE__.destroy_role/2)
      GrpcMock.stub(RBACMock, :list_accessible_orgs, &__MODULE__.list_accessible_orgs/2)
      GrpcMock.stub(RBACMock, :list_accessible_projects, &__MODULE__.list_accessible_projects/2)
      GrpcMock.stub(RBACMock, :list_existing_permissions, &__MODULE__.list_existing_permissions/2)
      GrpcMock.stub(RBACMock, :refresh_collaborators, &__MODULE__.refresh_collaborators/2)
    end

    def expect(function, n \\ 1, callback) do
      GrpcMock.expect(RBACMock, function, n, fn _request, _stream ->
        callback.()
      end)

      ExUnit.Callbacks.on_exit(fn ->
        __MODULE__.init()
      end)
    end

    def retract_role(req, _) do
      raise_if_unauthenticated(req.requester_id)

      org_id = req.role_assignment.org_id
      project_id = req.role_assignment.project_id
      subject_id = req.role_assignment.subject.subject_id

      for_removal =
        if project_id == "" do
          DB.all(:subject_role_bindings)
          |> Enum.filter(fn srb -> srb.org_id == org_id and srb.subject_id == subject_id end)
        else
          DB.all(:subject_role_bindings)
          |> Enum.filter(fn srb ->
            srb.org_id == org_id and srb.subject_id == subject_id and srb.project_id == project_id
          end)
        end

      Enum.each(for_removal, fn srb -> DB.delete(:subject_role_bindings, srb.id) end)

      InternalApi.RBAC.RetractRoleResponse.new()
    end

    def count_members(%{org_id: org_id}, _) do
      alias InternalApi.RBAC

      org_subject_role_bindings_count =
        DB.find_all_by(:subject_role_bindings, :org_id, org_id)
        |> Stream.filter(fn binding -> binding.project_id == nil end)
        |> Enum.count()

      RBAC.CountMembersResponse.new(count: org_subject_role_bindings_count)
    end

    def list_members(
          %{
            org_id: org_id,
            project_id: project_id,
            member_name_contains: member_name_contains,
            member_type: member_type,
            page: page
          },
          _
        ) do
      alias InternalApi.RBAC

      page_size = Application.get_env(:front, :test_page_size) || page.page_size
      project_id = if project_id == "", do: nil, else: project_id

      all_org_subject_role_bindings =
        DB.find_all_by(:subject_role_bindings, :org_id, org_id)
        |> Enum.filter(fn binding -> binding.project_id == project_id end)

      subject_grouped_role_bindings =
        Enum.group_by(all_org_subject_role_bindings, & &1.subject_id)

      string_member_type =
        RBAC.SubjectType.key(member_type) |> Atom.to_string() |> String.downcase()

      members =
        Enum.map(subject_grouped_role_bindings, fn {subject_id, bindings} ->
          user =
            DB.filter(:subjects, &(&1.id == subject_id and &1.type == string_member_type))
            |> List.first()

          if !is_nil(user) and
               (member_name_contains == "" ||
                  String.downcase(user.name) =~ String.downcase(member_name_contains)) do
            RBAC.ListMembersResponse.Member.new(
              subject:
                RBAC.Subject.new(
                  subject_type: member_type,
                  subject_id: user.id,
                  display_name: user.name
                ),
              subject_role_bindings:
                Enum.map(bindings, fn binding ->
                  role = DB.find_by(:rbac_roles, :id, binding.role_id)

                  RBAC.SubjectRoleBinding.new(
                    role:
                      RBAC.Role.new(
                        id: role.id,
                        name: role.name
                      ),
                    source: RBAC.RoleBindingSource.value(:ROLE_BINDING_SOURCE_MANUALLY)
                  )
                end)
            )
          else
            nil
          end
        end)
        |> Enum.filter(& &1)

      paginated_members =
        members
        |> Enum.sort_by(& &1.subject.display_name)
        |> Enum.chunk_every(page_size)
        |> Enum.at(page.page_no, [])

      RBAC.ListMembersResponse.new(
        members: paginated_members,
        total_pages:
          (length(members) / page_size)
          |> Float.ceil()
          |> round()
      )
    end

    def list_roles(req, _) do
      # We are ignoring req.org_id and returning all roles as if they belog to
      # to the org in request.
      roles = DB.all(:rbac_roles)

      roles =
        case InternalApi.RBAC.Scope.key(req.scope) do
          :SCOPE_UNSPECIFIED ->
            roles

          :SCOPE_ORG ->
            scope_id = DB.find_by(:scopes, :scope_name, "org_scope").id
            roles |> Enum.filter(&(&1.scope_id == scope_id))

          :SCOPE_PROJECT ->
            scope_id = DB.find_by(:scopes, :scope_name, "project_scope").id
            roles |> Enum.filter(&(&1.scope_id == scope_id))
        end

      grpc_roles = generate_internal_api_roles(roles)
      InternalApi.RBAC.ListRolesResponse.new(roles: grpc_roles)
    end

    def describe_role(req, _) do
      role = DB.find(:rbac_roles, req.role_id)

      if role == nil do
        raise(GRPC.RPCError,
          status: GRPC.Status.not_found(),
          message: "Role not found"
        )
      else
        InternalApi.RBAC.DescribeRoleResponse.new(role: to_api_role(role))
      end
    end

    def modify_role(req, _) do
      role_id = if req.role.id == "", do: UUID.gen(), else: req.role.id

      role =
        DB.upsert(:rbac_roles, %{
          id: role_id,
          name: req.role.name,
          description: req.role.description,
          scope_id:
            case InternalApi.RBAC.Scope.key(req.role.scope) do
              :SCOPE_UNSPECIFIED ->
                ""

              :SCOPE_ORG ->
                DB.find_by(:scopes, :scope_name, "org_scope").id

              :SCOPE_PROJECT ->
                DB.find_by(:scopes, :scope_name, "project_scope").id
            end,
          org_id: req.role.org_id,
          maps_to_id: req.role.maps_to && req.role.maps_to.id,
          permission_ids: Enum.into(req.role.rbac_permissions, [], & &1.id),
          readonly: false
        })

      InternalApi.RBAC.ModifyRoleResponse.new(role: to_api_role(role))
    end

    def destroy_role(req, _) do
      DB.delete(:rbac_roles, req.role_id)
      InternalApi.RBAC.DestroyRoleResponse.new(role_id: req.role_id)
    end

    def list_existing_permissions(req, _) do
      alias Support.Stubs.RBAC, as: Stub

      permissions =
        case InternalApi.RBAC.Scope.key(req.scope) do
          :SCOPE_UNSPECIFIED ->
            DB.all(:permissions)

          :SCOPE_ORG ->
            DB.find_all_by(:permissions, :scope_id, Stub.scope_id_from_name("org_scope"))

          :SCOPE_PROJECT ->
            DB.find_all_by(:permissions, :scope_id, Stub.scope_id_from_name("project_scope"))
        end

      InternalApi.RBAC.ListExistingPermissionsResponse.new(
        permissions: Enum.map(permissions, &to_api_permission/1)
      )
    end

    def assign_role(req, _) do
      raise_if_unauthenticated(req.requester_id)

      if DB.find(:rbac_roles, req.role_assignment.role_id) == nil do
        raise(GRPC.RPCError,
          status: GRPC.Status.failed_precondition(),
          message: "Error msg"
        )
      else
        project_id =
          if req.role_assignment.project_id == "" do
            nil
          else
            req.role_assignment.project_id
          end

        # If role is already assigned, remove it
        DB.filter(:subject_role_bindings, fn entity ->
          entity.subject_id == req.role_assignment.subject.subject_id and
            entity.org_id == req.role_assignment.org_id and
            (project_id == nil or entity.project_id == project_id)
        end)
        |> Enum.each(fn srb ->
          DB.delete(:subject_role_bindings, srb.id)
        end)

        DB.insert(:subject_role_bindings, %{
          id: UUID.gen(),
          subject_id: req.role_assignment.subject.subject_id,
          org_id: req.role_assignment.org_id,
          project_id: project_id,
          role_id: req.role_assignment.role_id
        })

        InternalApi.RBAC.AssignRoleResponse.new()
      end
    end

    def list_accessible_orgs(req, _) do
      subject_role_bindings =
        DB.find_all_by(:subject_role_bindings, :subject_id, req.user_id)
        |> Enum.filter(fn binding -> binding.project_id == nil end)

      InternalApi.RBAC.ListAccessibleOrgsResponse.new(
        org_ids: Enum.map(subject_role_bindings, & &1.org_id)
      )
    rescue
      _ ->
        reraise GRPC.RPCError, status: GRPC.Status.invalid_argument(), message: "Bad request"
    end

    def list_accessible_projects(req, _) do
      subject_role_bindings =
        DB.find_all_by(:subject_role_bindings, :subject_id, req.user_id)
        |> Enum.filter(fn binding -> binding.project_id != nil end)

      InternalApi.RBAC.ListAccessibleProjectsResponse.new(
        project_ids: Enum.map(subject_role_bindings, & &1.project_id)
      )
    rescue
      _ ->
        reraise GRPC.RPCError, status: GRPC.Status.invalid_argument(), message: "Bad request"
    end

    def refresh_collaborators(_req, _) do
      InternalApi.RBAC.RefreshCollaboratorsResponse.new()
    end

    ###
    ### Helpers
    ###

    def raise_if_unauthenticated(_user_id = ""),
      do: raise(GRPC.RPCError, status: GRPC.Status.unauthenticated(), message: "Unauthenticaded")

    def raise_if_unauthenticated(_user_id), do: nil

    defp generate_internal_api_roles(roles), do: Enum.map(roles, &to_api_role/1)

    defp to_api_role(nil), do: nil

    defp to_api_role(role) do
      maps_to_role = DB.find(:rbac_roles, role.maps_to_id)
      permissions = DB.find_many(:permissions, role.permission_ids)

      InternalApi.RBAC.Role.new(
        id: role.id,
        name: role.name,
        org_id: role.org_id,
        description: role.description,
        maps_to: to_api_role(maps_to_role),
        scope: scope_to_api(role.scope_id),
        rbac_permissions:
          Enum.into(permissions, [], fn permission ->
            InternalApi.RBAC.Permission.new(
              id: permission.id,
              name: permission.name,
              description: permission.description,
              scope: scope_to_api(permission.scope_id)
            )
          end),
        readonly: role.readonly
      )
    end

    defp to_api_permission(nil), do: nil

    defp to_api_permission(permission) do
      InternalApi.RBAC.Permission.new(
        id: permission.id,
        name: permission.name,
        description: permission.description,
        scope: scope_to_api(permission.scope_id)
      )
    end

    defp scope_to_api(scope_id) do
      scope = DB.find(:scopes, scope_id)

      case scope.scope_name do
        "org_scope" -> InternalApi.RBAC.Scope.value(:SCOPE_ORG)
        "project_scope" -> InternalApi.RBAC.Scope.value(:SCOPE_PROJECT)
        _ -> InternalApi.RBAC.Scope.value(:SCOPE_UNSPECIFIED)
      end
    end
  end
end
