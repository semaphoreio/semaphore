defmodule Front.DashboardPage.ModelTest do
  use ExUnit.Case

  alias Front.DashboardPage.Model
  alias Front.DashboardPage.Model.LoadParams

  setup do
    Cacheman.clear(:front)
    :ok
  end

  describe "cache_key" do
    test "constructs cache key based on org, user and requester" do
      params =
        struct!(LoadParams,
          organization_id: "org-1",
          user_id: "user-1",
          requester: true
        )

      assert Model.cache_key(params) ==
               "#{Model.cache_prefix()}/#{Model.cache_version()}/organization_id=org-1/user_id=user-1/requester=true/"
    end
  end

  describe "get" do
    test "returns cached value for first page requests" do
      params =
        struct!(LoadParams,
          organization_id: "org-1",
          user_id: "user-1",
          requester: false,
          page_token: ""
        )

      assert {:ok, {[:workflow], "next", "previous"}, :from_api} =
               Model.get(params, fn -> {:ok, [:workflow], "next", "previous"} end)

      assert {:ok, {[:workflow], "next", "previous"}, :from_cache} =
               Model.get(params, fn ->
                 flunk("fetch callback should not run when cache is hit")
               end)
    end

    test "does not cache non-first-page requests" do
      params =
        struct!(LoadParams,
          organization_id: "org-1",
          user_id: "user-1",
          requester: false,
          page_token: "token-1"
        )

      assert {:ok, {[:workflow], "next", "previous"}, :from_api} =
               Model.get(params, fn -> {:ok, [:workflow], "next", "previous"} end)

      assert {:error, :timeout} = Model.get(params, fn -> {:error, :timeout} end)
    end
  end

  describe "invalidate_org" do
    test "removes only entries for the target organization" do
      org1_params =
        struct!(LoadParams,
          organization_id: "org-1",
          user_id: "user-1",
          requester: false
        )

      org2_params =
        struct!(LoadParams,
          organization_id: "org-2",
          user_id: "user-1",
          requester: false
        )

      {:ok, _payload, :from_api} = Model.get(org1_params, fn -> {:ok, [:org1], "", ""} end)
      {:ok, _payload, :from_api} = Model.get(org2_params, fn -> {:ok, [:org2], "", ""} end)

      assert Cacheman.exists?(:front, Model.cache_key(org1_params))
      assert Cacheman.exists?(:front, Model.cache_key(org2_params))

      :ok = Model.invalidate_org("org-1")

      refute Cacheman.exists?(:front, Model.cache_key(org1_params))
      assert Cacheman.exists?(:front, Model.cache_key(org2_params))
    end
  end

  describe "invalidate_all" do
    test "removes all dashboard page entries" do
      params =
        struct!(LoadParams,
          organization_id: "org-1",
          user_id: "user-1",
          requester: false
        )

      {:ok, _payload, :from_api} = Model.get(params, fn -> {:ok, [:workflow], "", ""} end)
      assert Cacheman.exists?(:front, Model.cache_key(params))

      :ok = Model.invalidate_all()

      refute Cacheman.exists?(:front, Model.cache_key(params))
    end
  end
end
