# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
defmodule Zebra.Workers.JobRequestFactory.CacheTest do
  use Zebra.DataCase

  import ExUnit.CaptureLog

  alias Zebra.Workers.JobRequestFactory.Cache

  @org_id Ecto.UUID.generate()
  @cache_id Ecto.UUID.generate()
  @cache_credential "--BEGIN....lalalala...cache_key...END---"
  @cache_url "localhost:29920"

  @org InternalApi.Organization.Organization.new(org_id: @org_id, org_username: "test-org")

  @sftp_cache InternalApi.Cache.Cache.new(
                id: @cache_id,
                credential: @cache_credential,
                url: @cache_url
              )

  @ceph_cache InternalApi.Cache.Cache.new(
                id: @cache_id,
                bucket: "9c2a7b10-project-bucket",
                ro_role_arn: "arn:aws:iam::acc:role/ro-role",
                rw_role_arn: "arn:aws:iam::acc:role/rw-role",
                state: InternalApi.Cache.CacheState.value(:READY),
                backend: InternalApi.Cache.Backend.value(:CEPH)
              )

  @forked_pr %{pr_slug: "fork/repo", repo_slug: "base/repo"}
  @non_forked %{pr_slug: "", repo_slug: "base/repo"}

  defp env_value(envs, name) do
    case Enum.find(envs, fn e -> e["name"] == name end) do
      nil -> nil
      var -> Base.decode64!(var["value"])
    end
  end

  defp stub_cache_token(token, test_pid) do
    GrpcMock.stub(Support.FakeServers.SecretsApi, :generate_open_id_connect_token, fn req, _ ->
      send(test_pid, {:cache_token_req, req})

      InternalApi.Secrethub.GenerateOpenIDConnectTokenResponse.new(token: token)
    end)
  end

  defp stub_describe(fun) do
    GrpcMock.stub(Support.FakeServers.CacheApi, :describe, fun)
  end

  describe ".find" do
    test "with nil cache_id returns {:ok, nil} without contacting cachehub" do
      assert {:ok, nil} = Cache.find(nil, nil, @org_id)
    end

    test "logs warning and returns {:ok, nil} when cachehub returns non-OK status" do
      stub_describe(fn _, _ ->
        InternalApi.Cache.DescribeResponse.new(
          status:
            InternalApi.ResponseStatus.new(
              code: InternalApi.ResponseStatus.Code.value(:BAD_PARAM)
            )
        )
      end)

      log =
        capture_log(fn ->
          assert {:ok, nil} = Cache.find(@cache_id, nil, @org_id)
        end)

      assert log =~ "non-OK status"
      assert log =~ @cache_id
    end

    test "logs warning and returns {:ok, nil} when an sftp cache has a blank credential" do
      stub_describe(fn _, _ ->
        InternalApi.Cache.DescribeResponse.new(
          status:
            InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
          cache: InternalApi.Cache.Cache.new(id: @cache_id, credential: " ", url: @cache_url)
        )
      end)

      log =
        capture_log(fn ->
          assert {:ok, nil} = Cache.find(@cache_id, nil, @org_id)
        end)

      assert log =~ "blank credential"
      assert log =~ @cache_id
      refute log =~ @cache_url
    end

    test "treats an empty-string sftp credential as blank => returns {:ok, nil}" do
      stub_describe(fn _, _ ->
        InternalApi.Cache.DescribeResponse.new(
          status:
            InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
          cache: InternalApi.Cache.Cache.new(id: @cache_id, credential: "", url: @cache_url)
        )
      end)

      log =
        capture_log(fn ->
          assert {:ok, nil} = Cache.find(@cache_id, nil, @org_id)
        end)

      assert log =~ "blank credential"
    end

    #
    # Regression test for the "accept-main" bug: a CEPH cache legitimately carries
    # a blank credential. Routing an OK describe through main's blank-credential
    # arm would silently disable every ceph cache. find/3 must return the ceph
    # cache (via normalize_described_cache) and must NOT log a blank-credential
    # warning.
    #
    test "a READY ceph cache with a blank credential is NOT disabled" do
      stub_describe(fn _, _ ->
        InternalApi.Cache.DescribeResponse.new(
          status:
            InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
          cache:
            InternalApi.Cache.Cache.new(
              id: @cache_id,
              credential: "",
              bucket: "9c2a7b10-project-bucket",
              ro_role_arn: "arn:aws:iam::acc:role/ro-role",
              rw_role_arn: "arn:aws:iam::acc:role/rw-role",
              state: InternalApi.Cache.CacheState.value(:READY),
              backend: InternalApi.Cache.Backend.value(:CEPH)
            )
        )
      end)

      log =
        capture_log(fn ->
          assert {:ok, cache} = Cache.find(@cache_id, nil, @org_id)
          assert cache.backend == InternalApi.Cache.Backend.value(:CEPH)
          assert cache.bucket == "9c2a7b10-project-bucket"
          assert cache.ro_role_arn == "arn:aws:iam::acc:role/ro-role"
          assert cache.rw_role_arn == "arn:aws:iam::acc:role/rw-role"
        end)

      refute log =~ "blank credential"
    end

    test "logs warning and returns {:ok, nil} when cachehub raises" do
      stub_describe(fn _, _ ->
        raise "boom"
      end)

      log =
        capture_log(fn ->
          assert {:ok, nil} = Cache.find(@cache_id, nil, @org_id)
        end)

      assert log =~ "Failed to fetch info from cachehub"
      assert log =~ @cache_id
      refute log =~ @cache_credential
    end
  end

  describe ".forked_pr?" do
    test "true when PR slug org differs from repo slug org" do
      repo =
        InternalApi.RepoProxy.Hook.new(
          repo_slug: "test-org/test-repo",
          pr_slug: "fork-org/test-repo"
        )

      assert Cache.forked_pr?(repo)
    end

    test "false when PR slug org matches repo slug org" do
      repo =
        InternalApi.RepoProxy.Hook.new(
          repo_slug: "test-org/test-repo",
          pr_slug: "test-org/test-repo"
        )

      refute Cache.forked_pr?(repo)
    end

    test "false when there is no PR slug (not a PR build)" do
      repo = InternalApi.RepoProxy.Hook.new(repo_slug: "test-org/test-repo", pr_slug: "")
      refute Cache.forked_pr?(repo)
    end

    test "false when repo proxy is nil" do
      refute Cache.forked_pr?(nil)
    end
  end

  describe ".env_vars (sftp)" do
    test "injects the sftp cache env contract" do
      {:ok, job} = Support.Factories.Job.create(:pending, %{})
      {:ok, envs} = Cache.env_vars(job, @sftp_cache, @org, nil, :pipeline_job)

      assert env_value(envs, "SEMAPHORE_CACHE_BACKEND") == "sftp"
      assert env_value(envs, "SEMAPHORE_CACHE_URL") == "localhost:29920"
      assert env_value(envs, "SEMAPHORE_CACHE_USERNAME") == String.replace(@cache_id, "-", "")
      # No Ceph vars on the sftp path.
      assert env_value(envs, "SEMAPHORE_CACHE_OIDC_TOKEN") == nil
    end
  end

  describe ".env_vars (ceph)" do
    test "non-forked job gets read-write role and the ceph env contract" do
      test_pid = self()
      stub_cache_token("the-cache-token", test_pid)

      {:ok, job} = Support.Factories.Job.create(:pending, %{})
      {:ok, envs} = Cache.env_vars(job, @ceph_cache, @org, @non_forked, :pipeline_job)

      assert env_value(envs, "SEMAPHORE_CACHE_BACKEND") == "ceph"
      assert env_value(envs, "SEMAPHORE_CACHE_S3_BUCKET") == "9c2a7b10-project-bucket"
      assert env_value(envs, "SEMAPHORE_CACHE_S3_URL") == "https://ceph-cache.example.test"
      assert env_value(envs, "SEMAPHORE_CACHE_ROLE_ARN") == "arn:aws:iam::acc:role/rw-role"
      assert env_value(envs, "SEMAPHORE_CACHE_OIDC_TOKEN") == "the-cache-token"
      # No temporary AWS credentials are injected (cache-cli exchanges the token).
      assert env_value(envs, "AWS_ACCESS_KEY_ID") == nil

      assert_receive {:cache_token_req, req}
      assert req.subject == "org:#{@org_id}:project:#{job.project_id}:access:read_write"
      assert req.audience == ["ceph-cache"]
      assert req.project_id == job.project_id
      assert req.job_id == job.id
      assert req.org_id == @org_id
      assert req.org_username == "test-org"
    end

    test "forked PR job gets the read-only role and read_only access claim" do
      test_pid = self()
      stub_cache_token("the-cache-token", test_pid)

      {:ok, job} = Support.Factories.Job.create(:pending, %{})
      {:ok, envs} = Cache.env_vars(job, @ceph_cache, @org, @forked_pr, :pipeline_job)

      assert env_value(envs, "SEMAPHORE_CACHE_ROLE_ARN") == "arn:aws:iam::acc:role/ro-role"

      assert_receive {:cache_token_req, req}
      assert req.subject == "org:#{@org_id}:project:#{job.project_id}:access:read_only"
    end

    test "falls back to no cache when Secrethub fails" do
      GrpcMock.stub(Support.FakeServers.SecretsApi, :generate_open_id_connect_token, fn _, _ ->
        raise GRPC.RPCError, status: :internal, message: "boom"
      end)

      {:ok, job} = Support.Factories.Job.create(:pending, %{})
      assert {:ok, []} = Cache.env_vars(job, @ceph_cache, @org, @non_forked, :pipeline_job)
    end
  end

  describe ".files" do
    test "ceph backend injects no key file" do
      {:ok, job} = Support.Factories.Job.create(:pending, %{})
      assert {:ok, []} = Cache.files(job, @ceph_cache)
    end

    test "sftp backend injects the cache key file" do
      {:ok, job} = Support.Factories.Job.create(:pending, %{})
      assert {:ok, [file]} = Cache.files(job, @sftp_cache)
      assert file["path"] =~ "semaphore_cache_key"
    end
  end
end
