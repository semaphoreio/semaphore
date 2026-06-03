# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
defmodule Zebra.Workers.JobRequestFactory.CacheTest do
  use Zebra.DataCase

  alias Zebra.Workers.JobRequestFactory.Cache

  @org_id Ecto.UUID.generate()
  @cache_id Ecto.UUID.generate()

  @sftp_cache InternalApi.Cache.Cache.new(
                id: @cache_id,
                credential: "--BEGIN....lalalala...cache_key...END---",
                url: "localhost:29920"
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
    GrpcMock.stub(Support.FakeServers.SecretsApi, :generate_cache_open_id_connect_token, fn req,
                                                                                            _ ->
      send(test_pid, {:cache_token_req, req})

      InternalApi.Secrethub.GenerateCacheOpenIDConnectTokenResponse.new(
        token: token,
        expires_at: 123
      )
    end)
  end

  describe ".env_vars (sftp)" do
    test "injects the sftp cache env contract" do
      {:ok, job} = Support.Factories.Job.create(:pending, %{})
      {:ok, envs} = Cache.env_vars(job, @sftp_cache, @org_id, nil, :pipeline_job)

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
      {:ok, envs} = Cache.env_vars(job, @ceph_cache, @org_id, @non_forked, :pipeline_job)

      assert env_value(envs, "SEMAPHORE_CACHE_BACKEND") == "ceph"
      assert env_value(envs, "SEMAPHORE_CACHE_S3_BUCKET") == "9c2a7b10-project-bucket"
      assert env_value(envs, "SEMAPHORE_CACHE_S3_URL") == "https://ceph-cache.example.test"
      assert env_value(envs, "SEMAPHORE_CACHE_ROLE_ARN") == "arn:aws:iam::acc:role/rw-role"
      assert env_value(envs, "SEMAPHORE_CACHE_OIDC_TOKEN") == "the-cache-token"
      # No temporary AWS credentials are injected (cache-cli exchanges the token).
      assert env_value(envs, "AWS_ACCESS_KEY_ID") == nil

      assert_receive {:cache_token_req, req}
      assert req.cache_access == "read_write"
      assert req.project_id == job.project_id
      assert req.job_id == job.id
      assert req.organization_id == @org_id
    end

    test "forked PR job gets the read-only role and read_only access claim" do
      test_pid = self()
      stub_cache_token("the-cache-token", test_pid)

      {:ok, job} = Support.Factories.Job.create(:pending, %{})
      {:ok, envs} = Cache.env_vars(job, @ceph_cache, @org_id, @forked_pr, :pipeline_job)

      assert env_value(envs, "SEMAPHORE_CACHE_ROLE_ARN") == "arn:aws:iam::acc:role/ro-role"

      assert_receive {:cache_token_req, req}
      assert req.cache_access == "read_only"
    end

    test "falls back to no cache when Secrethub fails" do
      GrpcMock.stub(Support.FakeServers.SecretsApi, :generate_cache_open_id_connect_token, fn _,
                                                                                              _ ->
        raise GRPC.RPCError, status: :internal, message: "boom"
      end)

      {:ok, job} = Support.Factories.Job.create(:pending, %{})
      assert {:ok, []} = Cache.env_vars(job, @ceph_cache, @org_id, @non_forked, :pipeline_job)
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
