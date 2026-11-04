defmodule Gofer.RBAC.RolesCacheFreshTest do
  use ExUnit.Case, async: false

  alias Support.Stubs.RBAC, as: RBACStub
  alias Gofer.RBAC.RolesCache
  alias Gofer.RBAC.Subject

  @cache_name Application.compile_env!(:gofer, [RolesCache, :cache_name])

  setup_all _ctx do
    RBACStub.setup()
    :ok
  end

  setup do
    subject = %Subject{
      organization_id: UUID.uuid4(),
      project_id: UUID.uuid4(),
      triggerer: UUID.uuid4()
    }

    granted_role_id = UUID.uuid4()
    other_role_id = UUID.uuid4()
    RBACStub.set_role(role_tuple(subject, granted_role_id))

    {:ok, counter} = Agent.start_link(fn -> 0 end)

    GrpcMock.stub(RBACMock, :subjects_have_roles, fn req, stream ->
      Agent.update(counter, &(&1 + 1))
      RBACStub.Grpc.subjects_have_roles(req, stream)
    end)

    on_exit(fn -> RBACStub.Grpc.init(RBACMock) end)

    {:ok,
     subject: subject,
     granted_role_id: granted_role_id,
     other_role_id: other_role_id,
     role_ids: [granted_role_id, other_role_id],
     counter: counter}
  end

  defp role_tuple(subject, role_id),
    do: {subject.organization_id, subject.project_id, subject.triggerer, role_id}

  defp rbac_calls(ctx), do: Agent.get(ctx.counter, & &1)

  defp fresh_key(subject, role_ids) do
    {:fresh, "#{subject.organization_id}/#{subject.project_id}/#{subject.triggerer}",
     role_ids |> Enum.uniq() |> Enum.sort()}
  end

  defp wait_for_role_change, do: Process.sleep(50)

  describe "check_roles_fresh/2 with cache running" do
    setup do
      start_supervised!(RolesCache)
      :ok
    end

    test "returns RBAC assignments for granted and absent roles", ctx do
      assert {:ok, assignments} = RolesCache.check_roles_fresh(ctx.subject, ctx.role_ids)
      assert assignments[ctx.granted_role_id] == true
      assert assignments[ctx.other_role_id] == false
      assert rbac_calls(ctx) == 1
    end

    test "returns empty map for empty role ids without calling RBAC", ctx do
      assert {:ok, %{}} = RolesCache.check_roles_fresh(ctx.subject, [])
      assert rbac_calls(ctx) == 0
    end

    test "reuses a fresh result instead of calling RBAC again", ctx do
      assert {:ok, first} = RolesCache.check_roles_fresh(ctx.subject, ctx.role_ids)
      assert {:ok, ^first} = RolesCache.check_roles_fresh(ctx.subject, Enum.reverse(ctx.role_ids))
      assert rbac_calls(ctx) == 1
    end

    test "entries expire within seconds", ctx do
      assert {:ok, _} = RolesCache.check_roles_fresh(ctx.subject, ctx.role_ids)
      assert {:ok, ttl} = Cachex.ttl(@cache_name, fresh_key(ctx.subject, ctx.role_ids))
      assert ttl <= 5_000
    end

    test "does not share results between different subjects", ctx do
      other_user = %Subject{ctx.subject | triggerer: UUID.uuid4()}

      assert {:ok, %{} = granted} = RolesCache.check_roles_fresh(ctx.subject, ctx.role_ids)
      assert granted[ctx.granted_role_id] == true

      assert {:ok, %{} = denied} = RolesCache.check_roles_fresh(other_user, ctx.role_ids)
      assert denied[ctx.granted_role_id] == false
      assert rbac_calls(ctx) == 2
    end

    test "a revoked role is honored once the cached result is stale", ctx do
      assert {:ok, %{} = before} = RolesCache.check_roles_fresh(ctx.subject, ctx.role_ids)
      assert before[ctx.granted_role_id] == true

      RBACStub.remove_role(role_tuple(ctx.subject, ctx.granted_role_id))
      wait_for_role_change()
      age_entry(ctx)

      assert {:ok, %{} = later} = RolesCache.check_roles_fresh(ctx.subject, ctx.role_ids)
      assert later[ctx.granted_role_id] == false
      assert rbac_calls(ctx) == 2
    end

    test "a newly granted role is honored once the cached result is stale", ctx do
      assert {:ok, %{} = before} = RolesCache.check_roles_fresh(ctx.subject, ctx.role_ids)
      assert before[ctx.other_role_id] == false

      RBACStub.set_role(role_tuple(ctx.subject, ctx.other_role_id))
      wait_for_role_change()
      age_entry(ctx)

      assert {:ok, %{} = later} = RolesCache.check_roles_fresh(ctx.subject, ctx.role_ids)
      assert later[ctx.other_role_id] == true
    end

    test "concurrent identical lookups share one RBAC call", ctx do
      GrpcMock.stub(RBACMock, :subjects_have_roles, fn req, stream ->
        Agent.update(ctx.counter, &(&1 + 1))
        Process.sleep(300)
        RBACStub.Grpc.subjects_have_roles(req, stream)
      end)

      results =
        1..10
        |> Enum.map(fn _ ->
          Task.async(fn -> RolesCache.check_roles_fresh(ctx.subject, ctx.role_ids) end)
        end)
        |> Enum.map(&Task.await(&1, 5_000))

      assert Enum.all?(results, &match?({:ok, %{}}, &1))
      assert Enum.all?(results, fn {:ok, a} -> a[ctx.granted_role_id] == true end)
      assert rbac_calls(ctx) == 1
    end

    @tag capture_log: true
    test "errors are returned and not cached", ctx do
      RBACStub.Helpers.set_timeout()

      assert {:error, {:timeout, 1_000}} = RolesCache.check_roles_fresh(ctx.subject, ctx.role_ids)

      assert {:ok, nil} = Cachex.get(@cache_name, fresh_key(ctx.subject, ctx.role_ids))

      RBACStub.Grpc.init(RBACMock)
      assert {:ok, %{} = assignments} = RolesCache.check_roles_fresh(ctx.subject, ctx.role_ids)
      assert assignments[ctx.granted_role_id] == true
    end

    test "does not touch the long-lived subject entry used by check_roles/2", ctx do
      assert {:ok, _} = RolesCache.check_roles_fresh(ctx.subject, ctx.role_ids)

      subject_key =
        "#{ctx.subject.organization_id}/#{ctx.subject.project_id}/#{ctx.subject.triggerer}"

      assert {:ok, nil} = Cachex.get(@cache_name, subject_key)
    end
  end

  describe "check_roles_fresh/2 without the cache running" do
    test "calls RBAC on every lookup", ctx do
      assert {:ok, %{} = first} = RolesCache.check_roles_fresh(ctx.subject, ctx.role_ids)
      assert first[ctx.granted_role_id] == true
      assert {:ok, ^first} = RolesCache.check_roles_fresh(ctx.subject, ctx.role_ids)
      assert rbac_calls(ctx) == 2
    end
  end

  defp age_entry(ctx) do
    key = fresh_key(ctx.subject, ctx.role_ids)
    {:ok, {fetched_at, assignments}} = Cachex.get(@cache_name, key)
    Cachex.put(@cache_name, key, {fetched_at - 10_000, assignments})
  end
end
