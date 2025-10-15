defmodule Rbac.OnPrem.InitTest do
  use Rbac.RepoCase
  alias InternalApi.{ResponseStatus, Organization}
  alias Google.Rpc.Status, as: RpcStatus
  import Rbac.Utils.Grpc, only: [grpc_error!: 2]

  @org_username "semaphore"

  describe "init/1" do
    test "should assign owner role to the default user" do
      System.put_env("ORGANIZATION_SEED_ORG_USERNAME", @org_username)

      status_ok = %ResponseStatus{code: :OK}

      user_id = Ecto.UUID.generate()

      %Rbac.FrontRepo.User{
        id: user_id,
        name: "John",
        email: "john@localhost"
      }
      |> Rbac.FrontRepo.insert()

      {:ok, _} = Support.Factories.RbacUser.insert(user_id)

      org_id = Ecto.UUID.generate()

      GrpcMock.stub(OrganizationMock, :describe, fn request, _ ->
        if request.org_username == @org_username do
          %Organization.DescribeResponse{
            status: status_ok,
            organization: %Organization.Organization{
              org_id: org_id,
              org_username: @org_username,
              name: "Semaphore",
              owner_id: user_id
            }
          }
        else
          grpc_error!(:not_found, "Organization not found")
        end
      end)

      Rbac.OnPrem.Init.init()

      scopes = Rbac.Repo.Scope |> Rbac.Repo.all(sort: [asc: :scope_name])
      assert length(scopes) == 2
      assert ["org_scope", "project_scope"] == Enum.map(scopes, & &1.scope_name)

      {:ok, owner_role} = Rbac.Repo.RbacRole.get_role_by_name("Owner", "org_scope", org_id)
      {:ok, rbi} = Rbac.RoleBindingIdentification.new(user_id: user_id, org_id: org_id)
      assert Rbac.RoleManagement.has_role(rbi, owner_role.id)
    end
  end

  describe "upgrade_id_providers_for_1_5/0" do
    test "should add okta to allowed_id_providers for organizations with okta integration" do
      status_ok = %ResponseStatus{code: :OK}
      grpc_status_ok = %RpcStatus{code: 0, message: ""}

      org1_id = Ecto.UUID.generate()
      org2_id = Ecto.UUID.generate()
      org3_id = Ecto.UUID.generate()

      {:ok, _integration1} = Support.Factories.OktaIntegration.insert(org_id: org1_id)
      {:ok, _integration2} = Support.Factories.OktaIntegration.insert(org_id: org2_id)

      updated_orgs = Agent.start_link(fn -> %{} end)
      {:ok, agent_pid} = updated_orgs

      GrpcMock.stub(OrganizationMock, :describe, fn request, _ ->
        cond do
          request.org_id == org1_id ->
            # Organization without okta in allowed_id_providers
            %Organization.DescribeResponse{
              status: status_ok,
              organization: %Organization.Organization{
                org_id: org1_id,
                org_username: "org1",
                name: "Organization 1",
                allowed_id_providers: ["github"]
              }
            }

          request.org_id == org2_id ->
            # Organization already with okta in allowed_id_providers
            %Organization.DescribeResponse{
              status: status_ok,
              organization: %Organization.Organization{
                org_id: org2_id,
                org_username: "org2",
                name: "Organization 2",
                allowed_id_providers: ["okta", "github"]
              }
            }

          request.org_id == org3_id ->
            # Organization with nil allowed_id_providers
            %Organization.DescribeResponse{
              status: status_ok,
              organization: %Organization.Organization{
                org_id: org3_id,
                org_username: "org3",
                name: "Organization 3",
                allowed_id_providers: nil
              }
            }

          true ->
            grpc_error!(:not_found, "Organization not found")
        end
      end)

      GrpcMock.stub(OrganizationMock, :update, fn request, _ ->
        org = request.organization

        Agent.update(agent_pid, fn state ->
          Map.put(state, org.org_id, org.allowed_id_providers)
        end)

        %Organization.UpdateResponse{
          status: grpc_status_ok,
          organization: org
        }
      end)

      Rbac.OnPrem.Init.upgrade_id_providers_for_1_5()

      updated_state = Agent.get(agent_pid, & &1)

      # org1 should have been updated to include okta
      assert Map.has_key?(updated_state, org1_id)
      assert "okta" in updated_state[org1_id]
      assert "github" in updated_state[org1_id]

      # org2 should NOT have been updated (already had okta)
      refute Map.has_key?(updated_state, org2_id)

      Agent.stop(agent_pid)
    end

    test "crashes when organization cannot be found" do
      non_existent_org_id = Ecto.UUID.generate()
      {:ok, _integration} = Support.Factories.OktaIntegration.insert(org_id: non_existent_org_id)

      GrpcMock.stub(OrganizationMock, :describe, fn _request, _ ->
        grpc_error!(:not_found, "Organization not found")
      end)

      assert {:shutdown, 1} = catch_exit(Rbac.OnPrem.Init.upgrade_id_providers_for_1_5())
    end

    test "should handle empty allowed_id_providers list" do
      status_ok = %ResponseStatus{code: :OK}
      grpc_status_ok = %RpcStatus{code: 0, message: ""}
      org_id = Ecto.UUID.generate()

      {:ok, _integration} = Support.Factories.OktaIntegration.insert(org_id: org_id)

      updated_providers = Agent.start_link(fn -> nil end)
      {:ok, agent_pid} = updated_providers

      GrpcMock.stub(OrganizationMock, :describe, fn _request, _ ->
        %Organization.DescribeResponse{
          status: status_ok,
          organization: %Organization.Organization{
            org_id: org_id,
            org_username: "test_org",
            name: "Test Organization",
            allowed_id_providers: []
          }
        }
      end)

      GrpcMock.stub(OrganizationMock, :update, fn request, _ ->
        org = request.organization
        Agent.update(agent_pid, fn _ -> org.allowed_id_providers end)

        %Organization.UpdateResponse{
          status: grpc_status_ok,
          organization: org
        }
      end)

      Rbac.OnPrem.Init.upgrade_id_providers_for_1_5()

      providers = Agent.get(agent_pid, & &1)
      assert providers == ["oidc", "api_token", "okta"]

      Agent.stop(agent_pid)
    end

    test "should handle no okta integrations" do
      assert :ok = Rbac.OnPrem.Init.upgrade_id_providers_for_1_5()
    end
  end

  describe "upgrade_roles_for_1_5/0" do
    test "updates permissions and role bindings correctly" do
      import Ecto.Query
      alias Rbac.Repo
      alias Rbac.Repo.{Permission, RbacRole, RolePermissionBinding, Scope}

      {:ok, org} =
        Rbac.FrontRepo.insert(%Rbac.FrontRepo.Organization{
          name: "Test Organization",
          username: "test_org"
        })

      org_id = org.id

      org_scope = Repo.insert!(%Scope{scope_name: "org_scope"})
      _project_scope = Repo.insert!(%Scope{scope_name: "project_scope"})

      {:ok, _view_perm} =
        Repo.insert(%Permission{
          name: "organization.service_accounts.view",
          scope_id: org_scope.id,
          description: ""
        })

      {:ok, _manage_perm} =
        Repo.insert(%Permission{
          name: "organization.service_accounts.manage",
          scope_id: org_scope.id,
          description: ""
        })

      {:ok, owner_role} =
        Repo.insert(%RbacRole{
          name: "Owner",
          scope_id: org_scope.id,
          editable: false,
          org_id: org_id
        })

      {:ok, admin_role} =
        Repo.insert(%RbacRole{
          name: "Admin",
          scope_id: org_scope.id,
          editable: false,
          org_id: org_id
        })

      initial_permissions = Repo.all(Permission)
      initial_permission_ids = initial_permissions |> Enum.map(& &1.id) |> MapSet.new()

      assert Enum.all?(initial_permissions, &(&1.description == ""))

      initial_role_bindings =
        Repo.all(RolePermissionBinding)
        |> Enum.map(&{&1.rbac_role_id, &1.permission_id})
        |> MapSet.new()

      assert {:ok, [[:ok, :ok], [:ok, :ok]]} = Rbac.OnPrem.Init.upgrade_roles_for_1_5()

      current_permissions = Repo.all(Permission)

      assert Enum.all?(
               current_permissions,
               &(not is_nil(&1.description) and &1.description != "")
             )

      # Get all permissions for Owner role
      owner_permissions =
        from(rb in RolePermissionBinding,
          join: p in Permission,
          on: rb.permission_id == p.id,
          where: rb.rbac_role_id == ^owner_role.id,
          select: p.name
        )
        |> Repo.all()
        |> MapSet.new()

      # Verify Owner has both service_accounts.manage and service_accounts.view
      assert "organization.service_accounts.manage" in owner_permissions
      assert "organization.service_accounts.view" in owner_permissions

      # Get all permissions for Admin role
      admin_permissions =
        from(rb in RolePermissionBinding,
          join: p in Permission,
          on: rb.permission_id == p.id,
          where: rb.rbac_role_id == ^admin_role.id,
          select: p.name
        )
        |> Repo.all()
        |> MapSet.new()

      # Verify Admin has both service_accounts.view and service_accounts.manage
      assert "organization.service_accounts.view" in admin_permissions
      assert "organization.service_accounts.manage" in admin_permissions

      # Verify all previous permission IDs are preserved
      current_permission_ids = Repo.all(Permission) |> Enum.map(& &1.id) |> MapSet.new()

      assert MapSet.subset?(initial_permission_ids, current_permission_ids)

      current_role_bindings =
        Repo.all(RolePermissionBinding)
        |> Enum.map(&{&1.rbac_role_id, &1.permission_id})
        |> MapSet.new()

      # Check that initial role bindings are preserved
      assert MapSet.subset?(initial_role_bindings, current_role_bindings)
    end

    test "is idempotent - can be run multiple times safely" do
      import Ecto.Query
      alias Rbac.Repo
      alias Rbac.Repo.{Permission, RbacRole, RolePermissionBinding, Scope}

      {:ok, org} =
        Rbac.FrontRepo.insert(%Rbac.FrontRepo.Organization{
          name: "Test Organization",
          username: "test_org"
        })

      org_id = org.id

      org_scope = Repo.insert!(%Scope{scope_name: "org_scope"})
      _project_scope = Repo.insert!(%Scope{scope_name: "project_scope"})

      {:ok, _view_perm} =
        Repo.insert(%Permission{
          name: "organization.service_accounts.view",
          scope_id: org_scope.id,
          description: ""
        })

      {:ok, _manage_perm} =
        Repo.insert(%Permission{
          name: "organization.service_accounts.manage",
          scope_id: org_scope.id,
          description: ""
        })

      {:ok, owner_role} =
        Repo.insert(%RbacRole{
          name: "Owner",
          scope_id: org_scope.id,
          editable: false,
          org_id: org_id
        })

      {:ok, admin_role} =
        Repo.insert(%RbacRole{
          name: "Admin",
          scope_id: org_scope.id,
          editable: false,
          org_id: org_id
        })

      # Pre-populate all permissions from YAML to ensure idempotency test is accurate
      Rbac.Repo.Permission.insert_default_permissions()

      # Run the upgrade first time
      assert {:ok, [[:ok, :ok], [:ok, :ok]]} = Rbac.OnPrem.Init.upgrade_roles_for_1_5()

      # Capture state after first run
      first_run_bindings =
        from(rb in RolePermissionBinding,
          join: p in Permission,
          on: rb.permission_id == p.id,
          select: {rb.rbac_role_id, p.name}
        )
        |> Repo.all()
        |> MapSet.new()

      first_run_permission_count = Repo.aggregate(Permission, :count, :id)
      first_run_binding_count = Repo.aggregate(RolePermissionBinding, :count, :rbac_role_id)

      # Run the upgrade second time
      {:ok, [[:ok, :ok], [:ok, :ok]]} = Rbac.OnPrem.Init.upgrade_roles_for_1_5()

      # Verify state is identical after second run
      second_run_bindings =
        from(rb in RolePermissionBinding,
          join: p in Permission,
          on: rb.permission_id == p.id,
          select: {rb.rbac_role_id, p.name}
        )
        |> Repo.all()
        |> MapSet.new()

      second_run_permission_count = Repo.aggregate(Permission, :count, :id)
      second_run_binding_count = Repo.aggregate(RolePermissionBinding, :count, :rbac_role_id)

      assert first_run_bindings == second_run_bindings
      assert first_run_permission_count == second_run_permission_count
      assert first_run_binding_count == second_run_binding_count

      # Verify expected state
      owner_permissions =
        from(rb in RolePermissionBinding,
          join: p in Permission,
          on: rb.permission_id == p.id,
          where: rb.rbac_role_id == ^owner_role.id,
          select: p.name
        )
        |> Repo.all()
        |> MapSet.new()

      admin_permissions =
        from(rb in RolePermissionBinding,
          join: p in Permission,
          on: rb.permission_id == p.id,
          where: rb.rbac_role_id == ^admin_role.id,
          select: p.name
        )
        |> Repo.all()
        |> MapSet.new()

      assert "organization.service_accounts.manage" in owner_permissions
      assert "organization.service_accounts.view" in owner_permissions
      assert "organization.service_accounts.view" in admin_permissions
      assert "organization.service_accounts.manage" in admin_permissions
    end

    test "crashes when no organization found" do
      # Don't create any organization in the database

      assert {:shutdown, 1} =
               catch_exit(Rbac.OnPrem.Init.upgrade_roles_for_1_5())
    end

    test "crashes when multiple organizations found" do
      # Create multiple organizations in database
      Rbac.FrontRepo.insert!(%Rbac.FrontRepo.Organization{
        name: "Organization 1",
        username: "org1"
      })

      Rbac.FrontRepo.insert!(%Rbac.FrontRepo.Organization{
        name: "Organization 2",
        username: "org2"
      })

      assert {:shutdown, 1} =
               catch_exit(Rbac.OnPrem.Init.upgrade_roles_for_1_5())
    end

    test "crashes when org_scope not found" do
      Rbac.FrontRepo.insert!(%Rbac.FrontRepo.Organization{
        name: "Test Organization",
        username: "test_org"
      })

      # Don't create org_scope - this should cause an error

      assert {:shutdown, 1} =
               catch_exit(Rbac.OnPrem.Init.upgrade_roles_for_1_5())
    end
  end
end
