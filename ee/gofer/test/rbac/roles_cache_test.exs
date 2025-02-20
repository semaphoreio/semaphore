defmodule Gofer.RBAC.RolesCacheTest do
  use ExUnit.Case, async: false

  alias Support.Stubs.RBAC, as: RBACStub
  alias Gofer.RBAC.RolesCache
  alias Gofer.RBAC.Subject

  @cache_name Application.compile_env!(:gofer, [RolesCache, :cache_name])
  @cache_ttl Application.compile_env!(:gofer, [RolesCache, :expiration_ttl])

  setup_all _ctx do
    RBACStub.setup()

    subject_params = [
      organization_id: UUID.uuid4(),
      project_id: UUID.uuid4(),
      triggerer: UUID.uuid4()
    ]

    cache_key = subject_params |> Enum.map(&elem(&1, 1)) |> Enum.join("/")
    role_ids = for _ <- 1..6, do: insert_role(subject_params, UUID.uuid4())

    {:ok, subject: struct(Subject, subject_params), cache_key: cache_key, role_ids: role_ids}
  end

  setup ctx do
    {present_role_ids, absent_role_ids} = Enum.split(ctx.role_ids, 3)

    present_assignments =
      Map.merge(
        Enum.into(present_role_ids, %{}, &{&1, true}),
        for(_ <- 1..3, into: %{}, do: {UUID.uuid4(), false})
      )

    absent_assignments =
      Map.merge(
        Enum.into(absent_role_ids, %{}, &{&1, true}),
        for(_ <- 1..3, into: %{}, do: {UUID.uuid4(), false})
      )

    mixed_assignments =
      Map.merge(
        present_assignments |> Enum.take(3) |> Map.new(),
        absent_assignments |> Enum.take(3) |> Map.new()
      )

    start_supervised!(Gofer.RBAC.RolesCache)
    Cachex.put(:rbac_roles, ctx.cache_key, present_assignments, ttl: 90_000)

    {:ok,
     present_role_ids: MapSet.new(present_assignments, &elem(&1, 0)),
     present_assignments: present_assignments,
     absent_role_ids: MapSet.new(absent_assignments, &elem(&1, 0)),
     absent_assignments: absent_assignments,
     mixed_role_ids: MapSet.new(mixed_assignments, &elem(&1, 0)),
     mixed_assignments: mixed_assignments}
  end

  defp insert_role(subject_params, role_id) do
    subject_params
    |> Keyword.values()
    |> List.to_tuple()
    |> Tuple.append(role_id)
    |> RBACStub.set_role()

    role_id
  end

  describe "check_roles/2" do
    @tag capture_log: true
    test "when RBAC is unavailable then returns error", ctx = %{subject: subject} do
      RBACStub.Helpers.set_timeout()

      assert {:error, {:timeout, 1_000}} = RolesCache.check_roles(subject, ctx.absent_role_ids)
      assert {:ok, nil} = Cachex.get(@cache_name, ctx.cache_key)
    end

    test "when role_ids are empty then returns empty map", %{subject: subject} do
      assert {:ok, %{}} = RolesCache.check_roles(subject, [])
    end
  end

  describe "check_roles/2 when none of roles has been cached" do
    test "then calls RBAC to fetch them", ctx = %{absent_assignments: absent_assignments} do
      on_exit(fn -> RBACStub.Grpc.init(RBACMock) end)
      GrpcMock.expect(RBACMock, :subjects_have_roles, &RBACStub.Grpc.subjects_have_roles/2)

      assert {:ok, ^absent_assignments} =
               RolesCache.check_roles(ctx.subject, Enum.to_list(ctx.absent_role_ids))

      GrpcMock.verify!(RBACMock)
    end

    test "then caches fetched roles", ctx = %{absent_assignments: absent_assignments} do
      assert {:ok, ^absent_assignments} =
               RolesCache.check_roles(ctx.subject, Enum.to_list(ctx.absent_role_ids))

      assert {:ok, cached_assignments} = Cachex.get(@cache_name, ctx.cache_key)
      cached_role_ids = MapSet.new(cached_assignments, &elem(&1, 0))

      assert MapSet.subset?(ctx.absent_role_ids, cached_role_ids)
      assert MapSet.subset?(ctx.present_role_ids, cached_role_ids)
    end

    test "then TTL is reset", ctx = %{absent_assignments: absent_assignments} do
      assert {:ok, ^absent_assignments} =
               RolesCache.check_roles(ctx.subject, Enum.to_list(ctx.absent_role_ids))

      assert {:ok, ttl} = Cachex.ttl(@cache_name, ctx.cache_key)
      assert_in_delta ttl, @cache_ttl * 1_000, 1_000
    end
  end

  describe "check_roles/2 when some of roles has been cached" do
    test "then calls RBAC to fetch them", ctx = %{mixed_assignments: mixed_assignments} do
      on_exit(fn -> RBACStub.Grpc.init(RBACMock) end)
      GrpcMock.expect(RBACMock, :subjects_have_roles, &RBACStub.Grpc.subjects_have_roles/2)

      assert {:ok, ^mixed_assignments} =
               RolesCache.check_roles(ctx.subject, Enum.to_list(ctx.mixed_role_ids))

      GrpcMock.verify!(RBACMock)
    end

    test "then caches fetched roles", ctx = %{mixed_assignments: mixed_assignments} do
      assert {:ok, ^mixed_assignments} =
               RolesCache.check_roles(ctx.subject, Enum.to_list(ctx.mixed_role_ids))

      assert {:ok, cached_assignments} = Cachex.get(@cache_name, ctx.cache_key)
      cached_role_ids = MapSet.new(cached_assignments, &elem(&1, 0))

      assert MapSet.subset?(ctx.mixed_role_ids, cached_role_ids)
      assert MapSet.subset?(ctx.present_role_ids, cached_role_ids)
    end

    test "then TTL is reset", ctx = %{mixed_assignments: mixed_assignments} do
      assert {:ok, ^mixed_assignments} =
               RolesCache.check_roles(ctx.subject, Enum.to_list(ctx.mixed_role_ids))

      assert {:ok, ttl} = Cachex.ttl(@cache_name, ctx.cache_key)
      assert_in_delta ttl, @cache_ttl * 1_000, 1_000
    end
  end

  describe "check_roles/2 when all roles has been cached" do
    test "then does not call RBAC ", ctx = %{present_assignments: present_assignments} do
      on_exit(fn -> RBACStub.Grpc.init(RBACMock) end)
      GrpcMock.expect(RBACMock, :subjects_have_roles, 0, &RBACStub.Grpc.subjects_have_roles/2)

      assert {:ok, ^present_assignments} =
               RolesCache.check_roles(ctx.subject, Enum.to_list(ctx.present_role_ids))

      GrpcMock.verify!(RBACMock)
    end

    test "then caches is untouched", ctx = %{present_assignments: present_assignments} do
      assert {:ok, ^present_assignments} =
               RolesCache.check_roles(ctx.subject, Enum.to_list(ctx.present_role_ids))

      assert {:ok, cached_assignments} = Cachex.get(@cache_name, ctx.cache_key)
      cached_role_ids = MapSet.new(cached_assignments, &elem(&1, 0))

      assert MapSet.subset?(ctx.present_role_ids, cached_role_ids)
      assert MapSet.disjoint?(ctx.absent_role_ids, cached_role_ids)
    end

    test "then TTL is kept", ctx = %{present_assignments: present_assignments} do
      assert {:ok, ^present_assignments} =
               RolesCache.check_roles(ctx.subject, Enum.to_list(ctx.present_role_ids))

      assert {:ok, ttl} = Cachex.ttl(@cache_name, ctx.cache_key)
      assert_in_delta ttl, 90_000, 1_000
    end
  end
end
