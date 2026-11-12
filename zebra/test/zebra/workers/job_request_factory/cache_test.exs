# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
defmodule Zebra.Workers.JobRequestFactory.CacheTest do
  use Zebra.DataCase

  import ExUnit.CaptureLog

  alias Zebra.Workers.JobRequestFactory.Cache
  alias InternalApi.ResponseStatus

  @org_id Ecto.UUID.generate()
  @cache_id Ecto.UUID.generate()
  @cache_credential "--BEGIN....lalalala...cache_key...END---"
  @cache_url "localhost:29920"
  @cache InternalApi.Cache.Cache.new(
           id: @cache_id,
           credential: @cache_credential,
           url: @cache_url
         )

  @s3_secret "s3-secret-access-key"
  @s3_session_token "s3-session-token"

  describe ".find" do
    test "with nil cache_id returns {:ok, nil} without contacting cachehub" do
      assert {:ok, nil} = Cache.find(nil, nil, @org_id)
    end

    test "logs warning and returns {:ok, nil} when cachehub returns non-OK status" do
      GrpcMock.stub(Support.FakeServers.CacheApi, :describe, fn _, _ ->
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

    test "logs warning and returns {:ok, nil} when cachehub returns blank credential" do
      GrpcMock.stub(Support.FakeServers.CacheApi, :describe, fn _, _ ->
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

    test "treats an empty-string credential as blank => returns {:ok, nil}" do
      GrpcMock.stub(Support.FakeServers.CacheApi, :describe, fn _, _ ->
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

    test "logs warning and returns {:ok, nil} when cachehub raises" do
      GrpcMock.stub(Support.FakeServers.CacheApi, :describe, fn _, _ ->
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

    test "approved enable-cache lifts the forked PR status only while the project allows it" do
      enable_feature("sem_approve_options")

      repo =
        InternalApi.RepoProxy.Hook.new(
          repo_slug: "test-org/test-repo",
          pr_slug: "fork-org/test-repo",
          approval_enable_cache: true
        )

      refute Cache.forked_pr?(repo, @org_id, project_allowing_cache(true))
      assert Cache.forked_pr?(repo, @org_id, project_allowing_cache(false))
      assert Cache.forked_pr?(repo, @org_id)
    end
  end

  describe ".env_vars" do
    test "cache_cli_parallel_archive_method is enabled => uses parallel archive method" do
      #
      # stubbed feature provider has feature disabled,
      # so we need to enable it here.
      #
      Mox.stub(Support.MockedProvider, :provide_features, fn _, _ ->
        features =
          Support.StubbedProvider.provide_features()
          |> case do
            {:ok, features} -> features
            {:error, _} -> []
          end
          |> Enum.map(fn
            %FeatureProvider.Feature{type: "cache_cli_parallel_archive_method"} = feature ->
              %{feature | quantity: 1, state: :enabled}

            feature ->
              feature
          end)

        {:ok, features}
      end)

      {:ok, job} = Support.Factories.Job.create(:pending, %{})
      {:ok, envs} = Cache.env_vars(job, @cache, @org_id)
      expected_envs = expected_envs(true)
      assert envs == expected_envs
    end

    test "cache_cli_parallel_archive_method is disabled => does not use parallel archive method" do
      {:ok, job} = Support.Factories.Job.create(:pending, %{})
      {:ok, envs} = Cache.env_vars(job, @cache, @org_id)
      expected_envs = expected_envs(false)
      assert envs == expected_envs
    end
  end

  describe ".find with forked PR approval options" do
    test "forked PR with disable_forked_pr_cache enabled skips cache loading" do
      enable_feature("disable_forked_pr_cache")

      GrpcMock.stub(Support.FakeServers.CacheApi, :describe, fn _, _ ->
        raise "cache should not be queried for forked pull requests"
      end)

      repo = %{pr_slug: "contributor/repo", repo_slug: "org/repo"}

      assert Cache.find(@cache_id, repo, @org_id) == {:ok, nil}
    end

    test "approval enable-cache bypasses forked PR cache restriction" do
      enable_features(["disable_forked_pr_cache", "sem_approve_options"])

      GrpcMock.stub(Support.FakeServers.CacheApi, :describe, fn req, _ ->
        InternalApi.Cache.DescribeResponse.new(
          status: ResponseStatus.new(code: ResponseStatus.Code.value(:OK)),
          cache:
            InternalApi.Cache.Cache.new(
              id: req.cache_id,
              credential: "--BEGIN....lalalala...cache_key...END---",
              url: "localhost:29920"
            )
        )
      end)

      repo = %{pr_slug: "contributor/repo", repo_slug: "org/repo", approval_enable_cache: true}

      assert {:ok, cache} =
               Cache.find(@cache_id, repo, @org_id, :pipeline_job, project_allowing_cache(true))

      assert cache.id == @cache_id
    end

    test "approval enable-cache is ignored once the project setting is turned off" do
      enable_features(["disable_forked_pr_cache", "sem_approve_options"])

      GrpcMock.stub(Support.FakeServers.CacheApi, :describe, fn _, _ ->
        raise "cache should not be queried when the project disallows --enable-cache"
      end)

      repo = %{pr_slug: "contributor/repo", repo_slug: "org/repo", approval_enable_cache: true}

      assert Cache.find(@cache_id, repo, @org_id, :pipeline_job, project_allowing_cache(false)) ==
               {:ok, nil}

      assert Cache.find(@cache_id, repo, @org_id, :pipeline_job, nil) == {:ok, nil}
    end

    test "approval enable-cache is ignored when sem_approve_options feature is disabled" do
      enable_feature("disable_forked_pr_cache")

      GrpcMock.stub(Support.FakeServers.CacheApi, :describe, fn _, _ ->
        raise "cache should not be queried when sem_approve_options is disabled"
      end)

      repo = %{pr_slug: "contributor/repo", repo_slug: "org/repo", approval_enable_cache: true}

      assert Cache.find(@cache_id, repo, @org_id, :pipeline_job, project_allowing_cache(true)) ==
               {:ok, nil}
    end

    test "debug job on forked PR skips cache even when approval enable-cache is set" do
      enable_features(["disable_forked_pr_cache", "sem_approve_options"])

      GrpcMock.stub(Support.FakeServers.CacheApi, :describe, fn _, _ ->
        raise "cache should not be queried for debug jobs on forked pull requests"
      end)

      repo = %{pr_slug: "contributor/repo", repo_slug: "org/repo", approval_enable_cache: true}

      assert Cache.find(@cache_id, repo, @org_id, :debug_job, project_allowing_cache(true)) ==
               {:ok, nil}
    end

    test "debug job on forked PR uses cache when disable_forked_pr_cache is disabled" do
      GrpcMock.stub(Support.FakeServers.CacheApi, :describe, fn req, _ ->
        InternalApi.Cache.DescribeResponse.new(
          status: ResponseStatus.new(code: ResponseStatus.Code.value(:OK)),
          cache:
            InternalApi.Cache.Cache.new(
              id: req.cache_id,
              credential: "--BEGIN....lalalala...cache_key...END---",
              url: "localhost:29920"
            )
        )
      end)

      repo = %{pr_slug: "contributor/repo", repo_slug: "org/repo", approval_enable_cache: true}

      assert {:ok, cache} = Cache.find(@cache_id, repo, @org_id, :debug_job)
      assert cache.id == @cache_id
    end
  end

  describe ".find_s3" do
    setup do
      {:ok, job} = Support.Factories.Job.create(:pending, %{})
      %{job: job}
    end

    test "asks cachehub for credentials on the job's project with the given validity", %{
      job: job
    } do
      test_pid = self()

      GrpcMock.stub(Support.FakeServers.CacheApi, :get_s3_credentials, fn req, _ ->
        send(test_pid, {:get_s3_credentials, req})
        s3_credentials()
      end)

      assert {:ok, credentials} = Cache.find_s3(job, project(), nil, :pipeline_job, 7_200)
      assert credentials == s3_credentials()

      assert_received {:get_s3_credentials, req}
      assert req.project_id == job.project_id
      assert req.min_validity_seconds == 7_200
    end

    test "skips a project without a cache_id without asking cachehub", %{job: job} do
      stub_s3_credentials_not_called()

      assert {:ok, nil} =
               Cache.find_s3(job, %{project() | cache_id: nil}, nil, :pipeline_job, 7_200)

      refute_received :get_s3_credentials_called
    end

    test "logs a warning and returns {:ok, nil} on a non-OK status", %{job: job} do
      GrpcMock.stub(Support.FakeServers.CacheApi, :get_s3_credentials, fn _, _ ->
        %{
          s3_credentials()
          | status: ResponseStatus.new(code: ResponseStatus.Code.value(:BAD_PARAM))
        }
      end)

      log =
        capture_log(fn ->
          assert {:ok, nil} = Cache.find_s3(job, project(), nil, :pipeline_job, 7_200)
        end)

      assert log =~ "non-OK status for S3 credentials"
      assert log =~ job.project_id
      refute log =~ @s3_secret
      refute log =~ @s3_session_token
    end

    test "logs a warning and returns {:ok, nil} when a credential is blank", %{job: job} do
      GrpcMock.stub(Support.FakeServers.CacheApi, :get_s3_credentials, fn _, _ ->
        %{s3_credentials() | session_token: " "}
      end)

      log =
        capture_log(fn ->
          assert {:ok, nil} = Cache.find_s3(job, project(), nil, :pipeline_job, 7_200)
        end)

      assert log =~ "incomplete S3 credentials"
      refute log =~ @s3_secret
    end

    test "logs a warning and returns {:ok, nil} when cachehub raises", %{job: job} do
      GrpcMock.stub(Support.FakeServers.CacheApi, :get_s3_credentials, fn _, _ ->
        raise "boom"
      end)

      log =
        capture_log(fn ->
          assert {:ok, nil} = Cache.find_s3(job, project(), nil, :pipeline_job, 7_200)
        end)

      assert log =~ "Failed to fetch S3 credentials from cachehub"
      assert log =~ job.project_id
    end

    test "forked PR gets no credentials, even with disable_forked_pr_cache disabled", %{
      job: job
    } do
      stub_s3_credentials_not_called()
      repo = %{pr_slug: "contributor/repo", repo_slug: "org/repo"}

      assert {:ok, nil} = Cache.find_s3(job, project(), repo, :pipeline_job, 7_200)
      refute_received :get_s3_credentials_called
    end

    test "approval enable-cache lets a forked PR job have credentials", %{job: job} do
      enable_feature("sem_approve_options")

      GrpcMock.stub(Support.FakeServers.CacheApi, :get_s3_credentials, fn _, _ ->
        s3_credentials()
      end)

      repo = %{pr_slug: "contributor/repo", repo_slug: "org/repo", approval_enable_cache: true}

      assert {:ok, credentials} =
               Cache.find_s3(job, project_allowing_cache(true), repo, :pipeline_job, 7_200)

      assert credentials == s3_credentials()
    end

    test "debug job on a forked PR gets no credentials, even when approved", %{job: job} do
      enable_feature("sem_approve_options")
      stub_s3_credentials_not_called()
      repo = %{pr_slug: "contributor/repo", repo_slug: "org/repo", approval_enable_cache: true}

      assert {:ok, nil} =
               Cache.find_s3(job, project_allowing_cache(true), repo, :debug_job, 7_200)

      refute_received :get_s3_credentials_called
    end
  end

  describe ".files and .env_vars with S3 credentials" do
    setup do
      {:ok, job} = Support.Factories.Job.create(:pending, %{})
      %{job: job}
    end

    test "no key file", %{job: job} do
      assert Cache.files(job, s3_credentials()) == {:ok, []}
    end

    test "sets the S3 backend and the credentials", %{job: job} do
      assert {:ok, envs} = Cache.env_vars(job, s3_credentials(), @org_id)
      assert envs == expected_s3_envs()
    end

    test "adds the parallel archive method when it is enabled", %{job: job} do
      Mox.stub(Support.MockedProvider, :provide_features, fn _, _ ->
        {:ok, features} = Support.StubbedProvider.provide_features()

        {:ok,
         Enum.map(features, fn
           %FeatureProvider.Feature{type: "cache_cli_parallel_archive_method"} = feature ->
             %{feature | quantity: 1, state: :enabled}

           feature ->
             feature
         end)}
      end)

      assert {:ok, envs} = Cache.env_vars(job, s3_credentials(), @org_id)

      assert envs ==
               expected_s3_envs() ++
                 [
                   %{
                     "name" => "SEMAPHORE_CACHE_ARCHIVE_METHOD",
                     "value" => Base.encode64("native-parallel")
                   }
                 ]
    end

    test "sets none when the job sets a SEMAPHORE_CACHE_* variable itself", %{job: job} do
      assert {:ok, []} =
               Cache.env_vars(job, s3_credentials(), @org_id, ["A", "SEMAPHORE_CACHE_S3_BUCKET"])

      assert {:ok, []} = Cache.env_vars(job, s3_credentials(), @org_id, ["semaphore_cache_url"])
    end

    test "variables of other groups do not count", %{job: job} do
      assert {:ok, envs} =
               Cache.env_vars(job, s3_credentials(), @org_id, [
                 "AWS_ACCESS_KEY_ID",
                 "SEMAPHORE_REGISTRY_URL",
                 "SEMAPHORE_CACHE"
               ])

      assert envs == expected_s3_envs()
    end

    test "the SFTP variables do not depend on the job's own variables", %{job: job} do
      assert {:ok, envs} = Cache.env_vars(job, @cache, @org_id, ["SEMAPHORE_CACHE_URL"])
      assert envs == expected_envs(false)
    end
  end

  defp project do
    %Zebra.Models.Project{id: Ecto.UUID.generate(), cache_id: @cache_id}
  end

  defp s3_credentials do
    InternalApi.Cache.GetS3CredentialsResponse.new(
      status: ResponseStatus.new(code: ResponseStatus.Code.value(:OK)),
      region: "us-east-1",
      bucket: "cache-bucket",
      prefix: "project-prefix",
      access_key_id: "s3-access-key-id",
      secret_access_key: @s3_secret,
      session_token: @s3_session_token,
      expires_at: Google.Protobuf.Timestamp.new(seconds: 1_800_000_000)
    )
  end

  defp stub_s3_credentials_not_called do
    test_pid = self()

    GrpcMock.stub(Support.FakeServers.CacheApi, :get_s3_credentials, fn _, _ ->
      send(test_pid, :get_s3_credentials_called)
      raise "cachehub should not be asked for S3 credentials"
    end)
  end

  defp expected_s3_envs do
    [
      %{"name" => "SEMAPHORE_CACHE_BACKEND", "value" => Base.encode64("s3")},
      %{"name" => "SEMAPHORE_CACHE_S3_BUCKET", "value" => Base.encode64("cache-bucket")},
      %{"name" => "SEMAPHORE_CACHE_S3_REGION", "value" => Base.encode64("us-east-1")},
      %{"name" => "SEMAPHORE_CACHE_S3_KEY", "value" => Base.encode64("s3-access-key-id")},
      %{"name" => "SEMAPHORE_CACHE_S3_SECRET", "value" => Base.encode64(@s3_secret)},
      %{
        "name" => "SEMAPHORE_CACHE_S3_SESSION_TOKEN",
        "value" => Base.encode64(@s3_session_token)
      }
    ]
  end

  defp project_allowing_cache(allowed) do
    %Zebra.Models.Project{
      cache_id: @cache_id,
      forked_pull_requests:
        InternalApi.Projecthub.Project.Spec.Repository.ForkedPullRequests.new(
          allow_sem_approve_enable_cache: allowed
        )
    }
  end

  defp expected_envs(new_method_enabled) do
    vars = [
      %{
        "name" => "SSH_PRIVATE_KEY_PATH",
        "value" => Base.encode64("/home/semaphore/.ssh/semaphore_cache_key")
      },
      %{
        "name" => "SEMAPHORE_CACHE_BACKEND",
        "value" => Base.encode64("sftp")
      },
      %{
        "name" => "SEMAPHORE_CACHE_PRIVATE_KEY_PATH",
        "value" => Base.encode64("/home/semaphore/.ssh/semaphore_cache_key")
      },
      %{
        "name" => "SEMAPHORE_CACHE_USERNAME",
        "value" => Base.encode64(String.replace(@cache_id, "-", ""))
      },
      %{
        "name" => "SEMAPHORE_CACHE_URL",
        "value" => Base.encode64("localhost:29920")
      }
    ]

    if new_method_enabled do
      vars ++
        [
          %{
            "name" => "SEMAPHORE_CACHE_ARCHIVE_METHOD",
            "value" => Base.encode64("native-parallel")
          }
        ]
    else
      vars
    end
  end

  defp enable_feature(type), do: enable_features(List.wrap(type))

  defp enable_features(types) do
    Mox.stub(Support.MockedProvider, :provide_features, fn _, _ ->
      features =
        Support.StubbedProvider.provide_features()
        |> case do
          {:ok, features} -> features
          {:error, _} -> []
        end

      extra_features = Enum.map(types, &Support.StubbedProvider.feature(&1, [:enabled]))

      {:ok, extra_features ++ features}
    end)
  end
end
