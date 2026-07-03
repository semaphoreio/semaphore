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
        assert Rbac.single_member?(@org_id)
      end
    end

    test "single_member? is false for more than one member (#{convention} backend)" do
      with_mock RBAC.RBAC.Stub, list_members: list_members_responder(2, unquote(convention)) do
        refute Rbac.single_member?(@org_id)
      end
    end

    test "single_member? is false for a multi-page org (#{convention} backend)" do
      with_mock RBAC.RBAC.Stub, list_members: list_members_responder(150, unquote(convention)) do
        refute Rbac.single_member?(@org_id)
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
      assert Rbac.single_member?(@org_id)
    end
  end

  test "org_owner_ids returns [] and warns when the Owner role cannot be resolved" do
    list_roles_without_owner = fn _channel, _req, _opts ->
      {:ok, RBAC.ListRolesResponse.new(roles: [RBAC.Role.new(id: "role-admin", name: "Admin")])}
    end

    log =
      capture_log(fn ->
        with_mock RBAC.RBAC.Stub, list_roles: list_roles_without_owner do
          assert Rbac.org_owner_ids(@org_id) == []
        end
      end)

    assert log =~ "Owner role not found"
  end

  defp member(id) do
    RBAC.ListMembersResponse.Member.new(
      subject: RBAC.Subject.new(subject_id: id, subject_type: RBAC.SubjectType.value(:USER))
    )
  end
end
