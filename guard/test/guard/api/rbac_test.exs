defmodule Guard.Api.RbacTest do
  use ExUnit.Case, async: false

  import Mock
  import ExUnit.CaptureLog

  alias Guard.Api.Rbac
  alias InternalApi.RBAC

  @org_id "11111111-1111-1111-1111-111111111111"
  @page_size 100

  # Mimics a ListMembers backend holding `total` members under either edition's
  # pagination convention, so the guard client is exercised the way prod behaves:
  #
  #   * :ee -> 0-based, offset = page_no * size
  #   * :ce -> 1-based, page_no 0 is coerced to 1, offset = (page_no - 1) * size
  #            (so page_no 0 and 1 both return the first page)
  defp list_members_responder(total, convention) do
    all_ids = Enum.map(1..total, &"user-#{&1}")

    fn _channel, req, _opts ->
      offset =
        case convention do
          :ee -> req.page.page_no * @page_size
          :ce -> (max(req.page.page_no, 1) - 1) * @page_size
        end

      members =
        all_ids
        |> Enum.slice(offset, @page_size)
        |> Enum.map(&member/1)

      total_pages = div(total + @page_size - 1, @page_size)
      {:ok, RBAC.ListMembersResponse.new(members: members, total_pages: total_pages)}
    end
  end

  for convention <- [:ee, :ce] do
    test "no_of_members and list_members are exact across pages (#{convention} backend)" do
      total = 250

      with_mock RBAC.RBAC.Stub, list_members: list_members_responder(total, unquote(convention)) do
        assert Rbac.no_of_members(@org_id) == total

        ids = Rbac.list_members(@org_id) |> Enum.map(& &1.subject.subject_id)
        assert length(ids) == total
        assert Enum.uniq(ids) == ids
      end
    end

    test "single_member? is true only for exactly one member (#{convention} backend)" do
      with_mock RBAC.RBAC.Stub, list_members: list_members_responder(1, unquote(convention)) do
        assert Rbac.single_member?(@org_id) == {:ok, true}
      end
    end

    test "single_member? is false for more than one member (#{convention} backend)" do
      with_mock RBAC.RBAC.Stub, list_members: list_members_responder(2, unquote(convention)) do
        assert Rbac.single_member?(@org_id) == {:ok, false}
      end
    end

    test "single_member? is false for a multi-page org (#{convention} backend)" do
      with_mock RBAC.RBAC.Stub, list_members: list_members_responder(150, unquote(convention)) do
        assert Rbac.single_member?(@org_id) == {:ok, false}
      end
    end
  end

  test "single_member? dedups repeated subject rows on the first page (ce)" do
    # CE returns one row per role assignment, so a single user with several org
    # roles appears multiple times on page 0 but must still count as one member.
    responder = fn _channel, req, _opts ->
      members =
        if req.page.page_no == 0, do: Enum.map(1..3, fn _ -> member("user-1") end), else: []

      {:ok, RBAC.ListMembersResponse.new(members: members, total_pages: 1)}
    end

    with_mock RBAC.RBAC.Stub, list_members: responder do
      assert Rbac.single_member?(@org_id) == {:ok, true}
    end
  end

  test "org_owner_ids returns an error and warns when the Owner role cannot be resolved" do
    list_roles_without_owner = fn _channel, _req, _opts ->
      {:ok, RBAC.ListRolesResponse.new(roles: [RBAC.Role.new(id: "role-admin", name: "Admin")])}
    end

    log =
      capture_log(fn ->
        with_mock RBAC.RBAC.Stub, list_roles: list_roles_without_owner do
          assert Rbac.org_owner_ids(@org_id) == {:error, :owner_role_unresolved}
        end
      end)

    assert log =~ "Owner role not found"
  end

  test "single_member? returns an error when the member lookup fails" do
    failing = fn _channel, _req, _opts ->
      {:error, %GRPC.RPCError{status: 14, message: "unavailable"}}
    end

    log =
      capture_log(fn ->
        with_mock RBAC.RBAC.Stub, list_members: failing do
          assert Rbac.single_member?(@org_id) == {:error, :ownership_unverified}
        end
      end)

    assert log =~ "member lookup failed"
  end

  test "org_owner_ids includes users owning through a group next to direct owners" do
    with_mock RBAC.RBAC.Stub,
      list_roles: list_roles_with_owner_fn(),
      list_members: owner_members_responder(users: ["user-direct"], groups: ["group-1"]) do
      with_mock InternalApi.Groups.Groups.Stub,
        list_groups: groups_responder(%{"group-1" => ["user-alice", "user-direct"]}) do
        assert {:ok, ids} = Rbac.org_owner_ids(@org_id)
        assert Enum.sort(ids) == ["user-alice", "user-direct"]
      end
    end
  end

  test "org_owner_ids resolves owners held only through a group" do
    with_mock RBAC.RBAC.Stub,
      list_roles: list_roles_with_owner_fn(),
      list_members: owner_members_responder(users: [], groups: ["group-1"]) do
      with_mock InternalApi.Groups.Groups.Stub,
        list_groups: groups_responder(%{"group-1" => ["user-alice", "user-bob"]}) do
        assert {:ok, ids} = Rbac.org_owner_ids(@org_id)
        assert Enum.sort(ids) == ["user-alice", "user-bob"]
      end
    end
  end

  test "org_owner_ids stays direct-only when the backend reports no owner groups" do
    with_mock RBAC.RBAC.Stub,
      list_roles: list_roles_with_owner_fn(),
      list_members: owner_members_responder(users: ["user-direct"], groups: []) do
      assert Rbac.org_owner_ids(@org_id) == {:ok, ["user-direct"]}
    end
  end

  test "org_owner_ids expands owner groups through the groups endpoint, not the rbac one" do
    test_pid = self()
    groups_endpoint = "groups.internal:50051"
    rbac_endpoint = Application.fetch_env!(:guard, :rbac_grpc_endpoint)
    original = Application.get_env(:guard, :groups_grpc_endpoint)
    Application.put_env(:guard, :groups_grpc_endpoint, groups_endpoint)
    on_exit(fn -> Application.put_env(:guard, :groups_grpc_endpoint, original) end)

    members = fn channel, req, _opts ->
      send(test_pid, {:rbac_channel, channel})
      owner_members_responder(users: [], groups: ["group-1"]).(channel, req, [])
    end

    groups = fn channel, req, _opts ->
      send(test_pid, {:groups_channel, channel})
      groups_responder(%{"group-1" => ["user-alice"]}).(channel, req, [])
    end

    with_mock GRPC.Stub, [:passthrough], connect: fn endpoint -> {:ok, {:channel, endpoint}} end do
      with_mock RBAC.RBAC.Stub, list_roles: list_roles_with_owner_fn(), list_members: members do
        with_mock InternalApi.Groups.Groups.Stub, list_groups: groups do
          assert {:ok, ["user-alice"]} = Rbac.org_owner_ids(@org_id)
        end
      end
    end

    assert_received {:rbac_channel, {:channel, ^rbac_endpoint}}
    assert_received {:groups_channel, {:channel, ^groups_endpoint}}
  end

  test "org_owner_ids fails closed when expanding an owner group fails" do
    failing_groups = fn _channel, _req, _opts ->
      {:error, %GRPC.RPCError{status: 14, message: "unavailable"}}
    end

    log =
      capture_log(fn ->
        with_mock RBAC.RBAC.Stub,
          list_roles: list_roles_with_owner_fn(),
          list_members: owner_members_responder(users: ["user-direct"], groups: ["group-1"]) do
          with_mock InternalApi.Groups.Groups.Stub, list_groups: failing_groups do
            assert Rbac.org_owner_ids(@org_id) == {:error, :ownership_unverified}
          end
        end
      end)

    assert log =~ "owner lookup failed"
  end

  # ListMembers responder keyed by the requested member_type: owner users for
  # :USER, owner groups for :GROUP (single short page each, like both backends).
  defp owner_members_responder(users: user_ids, groups: group_ids) do
    fn _channel, req, _opts ->
      ids =
        cond do
          req.member_type == RBAC.SubjectType.value(:USER) -> user_ids
          req.member_type == RBAC.SubjectType.value(:GROUP) -> group_ids
        end

      members = if req.page.page_no in [0, 1], do: Enum.map(ids, &member/1), else: []
      {:ok, RBAC.ListMembersResponse.new(members: members, total_pages: 1)}
    end
  end

  defp groups_responder(members_by_group) do
    fn _channel, req, _opts ->
      groups =
        case Map.fetch(members_by_group, req.group_id) do
          {:ok, member_ids} ->
            [InternalApi.Groups.Group.new(id: req.group_id, member_ids: member_ids)]

          :error ->
            []
        end

      {:ok, InternalApi.Groups.ListGroupsResponse.new(groups: groups)}
    end
  end

  defp list_roles_with_owner_fn do
    fn _channel, _req, _opts ->
      {:ok, RBAC.ListRolesResponse.new(roles: [RBAC.Role.new(id: "role-owner", name: "Owner")])}
    end
  end

  test "org_owner_ids returns an error when the owner lookup fails" do
    list_roles_with_owner = fn _channel, _req, _opts ->
      {:ok, RBAC.ListRolesResponse.new(roles: [RBAC.Role.new(id: "role-owner", name: "Owner")])}
    end

    failing_members = fn _channel, _req, _opts ->
      {:error, %GRPC.RPCError{status: 14, message: "unavailable"}}
    end

    log =
      capture_log(fn ->
        with_mock RBAC.RBAC.Stub,
          list_roles: list_roles_with_owner,
          list_members: failing_members do
          assert Rbac.org_owner_ids(@org_id) == {:error, :ownership_unverified}
        end
      end)

    assert log =~ "owner lookup failed"
  end

  defp member(id) do
    RBAC.ListMembersResponse.Member.new(
      subject: RBAC.Subject.new(subject_id: id, subject_type: RBAC.SubjectType.value(:USER))
    )
  end
end
