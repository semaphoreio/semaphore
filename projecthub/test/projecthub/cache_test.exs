defmodule Projecthub.CacheTest do
  use Projecthub.DataCase
  alias Projecthub.Cache
  alias Projecthub.Models.Project

  describe ".create_for_project" do
    setup do
      FunRegistry.set!(Support.FakeServices.FeatureService, :list_organization_features, fn _req, _ ->
        InternalApi.Feature.ListOrganizationFeaturesResponse.new(organization_features: [])
      end)
    end

    test "when the response is on => updates project" do
      {:ok, project} = Support.Factories.Project.create()
      refute project.cache_id

      cache_id = Ecto.UUID.generate()

      response =
        InternalApi.Cache.CreateResponse.new(
          status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
          cache_id: cache_id
        )

      FunRegistry.set!(Support.FakeServices.CacheService, :create, response)

      Cache.create_for_project(project.id)

      reloaded_project = Project |> Repo.get(project.id)

      assert reloaded_project.cache_id == cache_id
    end

    test "when the response is not okay => doesn't update project" do
      {:ok, project} = Support.Factories.Project.create()

      response =
        InternalApi.Cache.CreateResponse.new(
          status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:BAD_PARAM))
        )

      FunRegistry.set!(Support.FakeServices.CacheService, :create, response)

      Cache.create_for_project(project.id)

      reloaded_project = Project |> Repo.get(project.id)

      assert reloaded_project.cache_id == project.cache_id
    end

    test "sends SFTP backend when use_ceph_for_cache flag is disabled" do
      {:ok, project} = Support.Factories.Project.create()
      test_pid = self()

      response =
        InternalApi.Cache.CreateResponse.new(
          status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
          cache_id: Ecto.UUID.generate()
        )

      FunRegistry.set!(Support.FakeServices.CacheService, :create, fn req, _stream ->
        send(test_pid, {:cache_create_request, req})
        response
      end)

      Cache.create_for_project(project.id)

      assert_receive {:cache_create_request, req}
      assert req.organization_id == project.organization_id
      assert req.project_id == project.id
      assert req.project_name == project.name
      assert req.backend == :SFTP
    end

    test "sends CEPH backend when use_ceph_for_cache flag is enabled" do
      {:ok, project} = Support.Factories.Project.create()
      test_pid = self()
      availability = InternalApi.Feature.Availability.new(state: :ENABLED, quantity: 1)

      FunRegistry.set!(Support.FakeServices.FeatureService, :list_organization_features, fn _req, _ ->
        InternalApi.Feature.ListOrganizationFeaturesResponse.new(
          organization_features: [
            [feature: %{type: "use_ceph_for_cache"}, availability: availability]
          ]
        )
      end)

      response =
        InternalApi.Cache.CreateResponse.new(
          status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
          cache_id: Ecto.UUID.generate()
        )

      FunRegistry.set!(Support.FakeServices.CacheService, :create, fn req, _stream ->
        send(test_pid, {:cache_create_request, req})
        response
      end)

      Cache.create_for_project(project.id)

      assert_receive {:cache_create_request, req}
      assert req.backend == :CEPH
    end
  end
end
