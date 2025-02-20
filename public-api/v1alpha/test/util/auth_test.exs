defmodule PipelinesAPI.Util.AuthTest do
  use ExUnit.Case, async: false

  setup do
    org1 = Support.Stubs.Organization.create(name: "RT1", org_username: "rt1")
    org2 = Support.Stubs.Organization.create(name: "RT2", org_username: "rt2")
    user = Support.Stubs.User.create_default()
    project = Support.Stubs.Project.create(org1, user)

    Cachex.clear(:project_api_cache)

    {:ok, %{org1: org1, org2: org2, user: user, project: project}}
  end

  describe "project_belongs_to_org/2" do
    test "when org_id is nil then return unauthorized" do
      assert {:error, {:user, :unauthorized}} ==
               PipelinesAPI.Util.Auth.project_belongs_to_org(nil, "project_id")
    end

    test "when project_id is nil then return unauthorized" do
      assert {:error, {:user, :unauthorized}} ==
               PipelinesAPI.Util.Auth.project_belongs_to_org("org_id", nil)
    end

    test "when org_id is empty then return unauthorized" do
      assert {:error, {:user, :unauthorized}} ==
               PipelinesAPI.Util.Auth.project_belongs_to_org("", "project_id")
    end

    test "when project_id is empty then return unauthorized" do
      assert {:error, {:user, :unauthorized}} ==
               PipelinesAPI.Util.Auth.project_belongs_to_org("org_id", "")
    end

    test "when project belongs to org then return ok", ctx do
      assert :ok == PipelinesAPI.Util.Auth.project_belongs_to_org(ctx.org1.id, ctx.project.id)
    end

    test "when project does not belong to org then return unauthorized", ctx do
      assert {:error, {:user, :unauthorized}} ==
               PipelinesAPI.Util.Auth.project_belongs_to_org(ctx.org2.id, ctx.project.id)
    end

    test "uses cache to retrieve information", ctx do
      Cachex.put(:project_api_cache, ctx.project.id, {:error, :not_found})

      assert {:error, {:user, :unauthorized}} ==
               PipelinesAPI.Util.Auth.project_belongs_to_org(ctx.org1.id, ctx.project.id)
    end

    test "saves caches after retrieving information from project API", ctx do
      assert :ok == PipelinesAPI.Util.Auth.project_belongs_to_org(ctx.org1.id, ctx.project.id)

      assert {:ok, {:ok, %{metadata: %{org_id: org_id}}}} =
               Cachex.get(:project_api_cache, ctx.project.id)

      assert org_id == ctx.org1.id
    end
  end
end
