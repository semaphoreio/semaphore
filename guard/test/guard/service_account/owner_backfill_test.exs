defmodule Guard.ServiceAccount.OwnerBackfillTest do
  use Guard.RepoCase, async: false

  import Mock

  alias Guard.FrontRepo
  alias Guard.Store.ServiceAccount
  alias Support.Factories.{FrontUser, OrgMembership, ServiceAccountFactory}

  setup do
    FunRegistry.clear!()
    Guard.FakeServers.setup_responses_for_development()

    org_id = Ecto.UUID.generate()
    {:ok, creator} = FrontUser.insert()

    [org_id: org_id, creator: creator]
  end

  test "gives the creator an account that has no owner", ctx do
    OrgMembership.insert(ctx.creator.id, ctx.org_id)

    {:ok, %{service_account: service_account}} =
      ServiceAccountFactory.insert(org_id: ctx.org_id, creator_id: ctx.creator.id)

    assert Guard.ServiceAccount.OwnerBackfill.process() == :ok

    assert {:ok, %{owner_id: owner_id, owner_active: true}} =
             ServiceAccount.find(service_account.id, ctx.org_id)

    assert owner_id == ctx.creator.id
  end

  test "leaves an account whose creator is no longer a member without one", ctx do
    {:ok, %{service_account: service_account}} =
      ServiceAccountFactory.insert(org_id: ctx.org_id, creator_id: ctx.creator.id)

    assert Guard.ServiceAccount.OwnerBackfill.process() == :ok

    assert {:ok, %{owner_id: nil, owner_active: false}} =
             ServiceAccount.find(service_account.id, ctx.org_id)
  end

  test "leaves an account that already has an owner alone", ctx do
    {:ok, owner} = FrontUser.insert()
    OrgMembership.insert(ctx.creator.id, ctx.org_id)
    OrgMembership.insert(owner.id, ctx.org_id)

    {:ok, %{service_account: service_account}} =
      ServiceAccountFactory.insert(
        org_id: ctx.org_id,
        creator_id: ctx.creator.id,
        owner_id: owner.id
      )

    assert Guard.ServiceAccount.OwnerBackfill.process() == :ok

    assert {:ok, %{owner_id: owner_id}} = ServiceAccount.find(service_account.id, ctx.org_id)
    assert owner_id == owner.id
  end

  test "does not take a creator who is a member of another organization only", ctx do
    OrgMembership.insert(ctx.creator.id, Ecto.UUID.generate())

    {:ok, %{service_account: service_account}} =
      ServiceAccountFactory.insert(org_id: ctx.org_id, creator_id: ctx.creator.id)

    assert Guard.ServiceAccount.OwnerBackfill.process() == :ok

    assert {:ok, %{owner_id: nil}} = ServiceAccount.find(service_account.id, ctx.org_id)
  end

  test "does not give the creator an account whose owner's user record was deleted", ctx do
    {:ok, owner} = FrontUser.insert()
    OrgMembership.insert(ctx.creator.id, ctx.org_id)
    OrgMembership.insert(owner.id, ctx.org_id)

    {:ok, %{service_account: service_account}} =
      ServiceAccountFactory.insert(
        org_id: ctx.org_id,
        creator_id: ctx.creator.id,
        owner_id: owner.id
      )

    # Deleting the owner nulls the column; the account waits for a member rather than
    # falling back on whoever created it.
    FrontRepo.delete!(owner)

    assert Guard.ServiceAccount.OwnerBackfill.process() == :ok

    assert {:ok, %{owner_id: nil, owner_active: false}} =
             ServiceAccount.find(service_account.id, ctx.org_id)
  end

  test "reaches an account behind a batch it can give no owner", ctx do
    OrgMembership.insert(ctx.creator.id, ctx.org_id)
    {:ok, stranger} = FrontUser.insert()

    # An account whose creator is not a member is left as it is, so a pass that stopped
    # after one batch would select these same rows and never reach anything behind them.
    for n <- 1..3 do
      ServiceAccountFactory.insert(
        id: "00000000-0000-4000-8000-00000000000#{n}",
        org_id: ctx.org_id,
        creator_id: stranger.id
      )
    end

    {:ok, %{service_account: service_account}} =
      ServiceAccountFactory.insert(
        id: "00000000-0000-4000-8000-0000000000ff",
        org_id: ctx.org_id,
        creator_id: ctx.creator.id
      )

    assert ServiceAccount.backfill_owners(2) == 1

    assert {:ok, %{owner_id: owner_id}} = ServiceAccount.find(service_account.id, ctx.org_id)
    assert owner_id == ctx.creator.id
  end

  test "leaves an account taken on while the pass was running alone", ctx do
    {:ok, taker} = FrontUser.insert()
    OrgMembership.insert(ctx.creator.id, ctx.org_id)
    OrgMembership.insert(taker.id, ctx.org_id)

    {:ok, %{service_account: service_account}} =
      ServiceAccountFactory.insert(org_id: ctx.org_id, creator_id: ctx.creator.id)

    # Stand in for a member taking the account on between the pass selecting it and
    # writing: the write has to find the row as it is, not as the pass last saw it.
    with_mock Guard.ServiceAccount.Owners,
      active_ids: fn _ids, _org_id ->
        FrontRepo.get!(Guard.FrontRepo.ServiceAccount, service_account.id)
        |> Guard.FrontRepo.ServiceAccount.owner_changeset(%{owner_id: taker.id})
        |> FrontRepo.update!()

        MapSet.new([ctx.creator.id])
      end do
      assert ServiceAccount.backfill_owners() == 0
    end

    assert {:ok, %{owner_id: owner_id}} = ServiceAccount.find(service_account.id, ctx.org_id)
    assert owner_id == taker.id
  end

  test "does not take a creator whose user record was deleted", ctx do
    OrgMembership.insert(ctx.creator.id, ctx.org_id)

    {:ok, %{service_account: service_account}} =
      ServiceAccountFactory.insert(org_id: ctx.org_id, creator_id: ctx.creator.id)

    FrontRepo.delete!(ctx.creator)

    assert Guard.ServiceAccount.OwnerBackfill.process() == :ok

    assert {:ok, %{owner_id: nil}} = ServiceAccount.find(service_account.id, ctx.org_id)
  end
end
