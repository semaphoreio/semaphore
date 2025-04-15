defmodule Rbac.Workers.GroupManagementWorkerTest do
  use Rbac.RepoCase, async: true
  import Mock

  alias Rbac.Store.Group
  alias Rbac.Repo.GroupManagementRequest
  alias Rbac.Workers.GroupManagement

  setup do
    {:ok, group} = Support.Factories.Group.insert()
    {:ok, user} = Support.Factories.RbacUser.insert()
    %{group_id: group.id, user_id: user.id}
  end

  describe "perform/1" do
    test "When request is nil" do
      assert GroupManagement.perform() == :ok
    end

    test "when request for adding users to a group exists", ctx do
      create_request(ctx, :add_user)

      with_mock Group, [:passthrough],
        add_to_group: fn group, user_id ->
          assert ctx.group_id == group.id
          assert ctx.user_id == user_id
          :ok
        end do
        GroupManagement.perform()
        assert_called_exactly(Group.add_to_group(:_, :_), 1)
      end

      request = GroupManagementRequest |> Rbac.Repo.one()
      assert request.state == :done
    end

    test "when request for removing users from a group exists", ctx do
      create_request(ctx, :remove_user)

      with_mock Group, [:passthrough],
        remove_from_group: fn group, user_id ->
          assert ctx.group_id == group.id
          assert ctx.user_id == user_id
          :ok
        end do
        GroupManagement.perform()
        assert_called_exactly(Group.remove_from_group(:_, :_), 1)
      end

      request = GroupManagementRequest |> Rbac.Repo.one()
      assert request.state == :done
    end

    test "when request for destroying a group exists", ctx do
      create_request(ctx, :destroy_group)

      with_mock Group, [:passthrough],
        destroy: fn group ->
          assert ctx.group_id == group.id
          :ok
        end do
        GroupManagement.perform()
        assert_called_exactly(Group.destroy(:_), 1)
      end

      request = GroupManagementRequest |> Rbac.Repo.one()
      assert request.state == :done
    end

    test "when an error occurs during processing", ctx do
      create_request(ctx, :add_user)

      with_mock Group, [:passthrough],
        add_to_group: fn _group, _user_id ->
          {:error, :some_error}
        end do
        GroupManagement.perform()
        assert_called_exactly(Group.add_to_group(:_, :_), 1)
      end

      request = GroupManagementRequest |> Rbac.Repo.one()
      assert request.state == :failed
    end
  end

  ###
  ### Helper functions
  ###

  defp create_request(ctx, action) do
    GroupManagementRequest.create_new_request(
      ctx.user_id,
      ctx.group_id,
      action,
      Ecto.UUID.generate()
    )
  end
end
