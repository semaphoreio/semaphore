defmodule Mix.Tasks.Cache.BackfillCephTest do
  use Projecthub.DataCase
  import ExUnit.CaptureIO

  setup do
    Application.ensure_all_started(:logger)
    :ok
  end

  test "queues provisioning for projects with cache_id and org filter" do
    Mix.Task.reenable("cache.backfill_ceph")
    test_pid = self()

    {:ok, p1} =
      Support.Factories.Project.create(%{organization_id: Ecto.UUID.generate(), cache_id: Ecto.UUID.generate()})

    {:ok, _p2} =
      Support.Factories.Project.create(%{organization_id: Ecto.UUID.generate(), cache_id: Ecto.UUID.generate()})

    {:ok, _p3} = Support.Factories.Project.create(%{organization_id: p1.organization_id, cache_id: nil})

    FunRegistry.set!(Support.FakeServices.CacheService, :provision_ceph_cache, fn req, _ ->
      send(test_pid, {:provision_ceph_cache_request, req})

      InternalApi.Cache.ProvisionCephCacheResponse.new(
        status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK))
      )
    end)

    output =
      capture_io(fn ->
        Mix.Tasks.Cache.BackfillCeph.run(["--org-id", p1.organization_id])
      end)

    assert output =~ "total=1"
    assert output =~ "queued=1"
    assert_receive {:provision_ceph_cache_request, req}
    assert req.cache_id == p1.cache_id
    assert req.organization_id == p1.organization_id
    assert req.project_id == p1.id
  end

  test "raises when there are provisioning failures without --allow-failures" do
    Mix.Task.reenable("cache.backfill_ceph")
    {:ok, p1} = Support.Factories.Project.create(%{cache_id: Ecto.UUID.generate()})

    FunRegistry.set!(Support.FakeServices.CacheService, :provision_ceph_cache, fn _req, _ ->
      InternalApi.Cache.ProvisionCephCacheResponse.new(
        status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:BAD_PARAM))
      )
    end)

    assert_raise Mix.Error, ~r/Failed to queue 1 cache\(s\)/, fn ->
      capture_io(fn ->
        Mix.Tasks.Cache.BackfillCeph.run(["--project-id", p1.id])
      end)
    end
  end
end
