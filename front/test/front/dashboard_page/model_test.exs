defmodule Front.DashboardPage.ModelTest do
  use ExUnit.Case

  alias Front.DashboardPage.Model
  alias Front.DashboardPage.Model.LoadParams

  setup do
    Cacheman.clear(:front)
    :ok
  end

  describe "cache_key" do
    test "constructs cache key based on org, user, requester and project access fingerprint" do
      params =
        struct!(LoadParams,
          organization_id: "org-1",
          user_id: "user-1",
          requester: true,
          project_ids_fingerprint: "projects-v1"
        )

      assert Model.cache_key(params) ==
               "#{Model.cache_prefix()}/#{Model.cache_version()}/organization_id=org-1/user_id=user-1/requester=true/project_ids_fingerprint=projects-v1/"
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

    test "bypasses cache when force_cold_boot is true" do
      params =
        struct!(LoadParams,
          organization_id: "org-1",
          user_id: "user-1",
          requester: false,
          page_token: ""
        )

      assert {:ok, {[:cached], "next", "previous"}, :from_api} =
               Model.get(params, fn -> {:ok, [:cached], "next", "previous"} end)

      assert {:ok, {[:fresh], "next-2", "previous-2"}, :from_api} =
               Model.get(
                 params,
                 fn -> {:ok, [:fresh], "next-2", "previous-2"} end,
                 force_cold_boot: "true"
               )

      assert {:ok, {[:fresh], "next-2", "previous-2"}, :from_cache} =
               Model.get(params, fn ->
                 flunk("fetch callback should not run when refreshed cache is hit")
               end)
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

    test "removes all keys after concurrent cache writes for the same organization" do
      org_id = "org-concurrent"
      user_id = "user-1"
      fingerprints = Enum.map(1..20, &"projects-#{&1}")

      fingerprints
      |> Task.async_stream(
        fn fingerprint ->
          params =
            struct!(LoadParams,
              organization_id: org_id,
              user_id: user_id,
              requester: false,
              project_ids_fingerprint: fingerprint
            )

          Model.get(params, fn -> {:ok, [fingerprint], "", ""} end)
        end,
        max_concurrency: 20,
        timeout: :timer.seconds(5)
      )
      |> Enum.each(fn {:ok, {:ok, _payload, :from_api}} -> :ok end)

      keys =
        Enum.map(fingerprints, fn fingerprint ->
          params =
            struct!(LoadParams,
              organization_id: org_id,
              user_id: user_id,
              requester: false,
              project_ids_fingerprint: fingerprint
            )

          Model.cache_key(params)
        end)

      assert Enum.all?(keys, &Cacheman.exists?(:front, &1))

      :ok = Model.invalidate_org(org_id)

      refute Enum.any?(keys, &Cacheman.exists?(:front, &1))
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

  describe "index set TTL" do
    test "org index set has a TTL after cache write" do
      params =
        struct!(LoadParams,
          organization_id: "org-ttl",
          user_id: "user-1",
          requester: false
        )

      {:ok, _payload, :from_api} = Model.get(params, fn -> {:ok, [:workflow], "", ""} end)

      org_set_key = "#{Model.cache_prefix()}/#{Model.cache_version()}/index/org=org-ttl"
      all_orgs_key = "#{Model.cache_prefix()}/#{Model.cache_version()}/index/all_orgs"

      assert redis_ttl(org_set_key) > 0
      assert redis_ttl(all_orgs_key) > 0
    end

    test "org index set TTL is refreshed on subsequent writes" do
      params =
        struct!(LoadParams,
          organization_id: "org-ttl-refresh",
          user_id: "user-1",
          requester: false
        )

      {:ok, _payload, :from_api} = Model.get(params, fn -> {:ok, [:workflow], "", ""} end)

      org_set_key = "#{Model.cache_prefix()}/#{Model.cache_version()}/index/org=org-ttl-refresh"

      ttl_after_first_write = redis_ttl(org_set_key)
      assert ttl_after_first_write > 0

      # Second write with different fingerprint refreshes TTL
      params2 =
        struct!(LoadParams,
          organization_id: "org-ttl-refresh",
          user_id: "user-2",
          requester: false
        )

      {:ok, _payload, :from_api} = Model.get(params2, fn -> {:ok, [:workflow2], "", ""} end)

      ttl_after_second_write = redis_ttl(org_set_key)
      assert ttl_after_second_write > 0
      assert ttl_after_second_write >= ttl_after_first_write
    end
  end

  describe "invalidate_org with expired payload keys" do
    test "invalidation is a no-op for already-expired payload keys" do
      org_id = "org-expired"

      params =
        struct!(LoadParams,
          organization_id: org_id,
          user_id: "user-1",
          requester: false
        )

      {:ok, _payload, :from_api} = Model.get(params, fn -> {:ok, [:workflow], "", ""} end)
      assert Cacheman.exists?(:front, Model.cache_key(params))

      # Simulate payload expiring via TTL before invalidation runs
      Cacheman.delete(:front, Model.cache_key(params))
      refute Cacheman.exists?(:front, Model.cache_key(params))

      # Should not raise even though the payload key is already gone
      :ok = Model.invalidate_org(org_id)
    end
  end

  describe "invalidate_all with multiple orgs" do
    test "removes entries across all organizations" do
      org1_params =
        struct!(LoadParams,
          organization_id: "org-all-1",
          user_id: "user-1",
          requester: false
        )

      org2_params =
        struct!(LoadParams,
          organization_id: "org-all-2",
          user_id: "user-1",
          requester: false
        )

      {:ok, _payload, :from_api} = Model.get(org1_params, fn -> {:ok, [:org1], "", ""} end)
      {:ok, _payload, :from_api} = Model.get(org2_params, fn -> {:ok, [:org2], "", ""} end)

      assert Cacheman.exists?(:front, Model.cache_key(org1_params))
      assert Cacheman.exists?(:front, Model.cache_key(org2_params))

      :ok = Model.invalidate_all()

      refute Cacheman.exists?(:front, Model.cache_key(org1_params))
      refute Cacheman.exists?(:front, Model.cache_key(org2_params))
    end
  end

  defp redis_ttl(key) do
    state = :sys.get_state(Cacheman.full_process_name(:front))

    :poolboy.transaction(state.backend_pid, fn conn ->
      {:ok, ttl} = Redix.command(conn, ["TTL", state.prefix <> key])
      ttl
    end)
  end
end
