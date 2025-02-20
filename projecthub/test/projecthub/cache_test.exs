defmodule Projecthub.CacheTest do
  use Projecthub.DataCase
  alias Projecthub.Cache
  alias Projecthub.Models.Project

  describe ".create_for_project" do
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
  end
end
