defmodule Support.Stubs.RBAC do
  alias Support.Stubs.User
  alias Support.Stubs.{DB, UUID, Feature}
  require Logger

  @nil_uuid "00000000-0000-0000-0000-000000000000"
  @default_org_id "92be62c2-9cf4-4dad-b168-d6efa6aa5e21"
  @default_project_id "92be1234-1234-4234-8234-123456789012"

  def init do
    DB.add_table(:rbac_roles, [:id, :name, :org_id, :scope_id])

    DB.add_table(:scopes, [:id, :scope_name])

    DB.add_table(:subject_role_bindings, [:id, :subject_id, :org_id, :role_id, :project_id])

    DB.add_table(:rbac_users, [:id, :name])

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

    # Insert 4 default roles

    default_project_roles = ["Admin", "Contributor"]
    default_org_roles = ["Owner", "Member"]

    Enum.each(default_project_roles, fn role_name ->
      DB.insert(:rbac_roles, %{
        id: UUID.gen(),
        name: role_name,
        org_id: @nil_uuid,
        scope_id: project_scope_entity.id
      })
    end)

    Enum.each(default_org_roles, fn role_name ->
      DB.insert(:rbac_roles, %{
        id: UUID.gen(),
        name: role_name,
        org_id: @nil_uuid,
        scope_id: org_scope_entity.id
      })
    end)

    # Insert 2 default users

    user_1 = UUID.gen()
    user_2 = UUID.gen()

    DB.insert(:rbac_users, %{
      id: user_1,
      name: "Jacob Bannon"
    })

    DB.insert(:rbac_users, %{
      id: user_2,
      name: "Dimitri Minakakis"
    })

    user_3 = User.default_user_id()

    DB.insert(:rbac_users, %{
      id: user_3,
      name: "Milica Nerlovic"
    })

    # Assign member roles within the default org

    member_role_id = DB.find_all_by(:rbac_roles, :name, "Member") |> List.first() |> Map.get(:id)

    DB.insert(:subject_role_bindings, %{
      id: UUID.gen(),
      org_id: @default_org_id,
      subject_id: user_1,
      role_id: member_role_id,
      project_id: nil
    })

    DB.insert(:subject_role_bindings, %{
      id: UUID.gen(),
      org_id: @default_org_id,
      subject_id: user_2,
      role_id: member_role_id,
      project_id: nil
    })

    DB.insert(:subject_role_bindings, %{
      id: UUID.gen(),
      org_id: @default_org_id,
      subject_id: user_3,
      role_id: member_role_id,
      project_id: @default_project_id
    })

    # Enable okta (includes rbac as well) for rtx
    Feature.enable_feature(@default_org_id, "okta")
  end

  defmodule Grpc do
    @nil_uuid "00000000-0000-0000-0000-000000000000"
    def init do
      GrpcMock.stub(RBACMock, :list_roles, &__MODULE__.list_roles/2)
      GrpcMock.stub(RBACMock, :assign_role, &__MODULE__.assign_role/2)
      GrpcMock.stub(RBACMock, :list_members, &__MODULE__.list_members/2)
      GrpcMock.stub(RBACMock, :retract_role, &__MODULE__.retract_role/2)
    end

    def retract_role(req, _) do
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

    def list_members(
          %{
            org_id: org_id,
            project_id: project_id,
            member_name_contains: member_name_contains
          },
          _
        ) do
      project_id = if project_id == "", do: nil, else: project_id

      org_subject_role_bindings =
        DB.find_all_by(:subject_role_bindings, :org_id, org_id)
        |> Enum.filter(fn binding -> binding.project_id == project_id end)

      Logger.info("bindings: #{inspect(org_subject_role_bindings)}")

      InternalApi.RBAC.ListMembersResponse.new(
        members:
          Enum.map(org_subject_role_bindings, fn binding ->
            user = DB.find_by(:rbac_users, :id, binding.subject_id)
            role = DB.find_by(:rbac_roles, :id, binding.role_id)

            if member_name_contains == "" ||
                 String.downcase(user.name) =~ String.downcase(member_name_contains) do
              InternalApi.RBAC.ListMembersResponse.Member.new(
                subject:
                  InternalApi.RBAC.Subject.new(
                    subject_type: InternalApi.RBAC.SubjectType.value(:USER),
                    subject_id: user.id,
                    display_name: user.name
                  ),
                subject_role_bindings: [
                  InternalApi.RBAC.SubjectRoleBinding.new(
                    role:
                      InternalApi.RBAC.Role.new(
                        id: role.id,
                        name: role.name
                      )
                  )
                ]
              )
            else
              nil
            end
          end)
          |> Enum.filter(fn user -> user != nil end)
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

    def assign_role(req, _) do
      if DB.find(:rbac_roles, req.role_assignment.role_id) == nil do
        raise(GRPC.RPCError,
          status: GRPC.Status.failed_precondition(),
          message: "Error msg"
        )
      else
        DB.insert(:subject_role_bindings, %{
          id: UUID.gen(),
          subject_id: req.role_assignment.subject.subject_id,
          org_id: req.role_assignment.org_id,
          project_id: req.role_assignment.project_id,
          role_id: req.role_assignment.role_id
        })

        InternalApi.RBAC.AssignRoleResponse.new()
      end
    end

    ###
    ### Helpers
    ###

    defp generate_internal_api_roles(roles) do
      Enum.map(roles, fn role ->
        scope_of_role = DB.find(:scopes, role.scope_id)

        InternalApi.RBAC.Role.new(
          id: role.id,
          name: role.name,
          org_id: role.org_id,
          scope:
            case scope_of_role.scope_name do
              "org_scope" -> InternalApi.RBAC.Scope.value(:SCOPE_ORG)
              "project_scope" -> InternalApi.RBAC.Scope.value(:SCOPE_PROJECT)
              _ -> InternalApi.RBAC.Scope.value(:SCOPE_UNSPECIFIED)
            end
        )
      end)
    end
  end
end
