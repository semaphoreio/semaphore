defmodule Badges.ApiTest do
  use ExUnit.Case, async: true
  use Plug.Test

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

  @opts Badges.Api.init([])
  @org_id "a927b83f-051d-4d2b-ae93-91fc92862a2b"
  @project_id "a927b83f-051d-4d2b-ae93-91fc92862a21"

  describe "/is_alive" do
    test "returns 200 OK" do
      conn = conn(:get, "/is_alive")
      conn = Badges.Api.call(conn, @opts)

      assert conn.state == :sent
      assert conn.status == 200
      assert conn.resp_body == "OK"
    end
  end

  describe "match _" do
    test "unsupported url => returns 404" do
      conn = conn(:get, "/badges/foo/bar/baz.svg")
      conn = conn |> put_req_header("x-semaphore-org-id", @org_id)
      conn = Badges.Api.call(conn, @opts)

      assert conn.status == 404
      assert conn.resp_body == "Badge not found"
    end

    test "unsupported method => returns 404" do
      conn = conn(:post, "/badges/foo/badges/baz.svg")
      conn = conn |> put_req_header("x-semaphore-org-id", @org_id)
      conn = Badges.Api.call(conn, @opts)

      assert conn.status == 404
      assert conn.resp_body == "Badge not found"
    end
  end

  describe "/badges/testproject.svg" do
    test "when branch is omitted => look for master" do
      GrpcMock.stub(PipelineMock, :list_keyset, fn _, _ ->
        InternalApi.Plumber.ListKeysetResponse.new(pipelines: [Support.Factories.pipeline()])
      end)

      conn = conn(:get, "/badges/testproject.svg")
      conn = conn |> put_req_header("x-semaphore-org-id", @org_id)
      conn = Badges.Api.call(conn, @opts)

      assert conn.status == 200
    end

    test "when extension is ommited => returns 404" do
      conn = conn(:get, "/badges/testproject")
      conn = conn |> put_req_header("x-semaphore-org-id", @org_id)
      conn = Badges.Api.call(conn, @opts)

      assert conn.status == 404
    end
  end

  describe "/badges/testproject/branches/rw/test.svg" do
    test "when extension is ommited => returns 404" do
      conn = conn(:get, "/badges/testproject/rw/test")
      conn = conn |> put_req_header("x-semaphore-org-id", @org_id)
      conn = Badges.Api.call(conn, @opts)

      assert conn.status == 404
    end

    test "when project doesn't exists => returns 404" do
      GrpcMock.stub(ProjectMock, :describe, fn req, _ ->
        assert req.name == "testproject"
        assert req.metadata.org_id == @org_id

        InternalApi.Projecthub.DescribeResponse.new(
          metadata: Support.Factories.response_meta(:NOT_FOUND)
        )
      end)

      conn = conn(:get, "/badges/testproject/branches/rw/test.svg")
      conn = conn |> put_req_header("x-semaphore-org-id", @org_id)
      conn = Badges.Api.call(conn, @opts)

      assert conn.status == 404

      assert conn.resp_body ==
               "Project not found - for private projects check: https://docs.semaphoreci.com/article/166-status-badges#private-projects-on-semaphore"
    end

    test "when branch doesn't exists => returns unknown badge" do
      GrpcMock.stub(PipelineMock, :list_keyset, fn _, _ ->
        InternalApi.Plumber.ListKeysetResponse.new(pipelines: [])
      end)

      conn = conn(:get, "/badges/testproject/branches/rw/test.svg")
      conn = conn |> put_req_header("x-semaphore-org-id", @org_id)
      conn = Badges.Api.call(conn, @opts)

      assert conn.status == 200
      assert conn.resp_body =~ "unknown"
    end

    test "when branch exists => returns green badge" do
      conn = conn(:get, "/badges/testproject/branches/rw/test.svg")
      conn = conn |> put_req_header("x-semaphore-org-id", @org_id)
      conn = Badges.Api.call(conn, @opts)

      assert conn.status == 200
      assert conn.resp_body =~ "passed"
    end

    test "private project without key => returns 404" do
      GrpcMock.stub(ProjectMock, :describe, fn _, _ ->
        InternalApi.Projecthub.DescribeResponse.new(
          metadata: Support.Factories.response_meta(:OK),
          project: Support.Factories.project([], public: false)
        )
      end)

      conn = conn(:get, "/badges/testproject/branches/rw/test.svg")
      conn = conn |> put_req_header("x-semaphore-org-id", @org_id)
      conn = Badges.Api.call(conn, @opts)

      assert conn.status == 404

      assert conn.resp_body ==
               "Project not found - for private projects check: https://docs.semaphoreci.com/article/166-status-badges#private-projects-on-semaphore"
    end

    test "private project wih key => returns green badge" do
      GrpcMock.stub(ProjectMock, :describe, fn _, _ ->
        InternalApi.Projecthub.DescribeResponse.new(
          metadata: Support.Factories.response_meta(:OK),
          project: Support.Factories.project([id: @project_id], public: false)
        )
      end)

      conn = conn(:get, "/badges/testproject/branches/rw/test.svg?key=#{@project_id}")
      conn = conn |> put_req_header("x-semaphore-org-id", @org_id)
      conn = Badges.Api.call(conn, @opts)

      assert conn.status == 200
      assert conn.resp_body =~ "passed"
    end
  end
end
