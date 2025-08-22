defmodule Rbac.GrpcServers.RbacServerTest do
  use ExUnit.Case
  alias InternalApi.RBAC.RBAC.Stub

  import Rbac.Utils.Grpc, only: [grpc_error!: 2]

  @grpc_url "localhost:50051"
  setup do
    {:ok, channel} = GRPC.Stub.connect(@grpc_url)
    {:ok, channel: channel}
  end

  describe "list_roles/2" do
    test "Should return all 3 organization roles", %{channel: channel} do
      request = %InternalApi.RBAC.ListRolesRequest{
        scope: InternalApi.RBAC.Scope.value(:SCOPE_ORG)
      }

      {:ok, response} = Stub.list_roles(channel, request)

      assert length(response.roles) == 3

      [owner_role, admin_role, member_role] = response.roles

      assert owner_role.name == "Owner"
      assert owner_role.maps_to == nil
      assert member_role.inherited_role == nil
      assert(length(owner_role.permissions) > 0)
      assert(length(admin_role.permissions) > 0)

      assert owner_role.description =~
               "Owners have access to all functionalities within the organization and any of its projects."

      assert admin_role.name == "Admin"
      assert admin_role.maps_to == nil
      assert admin_role.inherited_role == nil
      assert(length(admin_role.permissions) > 0)

      assert admin_role.description =~
               "Admins can modify settings within the organization or any of its projects."

      assert member_role.name == "Member"
      assert member_role.maps_to == nil
      assert member_role.inherited_role == nil
      assert(length(member_role.permissions) > 0)

      assert member_role.description =~
               "Members can access the organization's homepage and the projects they are assigned to."
    end

    test "Should return an invalid_argument grpc error for project roles", %{channel: channel} do
      request = %InternalApi.RBAC.ListRolesRequest{
        scope: InternalApi.RBAC.Scope.value(:SCOPE_PROJECT)
      }

      {:ok, response} = Stub.list_roles(channel, request)

      assert response == %InternalApi.RBAC.ListRolesResponse{
               roles: []
             }
    end
  end

  describe "assign_role/2" do
    setup %{channel: channel} do
      setup_assign_and_retract(channel)
    end

    @tag :subject_type_test
    test "Should assign a role to a USER subject and save correct subject_type", %{
      channel: channel,
      valid_requester: valid_requester,
      non_member_user: non_member_user,
      org_id: org_id
    } do
      request = %InternalApi.RBAC.AssignRoleRequest{
        requester_id: valid_requester.user_id,
        role_assignment: %InternalApi.RBAC.RoleAssignment{
          org_id: org_id,
          role_id: Rbac.Roles.Member.role().id,
          subject: %InternalApi.RBAC.Subject{
            subject_id: non_member_user.user_id,
            subject_type: :USER
          }
        }
      }

      {:ok, response} = Stub.assign_role(channel, request)
      assert response == %InternalApi.RBAC.AssignRoleResponse{}

      role_assignment =
        Rbac.Models.RoleAssignment.get_by_user_and_org_id(non_member_user.user_id, org_id)

      assert role_assignment.role_id == Rbac.Roles.Member.role().id
      assert role_assignment.subject_type == "user"
    end

    @tag :subject_type_test
    test "Should assign a role to a SERVICE_ACCOUNT subject and save correct subject_type", %{
      channel: channel,
      valid_requester: valid_requester,
      non_member_user: non_member_user,
      org_id: org_id
    } do
      request = %InternalApi.RBAC.AssignRoleRequest{
        requester_id: valid_requester.user_id,
        role_assignment: %InternalApi.RBAC.RoleAssignment{
          org_id: org_id,
          role_id: Rbac.Roles.Admin.role().id,
          subject: %InternalApi.RBAC.Subject{
            subject_id: non_member_user.user_id,
            subject_type: :SERVICE_ACCOUNT
          }
        }
      }

      {:ok, response} = Stub.assign_role(channel, request)
      assert response == %InternalApi.RBAC.AssignRoleResponse{}

      role_assignment =
        Rbac.Models.RoleAssignment.get_by_user_and_org_id(non_member_user.user_id, org_id)

      assert role_assignment.role_id == Rbac.Roles.Admin.role().id
      assert role_assignment.subject_type == "service_account"
    end

    @tag :subject_type_test
    test "Should default to 'user' subject_type when subject_type is not provided", %{
      channel: channel,
      valid_requester: valid_requester,
      non_member_user: non_member_user,
      org_id: org_id
    } do
      request = %InternalApi.RBAC.AssignRoleRequest{
        requester_id: valid_requester.user_id,
        role_assignment: %InternalApi.RBAC.RoleAssignment{
          org_id: org_id,
          role_id: Rbac.Roles.Owner.role().id,
          subject: %InternalApi.RBAC.Subject{
            subject_id: non_member_user.user_id
            # subject_type not provided
          }
        }
      }

      {:ok, response} = Stub.assign_role(channel, request)
      assert response == %InternalApi.RBAC.AssignRoleResponse{}

      role_assignment =
        Rbac.Models.RoleAssignment.get_by_user_and_org_id(non_member_user.user_id, org_id)

      assert role_assignment.role_id == Rbac.Roles.Owner.role().id
      assert role_assignment.subject_type == "user"
    end

    test "A valid requester user should assign a member role to a subject", %{
      channel: channel,
      valid_requester: valid_requester,
      non_member_user: non_member_user,
      org_id: org_id
    } do
      request = %InternalApi.RBAC.AssignRoleRequest{
        requester_id: valid_requester.user_id,
        role_assignment: %InternalApi.RBAC.RoleAssignment{
          org_id: org_id,
          role_id: Rbac.Roles.Member.role().id,
          subject: %InternalApi.RBAC.Subject{subject_id: non_member_user.user_id}
        }
      }

      {:ok, response} = Stub.assign_role(channel, request)
      assert response == %InternalApi.RBAC.AssignRoleResponse{}

      assert_receive {:ok, :role_assigned}, 5_000

      role_assignment =
        Rbac.Models.RoleAssignment.get_by_user_and_org_id(non_member_user.user_id, org_id)

      assert role_assignment.role_id == Rbac.Roles.Member.role().id
    end

    test "A valid requester user should assign an admin role to a subject", %{
      channel: channel,
      valid_requester: valid_requester,
      non_member_user: non_member_user,
      org_id: org_id
    } do
      request = %InternalApi.RBAC.AssignRoleRequest{
        requester_id: valid_requester.user_id,
        role_assignment: %InternalApi.RBAC.RoleAssignment{
          org_id: org_id,
          role_id: Rbac.Roles.Admin.role().id,
          subject: %InternalApi.RBAC.Subject{subject_id: non_member_user.user_id}
        }
      }

      {:ok, response} = Stub.assign_role(channel, request)
      assert response == %InternalApi.RBAC.AssignRoleResponse{}
      assert_receive {:ok, :role_assigned}, 5_000

      role_assignment =
        Rbac.Models.RoleAssignment.get_by_user_and_org_id(non_member_user.user_id, org_id)

      assert role_assignment.role_id == Rbac.Roles.Admin.role().id
    end

    test "A valid requester user should assign an owner role to a subject", %{
      channel: channel,
      valid_requester: valid_requester,
      non_member_user: non_member_user,
      org_id: org_id
    } do
      request = %InternalApi.RBAC.AssignRoleRequest{
        requester_id: valid_requester.user_id,
        role_assignment: %InternalApi.RBAC.RoleAssignment{
          org_id: org_id,
          role_id: Rbac.Roles.Owner.role().id,
          subject: %InternalApi.RBAC.Subject{subject_id: non_member_user.user_id}
        }
      }

      {:ok, response} = Stub.assign_role(channel, request)
      assert response == %InternalApi.RBAC.AssignRoleResponse{}
      assert_receive {:ok, :role_assigned}, 5_000

      role_assignment =
        Rbac.Models.RoleAssignment.get_by_user_and_org_id(non_member_user.user_id, org_id)

      assert role_assignment.role_id == Rbac.Roles.Owner.role().id
    end

    test "A valid requester user should assign a project to a member subject", %{
      channel: channel,
      valid_requester: valid_requester,
      member_user: member_user,
      org_id: org_id,
      project_id: project_id
    } do
      request = %InternalApi.RBAC.AssignRoleRequest{
        requester_id: valid_requester.user_id,
        role_assignment: %InternalApi.RBAC.RoleAssignment{
          org_id: org_id,
          project_id: project_id,
          subject: %InternalApi.RBAC.Subject{subject_id: member_user.user_id}
        }
      }

      {:ok, response} = Stub.assign_role(channel, request)
      assert response == %InternalApi.RBAC.AssignRoleResponse{}
      assert_receive {:ok, :role_assigned}, 5_000

      project_assignment =
        Rbac.Models.ProjectAssignment.get_by_user_and_project_id(member_user.user_id, project_id)

      assert project_assignment.project_id == project_id
    end

    test "A valid requester user should replace the role to admin from a member user, deleting his project assigns in the org",
         %{
           channel: channel,
           valid_requester: valid_requester,
           member_user: member_user,
           org_id: org_id
         } do
      # Create some project assignments
      1..2
      |> Enum.each(fn _ ->
        Rbac.Support.ProjectAssignmentsFixtures.project_assignment_fixture(%{
          user_id: member_user.user_id,
          org_id: org_id
        })
      end)

      request = %InternalApi.RBAC.AssignRoleRequest{
        requester_id: valid_requester.user_id,
        role_assignment: %InternalApi.RBAC.RoleAssignment{
          org_id: org_id,
          role_id: Rbac.Roles.Admin.role().id,
          subject: %InternalApi.RBAC.Subject{subject_id: member_user.user_id}
        }
      }

      {:ok, response} = Stub.assign_role(channel, request)
      assert response == %InternalApi.RBAC.AssignRoleResponse{}
      assert_receive {:ok, :role_assigned}, 5_000

      role_assignment =
        Rbac.Models.RoleAssignment.get_by_user_and_org_id(member_user.user_id, org_id)

      project_assignments =
        Rbac.Models.ProjectAssignment.get_by_user_and_org_id(member_user.user_id, org_id)

      assert role_assignment.role_id == Rbac.Roles.Admin.role().id
      assert Enum.empty?(project_assignments)
    end

    test "Should return an error if the role does not exist", %{
      channel: channel,
      valid_requester: valid_requester,
      member_user: member_user,
      org_id: org_id
    } do
      request = %InternalApi.RBAC.AssignRoleRequest{
        requester_id: valid_requester.user_id,
        role_assignment: %InternalApi.RBAC.RoleAssignment{
          org_id: org_id,
          role_id: Ecto.UUID.generate(),
          subject: %InternalApi.RBAC.Subject{subject_id: member_user.user_id}
        }
      }

      {:error, response} = Stub.assign_role(channel, request)
      assert response.status == GRPC.Status.not_found()

      refute_received {:ok, :role_assigned}
    end
  end

  describe "list_accessible_orgs/2" do
    setup %{channel: channel} do
      alias InternalApi.{User, ResponseStatus}

      status_ok = %ResponseStatus{code: :OK}

      org_ids =
        1..4
        |> Enum.map(fn _ -> Ecto.UUID.generate() end)

      user_id = Ecto.UUID.generate()

      org_ids
      |> Enum.each(fn org_id ->
        Rbac.Support.RoleAssignmentsFixtures.role_assignment_fixture(%{
          user_id: user_id,
          role_id: Rbac.Roles.Member.role().id,
          org_id: org_id
        })
      end)

      GrpcMock.stub(UserMock, :describe, fn request, _ ->
        if request.user_id == user_id do
          %User.DescribeResponse{
            status: status_ok,
            user_id: user_id,
            name: "Example"
          }
        else
          grpc_error!(:not_found, "User not found")
        end
      end)

      {:ok, channel: channel, org_ids: org_ids, user_id: user_id}
    end

    test "Should return accessible organization IDs for a valid user", %{
      channel: channel,
      user_id: user_id,
      org_ids: org_ids
    } do
      request = %InternalApi.RBAC.ListAccessibleOrgsRequest{user_id: user_id}
      {:ok, response} = Stub.list_accessible_orgs(channel, request)

      assert MapSet.new(response.org_ids) == MapSet.new(org_ids)
    end
  end

  describe "list_accessible_projects/2" do
    setup %{channel: channel} do
      alias InternalApi.{User, Projecthub, ResponseStatus}

      status_ok = %ResponseStatus{code: :OK}
      org_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()
      owner_id = Ecto.UUID.generate()

      Rbac.Support.RoleAssignmentsFixtures.role_assignment_fixture(%{
        user_id: user_id,
        role_id: Rbac.Roles.Member.role().id,
        org_id: org_id
      })

      Rbac.Support.RoleAssignmentsFixtures.role_assignment_fixture(%{
        user_id: owner_id,
        role_id: Rbac.Roles.Owner.role().id,
        org_id: org_id
      })

      project_ids =
        1..4
        |> Enum.map(fn _ -> Ecto.UUID.generate() end)

      owner_project_ids =
        1..2
        |> Enum.map(fn _ -> Ecto.UUID.generate() end)

      owner_project_ids = owner_project_ids ++ project_ids

      project_ids
      |> Enum.each(fn project_id ->
        Rbac.Support.ProjectAssignmentsFixtures.project_assignment_fixture(%{
          user_id: user_id,
          project_id: project_id,
          org_id: org_id
        })
      end)

      owner_project_ids
      |> Enum.each(fn project_id ->
        Rbac.Support.ProjectAssignmentsFixtures.project_assignment_fixture(%{
          user_id: owner_id,
          project_id: project_id,
          org_id: org_id
        })
      end)

      GrpcMock.stub(ProjecthubMock, :list, fn request, _ ->
        if request.metadata.org_id == org_id do
          %Projecthub.ListResponse{
            metadata: %Projecthub.ResponseMeta{
              status: %Projecthub.ResponseMeta.Status{code: :OK}
            },
            projects:
              Enum.map(owner_project_ids, fn project_id ->
                %Projecthub.Project{
                  metadata: %Projecthub.Project.Metadata{
                    id: project_id
                  }
                }
              end)
          }
        else
          grpc_error!(:not_found, "Organization not found")
        end
      end)

      GrpcMock.stub(UserMock, :describe, fn request, _ ->
        if request.user_id == user_id do
          %User.DescribeResponse{
            status: status_ok,
            user_id: user_id,
            name: "Example"
          }
        else
          grpc_error!(:not_found, "User not found")
        end
      end)

      {:ok,
       channel: channel,
       org_id: org_id,
       user_id: user_id,
       owner_id: owner_id,
       project_ids: project_ids,
       owner_project_ids: owner_project_ids}
    end

    test "Should return accessible project IDs for a valid user and organization", %{
      channel: channel,
      user_id: user_id,
      org_id: org_id,
      project_ids: project_ids
    } do
      request = %InternalApi.RBAC.ListAccessibleProjectsRequest{user_id: user_id, org_id: org_id}
      {:ok, response} = Stub.list_accessible_projects(channel, request)

      assert MapSet.new(response.project_ids) == MapSet.new(project_ids)
    end

    test "Should return all project IDs for an owner user", %{
      channel: channel,
      owner_id: owner_id,
      org_id: org_id,
      owner_project_ids: owner_project_ids
    } do
      request = %InternalApi.RBAC.ListAccessibleProjectsRequest{user_id: owner_id, org_id: org_id}
      {:ok, response} = Stub.list_accessible_projects(channel, request)

      assert MapSet.new(response.project_ids) == MapSet.new(owner_project_ids)
    end

    test "Should return an empty array if the organization does not exist", %{
      channel: channel,
      user_id: user_id
    } do
      request = %InternalApi.RBAC.ListAccessibleProjectsRequest{
        user_id: user_id,
        org_id: Ecto.UUID.generate()
      }

      {:ok, response} = Stub.list_accessible_projects(channel, request)

      assert response.project_ids == []
    end

    test "Should return an empty array if the user does not exist", %{
      channel: channel,
      org_id: org_id
    } do
      request = %InternalApi.RBAC.ListAccessibleProjectsRequest{
        user_id: Ecto.UUID.generate(),
        org_id: org_id
      }

      {:ok, response} = Stub.list_accessible_projects(channel, request)

      assert response.project_ids == []
    end
  end

  describe "list_existing_permissions/2" do
    test "Should return all organization permissions", %{channel: channel} do
      request = %InternalApi.RBAC.ListExistingPermissionsRequest{
        scope: InternalApi.RBAC.Scope.value(:SCOPE_ORG)
      }

      {:ok, response} = Stub.list_existing_permissions(channel, request)

      assert length(response.permissions) > 0

      assert Enum.all?(response.permissions, fn permission ->
               permission.name != "" and
                 permission.description != "" and
                 permission.scope == :SCOPE_ORG
             end)
    end

    test "Should return all project permissions", %{channel: channel} do
      request = %InternalApi.RBAC.ListExistingPermissionsRequest{
        scope: :SCOPE_PROJECT
      }

      {:ok, response} = Stub.list_existing_permissions(channel, request)

      assert length(response.permissions) > 0

      assert Enum.all?(response.permissions, fn permission ->
               permission.name != "" and
                 permission.description != "" and
                 permission.scope == :SCOPE_PROJECT
             end)
    end

    test "Should return all permissions if scope is unspecified", %{channel: channel} do
      request = %InternalApi.RBAC.ListExistingPermissionsRequest{
        scope: :SCOPE_UNSPECIFIED
      }

      {:ok, response} = Stub.list_existing_permissions(channel, request)

      assert length(response.permissions) > 0

      assert Enum.all?(response.permissions, fn permission ->
               permission.name != "" and
                 permission.description != "" and
                 (permission.scope == :SCOPE_PROJECT or
                    permission.scope == :SCOPE_ORG)
             end)
    end
  end

  describe "retract_role/2" do
    setup %{channel: channel} do
      setup_assign_and_retract(channel)
    end

    test "Should retract the role from an member user", %{
      channel: channel,
      member_user: member_user,
      valid_requester: valid_requester,
      org_id: org_id
    } do
      request = %InternalApi.RBAC.RetractRoleRequest{
        requester_id: valid_requester.user_id,
        role_assignment: %InternalApi.RBAC.RoleAssignment{
          org_id: org_id,
          role_id: Rbac.Roles.Member.role().id,
          subject: %InternalApi.RBAC.Subject{subject_id: member_user.user_id}
        }
      }

      {:ok, _} = Stub.retract_role(channel, request)

      assert_receive {:ok, :role_retracted}, 5_000

      role = Rbac.Models.RoleAssignment.get_by_user_and_org_id(member_user.user_id, org_id)
      assert role == nil
    end

    test "Should return an error if role is not assigned to an user", %{
      channel: channel,
      non_member_user: non_member_user,
      valid_requester: valid_requester,
      org_id: org_id
    } do
      request = %InternalApi.RBAC.RetractRoleRequest{
        requester_id: valid_requester.user_id,
        role_assignment: %InternalApi.RBAC.RoleAssignment{
          org_id: org_id,
          role_id: Rbac.Roles.Member.role().id,
          subject: %InternalApi.RBAC.Subject{subject_id: non_member_user.user_id}
        }
      }

      {:error, response} = Stub.retract_role(channel, request)
      refute_received {:ok, :role_retracted}
      assert response.status == GRPC.Status.permission_denied()

      assert response.message ==
               "User #{non_member_user.user_id} doesn't have access to the organization #{org_id}"
    end

    test "should retract the role from a member user, deleting his project assigns in the org",
         %{
           channel: channel,
           valid_requester: valid_requester,
           member_user: member_user,
           org_id: org_id
         } do
      # Create some project assignments
      1..4
      |> Enum.each(fn _ ->
        Rbac.Support.ProjectAssignmentsFixtures.project_assignment_fixture(%{
          user_id: member_user.user_id,
          org_id: org_id
        })
      end)

      request = %InternalApi.RBAC.RetractRoleRequest{
        requester_id: valid_requester.user_id,
        role_assignment: %InternalApi.RBAC.RoleAssignment{
          org_id: org_id,
          role_id: Rbac.Roles.Member.role().id,
          subject: %InternalApi.RBAC.Subject{subject_id: member_user.user_id}
        }
      }

      {:ok, response} = Stub.retract_role(channel, request)
      assert response == %InternalApi.RBAC.RetractRoleResponse{}
      assert_receive {:ok, :role_retracted}, 5_000

      role_assignment =
        Rbac.Models.RoleAssignment.get_by_user_and_org_id(member_user.user_id, org_id)

      project_assignments =
        Rbac.Models.ProjectAssignment.get_by_user_and_org_id(member_user.user_id, org_id)

      assert role_assignment == nil
      assert Enum.empty?(project_assignments)
    end

    test "should retract the role from a member user, deleting his project assigns in the org even if no role_id is provided",
         %{
           channel: channel,
           valid_requester: valid_requester,
           member_user: member_user,
           org_id: org_id
         } do
      # Create some project assignments
      1..4
      |> Enum.each(fn _ ->
        Rbac.Support.ProjectAssignmentsFixtures.project_assignment_fixture(%{
          user_id: member_user.user_id,
          org_id: org_id
        })
      end)

      request = %InternalApi.RBAC.RetractRoleRequest{
        requester_id: valid_requester.user_id,
        role_assignment: %InternalApi.RBAC.RoleAssignment{
          org_id: org_id,
          subject: %InternalApi.RBAC.Subject{subject_id: member_user.user_id}
        }
      }

      {:ok, response} = Stub.retract_role(channel, request)
      assert response == %InternalApi.RBAC.RetractRoleResponse{}
      assert_receive {:ok, :role_retracted}, 5_000

      role_assignment =
        Rbac.Models.RoleAssignment.get_by_user_and_org_id(member_user.user_id, org_id)

      project_assignments =
        Rbac.Models.ProjectAssignment.get_by_user_and_org_id(member_user.user_id, org_id)

      assert role_assignment == nil
      assert Enum.empty?(project_assignments)
    end
  end

  describe "list_user_permissions/2" do
    setup %{channel: channel} do
      setup_assign_and_retract(channel)
    end

    test "Should return all the permissions of a member user on a org", %{
      channel: channel,
      member_user: member_user,
      org_id: org_id
    } do
      request = %InternalApi.RBAC.ListUserPermissionsRequest{
        user_id: member_user.user_id,
        org_id: org_id
      }

      {:ok, response} = Stub.list_user_permissions(channel, request)

      assert response == %InternalApi.RBAC.ListUserPermissionsResponse{
               user_id: member_user.user_id,
               org_id: org_id,
               project_id: "",
               permissions: Rbac.Roles.Member.role().permissions
             }
    end

    test "Should return the permissions of a member user on a project", %{
      channel: channel,
      member_user: member_user,
      org_id: org_id,
      project_id: project_id
    } do
      # Assign the project to the member user
      Rbac.Support.ProjectAssignmentsFixtures.project_assignment_fixture(%{
        user_id: member_user.user_id,
        org_id: org_id,
        project_id: project_id
      })

      request = %InternalApi.RBAC.ListUserPermissionsRequest{
        user_id: member_user.user_id,
        org_id: org_id,
        project_id: project_id
      }

      {:ok, response} = Stub.list_user_permissions(channel, request)

      assert response == %InternalApi.RBAC.ListUserPermissionsResponse{
               user_id: member_user.user_id,
               org_id: org_id,
               project_id: project_id,
               permissions:
                 Rbac.Roles.Member.role().permissions
                 |> Enum.filter(&Rbac.Permissions.project_permission?/1)
             }
    end

    test "Should return an empty list of permissions if the user is not assigned to the project",
         %{
           channel: channel,
           non_member_user: non_member_user,
           org_id: org_id,
           project_id: project_id
         } do
      request = %InternalApi.RBAC.ListUserPermissionsRequest{
        org_id: org_id,
        project_id: project_id,
        user_id: non_member_user.user_id
      }

      {:ok, response} = Stub.list_user_permissions(channel, request)

      assert response.permissions == []
    end

    test "Should return empty permissions if the role assignment is not found", %{
      channel: channel,
      non_member_user: non_member_user,
      org_id: org_id,
      project_id: project_id
    } do
      request = %InternalApi.RBAC.ListUserPermissionsRequest{
        user_id: non_member_user.user_id,
        org_id: org_id,
        project_id: project_id
      }

      {:ok, response} = Stub.list_user_permissions(channel, request)

      assert response.permissions == []
    end
  end

  describe "list_members/2" do
    setup %{channel: channel} do
      setup_results = setup_assign_and_retract(channel)
      {:ok, values} = setup_results
      member_user = values[:member_user]
      owner_user = values[:valid_requester]

      user_api_response = [
        %InternalApi.User.User{
          id: member_user.user_id,
          name: member_user.name
        },
        %InternalApi.User.User{
          id: owner_user.user_id,
          name: owner_user.name
        }
      ]

      GrpcMock.stub(UserMock, :describe_many, fn request, _ ->
        %InternalApi.User.DescribeManyResponse{
          users: user_api_response |> Enum.filter(fn user -> user.id in request.user_ids end)
        }
      end)

      GrpcMock.stub(UserMock, :search_users, fn request, _ ->
        %InternalApi.User.DescribeManyResponse{
          users:
            user_api_response
            |> Enum.filter(fn user -> String.contains?(request.query, user.name) end)
        }
      end)

      setup_results
    end

    test "Should return list of members from one organization based on simple params", %{
      channel: channel,
      org_id: org_id,
      valid_requester: owner_user,
      member_user: member_user
    } do
      request = %InternalApi.RBAC.ListMembersRequest{
        org_id: org_id,
        page: %InternalApi.RBAC.ListMembersRequest.Page{
          page_no: 1,
          page_size: 10
        }
      }

      {:ok, response} = Stub.list_members(channel, request)

      assert length(response.members) == 2

      assert Enum.all?(response.members, fn member ->
               [role_binding] = member.subject_role_bindings

               member.subject.subject_id in [member_user.user_id, owner_user.user_id] and
                 member.subject.display_name in [member_user.name, owner_user.name] and
                 role_binding.role.permissions > 0
             end)
    end

    test "Should return list with an owner and a member that belongs to the org based on a project id",
         %{
           channel: channel,
           org_id: org_id,
           member_user: member_user,
           valid_requester: owner_user
         } do
      # Create a member that is part of the org but is not assigned to any project
      Rbac.Support.RoleAssignmentsFixtures.role_assignment_fixture(%{
        user_id: Ecto.UUID.generate(),
        role_id: Rbac.Roles.Member.role().id,
        org_id: org_id
      })

      project_id = Ecto.UUID.generate()

      Rbac.Support.ProjectAssignmentsFixtures.project_assignment_fixture(%{
        user_id: member_user.user_id,
        org_id: org_id,
        project_id: project_id
      })

      request = %InternalApi.RBAC.ListMembersRequest{
        org_id: org_id,
        project_id: project_id,
        page: %InternalApi.RBAC.ListMembersRequest.Page{
          page_no: 1,
          page_size: 10
        }
      }

      {:ok, response} = Stub.list_members(channel, request)

      assert length(response.members) == 2

      # check if the owner is in the list
      assert Enum.any?(response.members, fn member ->
               [role_binding] = member.subject_role_bindings

               member.subject.subject_id == owner_user.user_id and
                 member.subject.display_name == owner_user.name and
                 role_binding.role.permissions > 0
             end)

      # check if the member is in the list
      assert Enum.any?(response.members, fn member ->
               [role_binding] = member.subject_role_bindings

               member.subject.subject_id == member_user.user_id and
                 member.subject.display_name == member_user.name and
                 role_binding.role.permissions > 0
             end)
    end

    test "Should return list with one member based on member name", %{
      channel: channel,
      org_id: org_id,
      member_user: member_user
    } do
      request = %InternalApi.RBAC.ListMembersRequest{
        org_id: org_id,
        member_name_contains: member_user.name,
        page: %InternalApi.RBAC.ListMembersRequest.Page{
          page_no: 1,
          page_size: 10
        }
      }

      {:ok, response} = Stub.list_members(channel, request)

      assert length(response.members) == 1

      assert Enum.all?(response.members, fn member ->
               [role_binding] = member.subject_role_bindings

               role_binding.role.permissions > 0 and
                 member.subject.subject_id == member_user.user_id and
                 member.subject.display_name == member_user.name
             end)
    end

    test "Should return list with one member based on role_id", %{
      channel: channel,
      org_id: org_id,
      member_user: member_user
    } do
      request = %InternalApi.RBAC.ListMembersRequest{
        org_id: org_id,
        member_has_role: Rbac.Roles.Member.role().id,
        page: %InternalApi.RBAC.ListMembersRequest.Page{
          page_no: 1,
          page_size: 10
        }
      }

      {:ok, response} = Stub.list_members(channel, request)

      assert length(response.members) == 1

      assert Enum.all?(response.members, fn member ->
               [role_binding] = member.subject_role_bindings

               member.subject.display_name == member_user.name and
                 member.subject.subject_id == member_user.user_id and
                 role_binding.role.permissions > 0
             end)
    end

    test "Should return an empty list of members for a random organization id", %{
      channel: channel
    } do
      org_id = Ecto.UUID.generate()

      request = %InternalApi.RBAC.ListMembersRequest{
        org_id: org_id,
        page: %InternalApi.RBAC.ListMembersRequest.Page{
          page_no: 1,
          page_size: 10
        }
      }

      {:ok, response} = Stub.list_members(channel, request)

      assert Enum.empty?(response.members)
    end

    test "Should return only service accounts when member_type is SERVICE_ACCOUNT", %{
      channel: channel,
      org_id: org_id
    } do
      # Create a service account role assignment
      service_account_id = Ecto.UUID.generate()

      Rbac.Support.RoleAssignmentsFixtures.role_assignment_fixture(%{
        user_id: service_account_id,
        role_id: Rbac.Roles.Member.role().id,
        org_id: org_id,
        subject_type: "service_account"
      })

      # Mock the User API to return service account information
      GrpcMock.stub(UserMock, :describe_many, fn request, _ ->
        %InternalApi.User.DescribeManyResponse{
          users:
            [
              %InternalApi.User.User{
                id: service_account_id,
                name: "Test Service Account",
                creation_source: :SERVICE_ACCOUNT
              }
            ]
            |> Enum.filter(fn user -> user.id in request.user_ids end)
        }
      end)

      request = %InternalApi.RBAC.ListMembersRequest{
        org_id: org_id,
        member_type: :SERVICE_ACCOUNT,
        page: %InternalApi.RBAC.ListMembersRequest.Page{
          page_no: 1,
          page_size: 10
        }
      }

      {:ok, response} = Stub.list_members(channel, request)

      assert length(response.members) == 1

      [member] = response.members
      assert member.subject.subject_type == :SERVICE_ACCOUNT
      assert member.subject.subject_id == service_account_id
    end

    test "Should exclude service accounts by default when no member_type is specified", %{
      channel: channel,
      org_id: org_id,
      valid_requester: owner_user,
      member_user: member_user
    } do
      # Create a service account role assignment to ensure it's filtered out by default
      service_account_id = Ecto.UUID.generate()

      Rbac.Support.RoleAssignmentsFixtures.role_assignment_fixture(%{
        user_id: service_account_id,
        role_id: Rbac.Roles.Admin.role().id,
        org_id: org_id,
        subject_type: "service_account"
      })

      request = %InternalApi.RBAC.ListMembersRequest{
        org_id: org_id,
        page: %InternalApi.RBAC.ListMembersRequest.Page{
          page_no: 1,
          page_size: 10
        }
      }

      {:ok, response} = Stub.list_members(channel, request)

      # Should only return the 2 regular users, not the service account
      assert length(response.members) == 2

      assert Enum.all?(response.members, fn member ->
               member.subject.subject_type == :USER and
                 member.subject.subject_id in [member_user.user_id, owner_user.user_id]
             end)

      # Verify service account is not in the results
      refute Enum.any?(response.members, fn member ->
               member.subject.subject_id == service_account_id
             end)
    end
  end

  describe "count_members/2" do
    setup %{channel: channel} do
      setup_assign_and_retract(channel)
    end

    test "Should return the total count of members", %{channel: channel, org_id: org_id} do
      request = %InternalApi.RBAC.CountMembersRequest{
        org_id: org_id
      }

      {:ok, response} = Stub.count_members(channel, request)

      assert response.members == 2
    end

    test "Should return a not_found error if org does not exist", %{channel: channel} do
      request = %InternalApi.RBAC.CountMembersRequest{
        org_id: Ecto.UUID.generate()
      }

      {:error, response} = Stub.count_members(channel, request)

      assert response.status == GRPC.Status.not_found()
      assert response.message == "Organization with id #{request.org_id} not found"
    end
  end

  describe "subjects_have_roles/2" do
    test "Should raise a unimplemented error", %{channel: channel} do
      request = %InternalApi.RBAC.SubjectsHaveRolesRequest{}

      {:error, response} = Stub.subjects_have_roles(channel, request)
      assert response.status == GRPC.Status.unimplemented()
    end
  end

  describe "describe_role/2" do
    test "Should describe role to admin, owner and member", %{channel: channel} do
      roles = [Rbac.Roles.Admin.role(), Rbac.Roles.Owner.role(), Rbac.Roles.Member.role()]

      roles
      |> Enum.each(fn role ->
        request = %InternalApi.RBAC.DescribeRoleRequest{
          role_id: role.id
        }

        {:ok, response} = Stub.describe_role(channel, request)

        assert response.role.id == role.id
        assert length(response.role.permissions) > 0
        assert response.role.name in ["Admin", "Owner", "Member"]
      end)
    end

    test "Should return a not_found error if role_id is invalid", %{channel: channel} do
      request = %InternalApi.RBAC.DescribeRoleRequest{
        role_id: Ecto.UUID.generate()
      }

      {:error, response} = Stub.describe_role(channel, request)

      assert response.status == GRPC.Status.not_found()
      assert response.message == "Role with id #{request.role_id} not found"
    end
  end

  describe "destroy_role/2" do
    test "Should return an unimplemented rpc error", %{channel: channel} do
      request = %InternalApi.RBAC.DestroyRoleRequest{}

      {:error, response} = Stub.destroy_role(channel, request)

      assert response.status == GRPC.Status.unimplemented()
    end
  end

  describe "modify_role/2" do
    test "Should return an unimplemented rpc error", %{channel: channel} do
      request = %InternalApi.RBAC.DestroyRoleRequest{}

      {:error, response} = Stub.modify_role(channel, request)

      assert response.status == GRPC.Status.unimplemented()
    end
  end

  defp setup_assign_and_retract(channel) do
    alias InternalApi.{User, ResponseStatus}

    status_ok = %ResponseStatus{code: :OK}

    org_id = Ecto.UUID.generate()
    project_id = Ecto.UUID.generate()

    [valid_requester, member_user, non_member_user] =
      ["Owner Requester", "Member", "Non-Member"]
      |> Enum.map(fn name ->
        %User.DescribeResponse{
          status: status_ok,
          user_id: Ecto.UUID.generate(),
          name: name
        }
      end)

    [
      {valid_requester, Rbac.Roles.Owner.role().id},
      {member_user, Rbac.Roles.Member.role().id}
    ]
    |> Enum.each(fn {user, role_id} ->
      Rbac.Support.RoleAssignmentsFixtures.role_assignment_fixture(%{
        user_id: user.user_id,
        role_id: role_id,
        org_id: org_id
      })
    end)

    GrpcMock.stub(UserMock, :describe, fn request, _ ->
      cond do
        request.user_id == valid_requester.user_id ->
          valid_requester

        request.user_id == member_user.user_id ->
          member_user

        request.user_id == non_member_user.user_id ->
          non_member_user

        true ->
          grpc_error!(:not_found, "User not found")
      end
    end)

    {:module, role_assign_consumer, _, _} =
      Support.TestConsumer.create_test_consumer(
        self(),
        Application.get_env(:rbac, :amqp_url),
        "rbac_exchange",
        "role_assigned",
        Ecto.UUID.generate(),
        :role_assigned
      )

    {:ok, _} = role_assign_consumer.start_link()

    {:module, role_retract_consumer, _, _} =
      Support.TestConsumer.create_test_consumer(
        self(),
        Application.get_env(:rbac, :amqp_url),
        "rbac_exchange",
        "role_retracted",
        Ecto.UUID.generate(),
        :role_retracted
      )

    {:ok, _} = role_retract_consumer.start_link()

    {:ok,
     channel: channel,
     valid_requester: valid_requester,
     member_user: member_user,
     non_member_user: non_member_user,
     org_id: org_id,
     project_id: project_id}
  end
end
