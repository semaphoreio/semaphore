defmodule Front.DashboardPage.ModelTest do
  use ExUnit.Case

  alias Front.DashboardPage.Model
  alias Front.DashboardPage.Model.LoadParams

  @payload_without_index_script """
  local payload_exists = redis.call('EXISTS', KEYS[1])
  if payload_exists == 0 then
    return 0
  end

  local tracked = redis.call('SISMEMBER', KEYS[2], ARGV[1])
  if tracked == 1 then
    return 0
  end

  return 1
  """

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

  describe "atomic invalidation (race condition regression)" do
    test "keys written concurrently with invalidation are not orphaned" do
      # Regression: non-atomic SMEMBERS → DEL keys → DEL set could orphan a key
      # written between SMEMBERS and DEL set, leaving it unreachable by future
      # invalidations. With atomic Lua-based invalidation this cannot happen:
      # any surviving key must remain tracked so a follow-up invalidation removes it.
      org_id = "org-race"

      Enum.each(1..5, fn i ->
        params =
          struct!(LoadParams,
            organization_id: org_id,
            user_id: "user-pre-#{i}",
            requester: false
          )

        Model.get(params, fn -> {:ok, [:"pre_#{i}"], "", ""} end)
      end)

      # Fire invalidation + new writes concurrently
      tasks =
        [Task.async(fn -> Model.invalidate_org(org_id) end)] ++
          Enum.map(1..10, fn i ->
            Task.async(fn ->
              params =
                struct!(LoadParams,
                  organization_id: org_id,
                  user_id: "user-race-#{i}",
                  requester: false
                )

              Model.get(params, fn -> {:ok, [:"race_#{i}"], "", ""} end)
            end)
          end)

      Task.await_many(tasks, :timer.seconds(5))

      # A second invalidation must be able to clean up every surviving entry.
      # Under the old non-atomic code, orphaned keys would escape this.
      :ok = Model.invalidate_org(org_id)

      all_params =
        Enum.map(1..5, fn i ->
          struct!(LoadParams,
            organization_id: org_id,
            user_id: "user-pre-#{i}",
            requester: false
          )
        end) ++
          Enum.map(1..10, fn i ->
            struct!(LoadParams,
              organization_id: org_id,
              user_id: "user-race-#{i}",
              requester: false
            )
          end)

      Enum.each(all_params, fn params ->
        refute Cacheman.exists?(:front, Model.cache_key(params)),
               "orphaned key: #{Model.cache_key(params)}"
      end)
    end

    test "repeated concurrent write/invalidation cycles leave no stale entries" do
      org_id = "org-stress"

      # Run 20 cycles of concurrent writes + invalidation to exercise timing
      Enum.each(1..20, fn cycle ->
        writer_tasks =
          Enum.map(1..5, fn i ->
            Task.async(fn ->
              params =
                struct!(LoadParams,
                  organization_id: org_id,
                  user_id: "user-#{cycle}-#{i}",
                  requester: false
                )

              Model.get(params, fn -> {:ok, [:"c#{cycle}_#{i}"], "", ""} end)
            end)
          end)

        invalidator = Task.async(fn -> Model.invalidate_org(org_id) end)

        Task.await_many([invalidator | writer_tasks], :timer.seconds(5))
      end)

      # Final invalidation must reach every surviving key
      :ok = Model.invalidate_org(org_id)

      all_params =
        for cycle <- 1..20, i <- 1..5 do
          struct!(LoadParams,
            organization_id: org_id,
            user_id: "user-#{cycle}-#{i}",
            requester: false
          )
        end

      Enum.each(all_params, fn params ->
        refute Cacheman.exists?(:front, Model.cache_key(params)),
               "stale key after stress cycles: #{Model.cache_key(params)}"
      end)
    end

    test "surviving key from concurrent write is reachable by next invalidation" do
      org_id = "org-survive"

      # Write a key that we'll check individually
      target_params =
        struct!(LoadParams,
          organization_id: org_id,
          user_id: "user-target",
          requester: false
        )

      # Run invalidation while simultaneously writing the target key, many times
      # to increase the chance of hitting the interleaving window
      Enum.each(1..30, fn _ ->
        # Seed an initial entry so the org set exists
        seed_params =
          struct!(LoadParams,
            organization_id: org_id,
            user_id: "user-seed",
            requester: false
          )

        Model.get(seed_params, fn -> {:ok, [:seed], "", ""} end)

        tasks = [
          Task.async(fn -> Model.invalidate_org(org_id) end),
          Task.async(fn ->
            Model.get(target_params, fn -> {:ok, [:target], "", ""} end)
          end)
        ]

        Task.await_many(tasks, :timer.seconds(5))

        # If target's cache entry survived the concurrent invalidation,
        # it MUST be removable by a follow-up invalidation
        if Cacheman.exists?(:front, Model.cache_key(target_params)) do
          :ok = Model.invalidate_org(org_id)

          refute Cacheman.exists?(:front, Model.cache_key(target_params)),
                 "orphaned key survived follow-up invalidation"
        end

        # Clean up for next iteration
        Model.invalidate_org(org_id)
      end)
    end
  end

  describe "atomic cache_and_track (race condition regression)" do
    test "never exposes payload key without org index membership under concurrent load" do
      org_id = "org-write-atomic"

      params_list =
        Enum.map(1..20, fn i ->
          struct!(LoadParams,
            organization_id: org_id,
            user_id: "user-#{i}",
            requester: false,
            project_ids_fingerprint: "fp-#{i}"
          )
        end)

      keys = Enum.map(params_list, &Model.cache_key/1)
      org_set_key = "#{Model.cache_prefix()}/#{Model.cache_version()}/index/org=#{org_id}"
      parent = self()

      auditor =
        Task.async(fn ->
          Enum.each(1..250, fn _ ->
            Enum.each(keys, fn key ->
              if redis_payload_without_index?(org_set_key, key) do
                send(parent, {:payload_without_index, key})
              end
            end)

            Process.sleep(2)
          end)
        end)

      writer_tasks =
        Enum.map(0..3, fn offset ->
          Task.async(fn ->
            Enum.each(1..120, fn iter ->
              params = Enum.at(params_list, rem(iter + offset, length(params_list)))

              assert {:ok, {_workflows, "", ""}, :from_api} =
                       Model.get(
                         params,
                         fn -> {:ok, [:"w#{offset}_#{iter}"], "", ""} end,
                         force_cold_boot: true
                       )
            end)
          end)
        end)

      invalidator =
        Task.async(fn ->
          Enum.each(1..90, fn _ ->
            :ok = Model.invalidate_org(org_id)
            Process.sleep(1)
          end)
        end)

      Task.await_many(writer_tasks ++ [invalidator, auditor], :timer.seconds(20))

      refute_received {:payload_without_index, _}

      Enum.each(keys, fn key ->
        refute redis_payload_without_index?(org_set_key, key),
               "payload key exists without org index: #{key}"
      end)
    end
  end

  defp redis_ttl(key) do
    state = :sys.get_state(Cacheman.full_process_name(:front))

    :poolboy.transaction(state.backend_pid, fn conn ->
      {:ok, ttl} = Redix.command(conn, ["TTL", state.prefix <> key])
      ttl
    end)
  end

  defp redis_payload_without_index?(org_set_key, payload_key) do
    state = :sys.get_state(Cacheman.full_process_name(:front))

    :poolboy.transaction(state.backend_pid, fn conn ->
      command = [
        "EVAL",
        @payload_without_index_script,
        "2",
        state.prefix <> payload_key,
        state.prefix <> org_set_key,
        payload_key
      ]

      case Redix.command(conn, command) do
        {:ok, 1} -> true
        _ -> false
      end
    end)
  end
end
