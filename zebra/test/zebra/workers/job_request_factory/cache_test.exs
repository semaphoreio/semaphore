# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
defmodule Zebra.Workers.JobRequestFactory.CacheTest do
  use Zebra.DataCase

  alias Zebra.Workers.JobRequestFactory.Cache

  defmodule CephStsSuccessMock do
    def assume_role(role_arn, session_name, duration_seconds) do
      send(self(), {:assume_role_called, role_arn, session_name, duration_seconds})

      {:ok,
       %{
         access_key_id: "tmp-access",
         secret_access_key: "tmp-secret",
         session_token: "tmp-token"
       }}
    end
  end

  defmodule CephStsFailureMock do
    def assume_role(_role_arn, _session_name, _duration_seconds), do: {:error, :boom}
  end

  @org_id Ecto.UUID.generate()
  @cache_id Ecto.UUID.generate()

  @sftp_cache InternalApi.Cache.Cache.new(
                id: @cache_id,
                credential: "--BEGIN....lalalala...cache_key...END---",
                url: "localhost:29920",
                backend: InternalApi.Cache.Backend.value(:SFTP)
              )

  @ceph_cache InternalApi.Cache.Cache.new(
                id: @cache_id,
                backend: InternalApi.Cache.Backend.value(:CEPH),
                state: InternalApi.Cache.CacheState.value(:READY),
                bucket: "project-bucket",
                ro_role_arn: "arn:aws:iam::acc:role/project-ro",
                rw_role_arn: "arn:aws:iam::acc:role/project-rw"
              )

  setup do
    Application.put_env(:zebra, :ceph_sts_client_module, CephStsSuccessMock)
    System.put_env("CEPH_ENDPOINT", "https://ceph.example.com")

    on_exit(fn ->
      Application.delete_env(:zebra, :ceph_sts_client_module)
      System.delete_env("CEPH_ENDPOINT")
    end)

    :ok
  end

  describe ".files" do
    test "sftp cache => injects private key file" do
      {:ok, job} = Support.Factories.Job.create(:pending, %{})
      {:ok, files} = Cache.files(job, @sftp_cache)

      assert files == [
               %{
                 "path" => "/home/semaphore/.ssh/semaphore_cache_key",
                 "content" => Base.encode64("--BEGIN....lalalala...cache_key...END---"),
                 "mode" => "0600"
               }
             ]
    end

    test "ceph cache => does not inject key file" do
      {:ok, job} = Support.Factories.Job.create(:pending, %{})
      assert {:ok, []} = Cache.files(job, @ceph_cache)
    end
  end

  describe ".env_vars sftp" do
    test "cache_cli_parallel_archive_method is enabled => uses parallel archive method" do
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
      {:ok, envs} = Cache.env_vars(job, @sftp_cache, @org_id, nil, :pipeline_job)
      expected_envs = expected_sftp_envs(true)
      assert envs == expected_envs
    end

    test "cache_cli_parallel_archive_method is disabled => does not use parallel archive method" do
      {:ok, job} = Support.Factories.Job.create(:pending, %{})
      {:ok, envs} = Cache.env_vars(job, @sftp_cache, @org_id, nil, :pipeline_job)
      expected_envs = expected_sftp_envs(false)
      assert envs == expected_envs
    end
  end

  describe ".env_vars ceph" do
    test "non-forked job => uses RW role and injects temporary AWS credentials" do
      {:ok, job} = Support.Factories.Job.create(:pending, %{})

      repo_proxy = %{repo_slug: "org/repo", pr_slug: ""}
      {:ok, envs} = Cache.env_vars(job, @ceph_cache, @org_id, repo_proxy, :pipeline_job)

      assert_receive {:assume_role_called, "arn:aws:iam::acc:role/project-rw", _session, 87_300}

      assert envs == [
               %{"name" => "SEMAPHORE_CACHE_BACKEND", "value" => Base.encode64("s3")},
               %{
                 "name" => "SEMAPHORE_CACHE_S3_URL",
                 "value" => Base.encode64("https://ceph.example.com")
               },
               %{
                 "name" => "SEMAPHORE_CACHE_S3_BUCKET",
                 "value" => Base.encode64("project-bucket")
               },
               %{"name" => "AWS_ACCESS_KEY_ID", "value" => Base.encode64("tmp-access")},
               %{"name" => "AWS_SECRET_ACCESS_KEY", "value" => Base.encode64("tmp-secret")},
               %{"name" => "AWS_SESSION_TOKEN", "value" => Base.encode64("tmp-token")}
             ]
    end

    test "forked PR regular job => uses RO role and regular STS duration" do
      {:ok, job} = Support.Factories.Job.create(:pending, %{})

      repo_proxy = %{repo_slug: "base/repo", pr_slug: "fork/repo"}
      {:ok, _envs} = Cache.env_vars(job, @ceph_cache, @org_id, repo_proxy, :pipeline_job)

      assert_receive {:assume_role_called, "arn:aws:iam::acc:role/project-ro", _session, 87_300}
    end

    test "forked PR debug job => uses RO role and debug STS duration" do
      {:ok, job} = Support.Factories.Job.create(:pending, %{})

      repo_proxy = %{repo_slug: "base/repo", pr_slug: "fork/repo"}
      {:ok, _envs} = Cache.env_vars(job, @ceph_cache, @org_id, repo_proxy, :debug_job)

      assert_receive {:assume_role_called, "arn:aws:iam::acc:role/project-ro", _session, 4_200}
    end

    test "sts failure => cache env vars are skipped" do
      Application.put_env(:zebra, :ceph_sts_client_module, CephStsFailureMock)

      {:ok, job} = Support.Factories.Job.create(:pending, %{})
      repo_proxy = %{repo_slug: "org/repo", pr_slug: ""}

      assert {:ok, []} = Cache.env_vars(job, @ceph_cache, @org_id, repo_proxy, :pipeline_job)
    end
  end

  test "session_name_for_job normalizes disallowed chars and limits length" do
    session_name = Cache.session_name_for_job("ABC/123:weird*chars-#{String.duplicate("x", 80)}", true)

    assert byte_size(session_name) <= 64
    assert session_name =~ ~r/^[a-z0-9+=,.@-]+$/
  end

  defp expected_sftp_envs(new_method_enabled) do
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
end
