defmodule Guard.ServiceAccount.OwnersTest do
  use Guard.RepoCase, async: false

  alias Guard.FrontRepo
  alias Guard.FrontRepo.User
  alias Guard.ServiceAccount.Owners
  alias Support.Factories.{FrontUser, OrgMembership, ServiceAccountFactory}

  setup do
    FunRegistry.clear!()
    Guard.FakeServers.setup_responses_for_development()

    org_id = Ecto.UUID.generate()
    {:ok, member} = FrontUser.insert()
    OrgMembership.insert(member.id, org_id)

    [org_id: org_id, member: member]
  end

  describe "active?/2" do
    test "accepts a member of the organization", ctx do
      assert Owners.active?(ctx.member.id, ctx.org_id)
    end

    test "refuses a user who is not a member", ctx do
      {:ok, outsider} = FrontUser.insert()

      refute Owners.active?(outsider.id, ctx.org_id)
    end

    test "refuses a member of another organization", ctx do
      refute Owners.active?(ctx.member.id, Ecto.UUID.generate())
    end

    test "refuses a member who was removed from the organization", ctx do
      OrgMembership.remove(ctx.member.id, ctx.org_id)

      refute Owners.active?(ctx.member.id, ctx.org_id)
    end

    test "refuses a blocked member", ctx do
      ctx.member |> User.changeset(%{blocked_at: DateTime.utc_now()}) |> FrontRepo.update!()

      refute Owners.active?(ctx.member.id, ctx.org_id)
    end

    test "refuses a deactivated member", ctx do
      ctx.member |> User.changeset(%{deactivated: true}) |> FrontRepo.update!()

      refute Owners.active?(ctx.member.id, ctx.org_id)
    end

    test "refuses a service account, which is a member in its own right", ctx do
      {:ok, %{service_account: service_account}} =
        ServiceAccountFactory.insert(org_id: ctx.org_id)

      OrgMembership.insert(service_account.id, ctx.org_id, type: "service_account")

      refute Owners.active?(service_account.id, ctx.org_id)
    end

    test "refuses nothing at all", ctx do
      refute Owners.active?(nil, ctx.org_id)
      refute Owners.active?("", ctx.org_id)
      refute Owners.active?("not-a-uuid", ctx.org_id)
      refute Owners.active?(ctx.member.id, "not-a-uuid")
    end
  end

  describe "active_ids/2" do
    test "keeps only the members", ctx do
      {:ok, outsider} = FrontUser.insert()
      {:ok, second_member} = FrontUser.insert()
      OrgMembership.insert(second_member.id, ctx.org_id)

      active = Owners.active_ids([ctx.member.id, outsider.id, second_member.id, nil], ctx.org_id)

      assert MapSet.equal?(active, MapSet.new([ctx.member.id, second_member.id]))
    end

    test "is empty for an empty list", ctx do
      assert MapSet.size(Owners.active_ids([], ctx.org_id)) == 0
    end
  end
end
