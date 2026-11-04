defmodule Front.Layout.ModelTest do
  use Front.TestCase

  alias Front.Layout.Model
  alias Front.Layout.Model.LoadParams
  alias Support.Stubs

  describe ".load_from_api" do
    test "it completes without error" do
      user = Stubs.User.create_default()
      org = Stubs.Organization.create_default()

      params =
        struct!(LoadParams,
          user_id: user.id,
          organization_id: org.id
        )

      {:ok, _data, :from_api} = Model.load_from_api(params)
    end

    test "when the organization has suspensions => loads them" do
      alias InternalApi.Organization.Suspension

      user = Stubs.User.create_default()
      org = Stubs.Organization.create_default()

      Stubs.Organization.suspend(
        org,
        reason: Suspension.Reason.value(:VIOLATION_OF_TOS)
      )

      params =
        struct!(LoadParams,
          user_id: user.id,
          organization_id: org.id
        )

      {:ok, data, :from_api} = Model.load_from_api(params)

      assert data.suspensions == [:VIOLATION_OF_TOS]
    end
  end

  describe ".invalidate_many" do
    test "drops only the given keys, missing keys and empty lists are fine" do
      params =
        for i <- 1..3 do
          %LoadParams{user_id: "user-#{i}-#{UUID.uuid4()}", organization_id: "org"}
        end

      Enum.each(params, &Cacheman.put(:front, Model.cache_key(&1), "x"))

      [a, b, c] = params
      missing = %LoadParams{user_id: UUID.uuid4(), organization_id: "org"}

      assert :ok = Model.invalidate_many([a, b, missing])
      refute Cacheman.exists?(:front, Model.cache_key(a))
      refute Cacheman.exists?(:front, Model.cache_key(b))
      assert Cacheman.exists?(:front, Model.cache_key(c))

      assert :ok = Model.invalidate_many([])
      assert :ok = Model.invalidate(c)
      refute Cacheman.exists?(:front, Model.cache_key(c))
      assert :ok = Model.invalidate(c)
    end

    test "handles more keys than one batch" do
      params = for _ <- 1..1_100, do: %LoadParams{user_id: UUID.uuid4(), organization_id: "org"}

      Enum.each(params, &Cacheman.put(:front, Model.cache_key(&1), "x"))

      assert :ok = Model.invalidate_many(params)
      refute Enum.any?(params, &Cacheman.exists?(:front, Model.cache_key(&1)))
    end
  end
end
