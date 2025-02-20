defmodule Badges.BadgeTest do
  use ExUnit.Case

  @org_id "12345678-1234-5678-0000-010101010101"
  @project_id "12345678-1234-5678-0000-010101010101"

  alias Badges.Badge

  setup do
    Cachex.reset(:badges_cache)

    GrpcMock.stub(ProjectMock, :describe, fn _, _ ->
      InternalApi.Projecthub.DescribeResponse.new(
        metadata: Support.Factories.response_meta(:OK),
        project: Support.Factories.project([], public: true)
      )
    end)

    GrpcMock.stub(PipelineMock, :list_keyset, fn _, _ ->
      InternalApi.Plumber.ListKeysetResponse.new(pipelines: [Support.Factories.pipeline()])
    end)

    :ok
  end

  describe ".variant" do
    test "when project doesn't exists => returns error" do
      GrpcMock.stub(ProjectMock, :describe, fn _, _ ->
        InternalApi.Projecthub.DescribeResponse.new(
          metadata: Support.Factories.response_meta(:NOT_FOUND)
        )
      end)

      {:error, :project_not_found} = Badge.variant(@org_id, "testproject", "master", nil)
    end

    test "when branch doesn't exists => returns unknown badge" do
      GrpcMock.stub(PipelineMock, :list_keyset, fn _, _ ->
        InternalApi.Plumber.ListKeysetResponse.new(pipelines: [])
      end)

      {:ok, badge} = Badge.variant(@org_id, "testproject", "master", nil)

      assert badge == :unknown
    end

    test "when branch exists => returns green badge" do
      {:ok, badge} = Badge.variant(@org_id, "testproject", "master", nil)

      assert badge == :passed
    end

    test "when project is private and there is no key => returns error" do
      GrpcMock.stub(ProjectMock, :describe, fn _, _ ->
        InternalApi.Projecthub.DescribeResponse.new(
          metadata: Support.Factories.response_meta(:OK),
          project: Support.Factories.project([], public: false)
        )
      end)

      {:error, :project_not_found} = Badge.variant(@org_id, "testproject", "master", nil)
    end

    test "when project is private and key is invalid => returns error" do
      GrpcMock.stub(ProjectMock, :describe, fn _, _ ->
        InternalApi.Projecthub.DescribeResponse.new(
          metadata: Support.Factories.response_meta(:OK),
          project: Support.Factories.project([], public: false)
        )
      end)

      {:error, :project_not_found} = Badge.variant(@org_id, "testproject", "master", "foo")
    end

    test "when project is private and key is valid => returns badge" do
      GrpcMock.stub(ProjectMock, :describe, fn _, _ ->
        InternalApi.Projecthub.DescribeResponse.new(
          metadata: Support.Factories.response_meta(:OK),
          project: Support.Factories.project([id: @project_id], public: false)
        )
      end)

      {:ok, badge} = Badge.variant(@org_id, "testproject", "master", @project_id)

      assert badge == :passed
    end
  end
end
