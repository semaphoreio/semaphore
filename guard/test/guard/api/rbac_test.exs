defmodule Guard.Api.RbacTest do
  use ExUnit.Case, async: false

  import Mock

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
        |> Enum.map(fn id ->
          RBAC.ListMembersResponse.Member.new(
            subject:
              RBAC.Subject.new(
                subject_id: id,
                subject_type: RBAC.SubjectType.value(:USER)
              )
          )
        end)

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
  end
end
