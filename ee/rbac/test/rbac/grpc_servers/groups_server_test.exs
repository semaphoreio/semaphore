defmodule Rbac.GrpcServers.GroupsServer.Test do
  use Rbac.RepoCase, async: false

  alias InternalApi.Groups.Groups.Stub
  alias Support.Factories

  import Ecto.Query

  @org_id Ecto.UUID.generate()
  @requester_id Ecto.UUID.generate()

  setup state do
    {:ok, channel} = GRPC.Stub.connect("localhost:50051")
    Support.Factories.RbacUser.insert(@requester_id)

    if !(Atom.to_string(state.test) =~ "unauthorized"),
      do: authorize_user_for_people_management(@requester_id, @org_id)

    {:ok, %{grpc_channel: channel}}
  end

  describe "list_groups/2" do
    alias InternalApi.Groups.ListGroupsRequest, as: Request

    test "invalid requests", state do
      requests = [
        %Request{},
        %Request{org_id: ""},
        %Request{org_id: "not-valid-uuid"},
        %Request{org_id: @org_id, group_id: "not-valid-uuid"}
      ]

      Enum.each(requests, fn request ->
        assert {:error, response} = state.grpc_channel |> Stub.list_groups(request)
        assert response.status == GRPC.Status.invalid_argument()

        assert response.message ==
                 "Invalid uuid passed as an argument where uuid v4 was expected."
      end)
    end

    test "returns all groups within an organization", state do
      request = %Request{org_id: @org_id}

      {:ok, group1} = Factories.Group.insert(org_id: @org_id)
      {:ok, group2} = Factories.Group.insert(org_id: @org_id)

      {:ok, user1} = Factories.RbacUser.insert()
      {:ok, user2} = Factories.RbacUser.insert()
      {:ok, _} = Factories.UserGroupBinding.insert(group_id: group1.id, user_id: user1.id)
      {:ok, _} = Factories.UserGroupBinding.insert(group_id: group1.id, user_id: user2.id)

      {:ok, response} = state.grpc_channel |> Stub.list_groups(request)

      group_with_members = response.groups |> Enum.find(&(&1.id == group1.id))
      assert user1.id in group_with_members.member_ids
      assert user2.id in group_with_members.member_ids

      group_with_no_members = response.groups |> Enum.find(&(&1.id == group2.id))
      assert Enum.empty?(group_with_no_members.member_ids)
    end

    test "returns an empty list when no groups are found for an organization", state do
      request = %Request{org_id: Ecto.UUID.generate()}
      {:ok, response} = state.grpc_channel |> Stub.list_groups(request)
      assert Enum.empty?(response.groups)
    end

    test "If group id is present, return only that group", state do
      {:ok, group1} = Factories.Group.insert(org_id: @org_id)
      {:ok, _group2} = Factories.Group.insert(org_id: @org_id)

      request = %Request{org_id: @org_id, group_id: group1.id}
      {:ok, response} = state.grpc_channel |> Stub.list_groups(request)

      assert response.groups |> length == 1
      assert hd(response.groups) |> Map.get(:id) == group1.id
    end

    test "If group id is present, and group does not exist, return empty list", state do
      request = %Request{org_id: @org_id, group_id: Ecto.UUID.generate()}
      {:ok, response} = state.grpc_channel |> Stub.list_groups(request)
      assert response.groups == []
    end
  end

  describe "modify_group/2" do
    alias InternalApi.Groups.ModifyGroupRequest, as: Request

    setup state do
      {:ok, group} = Support.Factories.Group.insert(org_id: @org_id)
      {:ok, group_model} = Rbac.Store.Group.fetch_group(group.id)
      {:ok, Map.merge(state, %{group: group_model})}
    end

    test "invalid requests", state do
      requests = [
        {
          %Request{},
          "Required group information not provided"
        },
        {
          %Request{
            group: %InternalApi.Groups.Group{id: Ecto.UUID.generate()},
            requester_id: ""
          },
          "Invalid uuid passed as an argument where uuid v4 was expected."
        },
        {
          %Request{
            group: %InternalApi.Groups.Group{id: Ecto.UUID.generate()},
            requester_id: "not-valid"
          },
          "Invalid uuid passed as an argument where uuid v4 was expected."
        },
        {
          %Request{
            group: %InternalApi.Groups.Group{id: Ecto.UUID.generate()},
            requester_id: @requester_id,
            org_id: ""
          },
          "Invalid uuid passed as an argument where uuid v4 was expected."
        },
        {
          %Request{
            group: %InternalApi.Groups.Group{id: Ecto.UUID.generate()},
            requester_id: @requester_id,
            org_id: "not-valid"
          },
          "Invalid uuid passed as an argument where uuid v4 was expected."
        },
        {
          %Request{
            requester_id: @requester_id,
            org_id: @org_id,
            group: %InternalApi.Groups.Group{}
          },
          "Invalid uuid passed as an argument where uuid v4 was expected."
        },
        {
          %Request{
            requester_id: @requester_id,
            org_id: @org_id,
            group: %InternalApi.Groups.Group{id: "not-valid"}
          },
          "Invalid uuid passed as an argument where uuid v4 was expected."
        }
      ]

      Enum.each(requests, fn {request, expected_message} ->
        {:error, %{status: status, message: msg}} =
          state.grpc_channel |> Stub.modify_group(request)

        assert status == GRPC.Status.invalid_argument()
        assert msg == expected_message
      end)
    end

    test "unauthorized requests", state do
      request =
        %Request{
          group: %InternalApi.Groups.Group{id: Ecto.UUID.generate()},
          requester_id: @requester_id,
          org_id: @org_id
        }

      {:error, %{status: status, message: msg}} = state.grpc_channel |> Stub.modify_group(request)
      assert status == GRPC.Status.permission_denied()
      assert msg == "User unauthorized"
    end

    test "group for update does not exist", state do
      request =
        %Request{
          group: %InternalApi.Groups.Group{id: Ecto.UUID.generate()},
          requester_id: @requester_id,
          org_id: @org_id
        }

      {:error, %{status: status, message: msg}} = state.grpc_channel |> Stub.modify_group(request)
      assert status == GRPC.Status.invalid_argument()
      assert msg == "The group you are trying to modify does not exist"
    end

    test "user that is being added to the group is not org member", state do
      {:ok, user1} = Support.Factories.RbacUser.insert()

      request =
        %Request{
          group: %InternalApi.Groups.Group{id: state.group.id, name: "New Name"},
          members_to_add: [user1.id],
          requester_id: @requester_id,
          org_id: @org_id
        }

      {:error, %{status: status, message: msg}} = state.grpc_channel |> Stub.modify_group(request)
      assert status == GRPC.Status.invalid_argument()
      assert msg =~ "have to already be part of the organization"
    end

    test "updated only name", state do
      request =
        %Request{
          group: %InternalApi.Groups.Group{id: state.group.id, name: "New Name"},
          requester_id: @requester_id,
          org_id: @org_id
        }

      {:ok, %{group: group_response}} = state.grpc_channel |> Stub.modify_group(request)

      {:ok, updated_group} = Rbac.Store.Group.fetch_group(state.group.id)
      assert group_response.name == "New Name"
      assert updated_group.id == state.group.id
      assert updated_group.name == "New Name"
      assert updated_group.description == state.group.description
    end

    test "updated only desc", state do
      request =
        %Request{
          group: %InternalApi.Groups.Group{id: state.group.id, description: "New Description"},
          requester_id: @requester_id,
          org_id: @org_id
        }

      {:ok, %{group: group_response}} = state.grpc_channel |> Stub.modify_group(request)

      {:ok, updated_group} = Rbac.Store.Group.fetch_group(state.group.id)
      assert group_response.description == "New Description"
      assert updated_group.id == state.group.id
      assert updated_group.name == state.group.name
      assert updated_group.description == "New Description"
    end

    # Here we only check if the request was created. How the
    # request is handled is tested in the Rbac.Store.Groups.Test tests.
    test "adds/removes user to a group", state do
      Support.Rbac.create_org_roles(@org_id)

      {:ok, user1} = Support.Factories.RbacUser.insert()
      {:ok, user2} = Support.Factories.RbacUser.insert()
      {:ok, user3} = Support.Factories.RbacUser.insert()

      [user1.id, user2.id]
      |> Enum.each(&Support.Rbac.assign_org_role_by_name(@org_id, &1, "Member"))

      request =
        %Request{
          group: %InternalApi.Groups.Group{id: state.group.id},
          members_to_add: [user1.id, user2.id],
          members_to_remove: [user3.id],
          requester_id: @requester_id,
          org_id: @org_id
        }

      {:ok, _} = state.grpc_channel |> Stub.modify_group(request)
      assert_request_created(user1.id, state.group.id, "add")
      assert_request_created(user2.id, state.group.id, "add")
      assert_request_created(user3.id, state.group.id, "remove")
      assert Rbac.Repo.GroupManagementRequest |> Rbac.Repo.aggregate(:count, :id) == 3
    end
  end

  describe "create_group/2" do
    test "invalid requests", state do
      requests = [
        %InternalApi.Groups.CreateGroupRequest{},
        %InternalApi.Groups.CreateGroupRequest{requester_id: ""},
        %InternalApi.Groups.CreateGroupRequest{requester_id: "not-valid"},
        %InternalApi.Groups.CreateGroupRequest{requester_id: @requester_id, org_id: ""},
        %InternalApi.Groups.CreateGroupRequest{
          requester_id: @requester_id,
          org_id: "not-valid"
        }
      ]

      Enum.each(requests, fn request ->
        {:error, %{status: status, message: msg}} =
          state.grpc_channel |> Stub.create_group(request)

        assert status == GRPC.Status.invalid_argument()
        assert msg == "Invalid uuid passed as an argument where uuid v4 was expected."
      end)
    end

    test "unauthorized requests", state do
      request =
        %InternalApi.Groups.CreateGroupRequest{
          requester_id: @requester_id,
          org_id: @org_id
        }

      {:error, %{status: status, message: msg}} = state.grpc_channel |> Stub.create_group(request)
      assert status == GRPC.Status.permission_denied()
      assert msg == "User unauthorized"
    end

    test "when group data is missing, we return an error", state do
      request =
        %InternalApi.Groups.CreateGroupRequest{
          requester_id: @requester_id,
          org_id: @org_id
        }

      assert {:error, %{status: status, message: msg}} =
               state.grpc_channel |> Stub.create_group(request)

      assert status == GRPC.Status.invalid_argument()
      assert msg == "No group information provided"
    end

    test "when group name is missing, we return an error", state do
      request =
        %InternalApi.Groups.CreateGroupRequest{
          group: %InternalApi.Groups.Group{},
          requester_id: @requester_id,
          org_id: @org_id
        }

      assert {:error, %{status: status, message: msg}} =
               state.grpc_channel |> Stub.create_group(request)

      assert status == GRPC.Status.invalid_argument()
      assert msg == "Group name is required"
    end

    test "when members are not part of the org, we return an error", state do
      request =
        %InternalApi.Groups.CreateGroupRequest{
          group: %InternalApi.Groups.Group{
            name: "Test Group",
            description: "Test group description",
            member_ids: [Ecto.UUID.generate()]
          },
          requester_id: @requester_id,
          org_id: @org_id
        }

      {:error, %{status: status, message: msg}} = state.grpc_channel |> Stub.create_group(request)
      assert status == GRPC.Status.invalid_argument()
      assert msg =~ "have to already be part of the organization"
    end

    test "group is created, assigned org member role and group management requests are created",
         state do
      {:ok, user1} = Support.Factories.RbacUser.insert()

      Support.Rbac.create_org_roles(@org_id)
      Support.Rbac.assign_org_role_by_name(@org_id, user1.id, "Member")

      request =
        %InternalApi.Groups.CreateGroupRequest{
          group: %InternalApi.Groups.Group{
            name: "Test Group",
            description: "Test group description",
            member_ids: [user1.id]
          },
          requester_id: @requester_id,
          org_id: @org_id
        }

      {:ok, resp} = state.grpc_channel |> Stub.create_group(request)
      {:ok, group} = Rbac.Store.Group.fetch_group(resp.group.id)

      assert group.name == "Test Group"
      assert group.description == "Test group description"

      assert_request_created(user1.id, group.id, "add")
      assert Rbac.Repo.GroupManagementRequest |> Rbac.Repo.aggregate(:count, :id) == 1
    end
  end

  #
  # Helper funcs
  #

  defp authorize_user_for_people_management(user_id, org_id) do
    key = "user:#{user_id}_org:#{org_id}_project:*"

    %Rbac.Repo.UserPermissionsKeyValueStore{key: key, value: "organization.people.manage"}
    |> Rbac.Repo.insert()
  end

  defp assert_request_created(user_id, group_id, action) do
    assert Rbac.Repo.GroupManagementRequest
           |> where(
             [mr],
             mr.group_id == ^group_id and mr.user_id == ^user_id and mr.action == ^action
           )
           |> Rbac.Repo.exists?()
  end
end
