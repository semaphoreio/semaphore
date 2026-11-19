defmodule Zebra.Workers.JobRequestFactoryTest do
  alias Support.Factories
  use Zebra.DataCase

  import ExUnit.CaptureLog

  alias Zebra.Models.Job
  alias Zebra.Workers.JobRequestFactory, as: Worker
  alias Zebra.Workers.JobRequestFactory.JobRequest

  @artifact_token "asdfg"
  @project_id Ecto.UUID.generate()
  @cache_id Ecto.UUID.generate()
  @job_spec %{
    "agent" => %{
      "machine" => %{
        "type" => "e1-standard-2",
        "os_image" => "ubuntu1804"
      }
    },
    "env_vars" => [
      %{"name" => "IGOR", "value" => "TRUE"},
      %{"name" => "SEMAPHORE_WORKFLOW_TRIGGERED_BY_HOOK", "value" => "true"}
    ],
    "files" => [
      %{"path" => "/var/log/sem", "content" => "ZXRlcm5hbCBzdW5zaGluZQo="}
    ],
    "secrets" => [
      %{"name" => "aws-secrets"}
    ],
    "commands" => [
      "echo 'here'"
    ],
    "epilogue_always_commands" => [
      "echo 'always'"
    ],
    "epilogue_on_pass_commands" => [
      "echo 'on pass'"
    ],
    "epilogue_on_fail_commands" => [
      "echo 'on fail'"
    ],
    "project_id" => @project_id
  }

  @job_spec_with_containers %{
    "agent" => %{
      "machine" => %{
        "type" => "e1-standard-2",
        "os_image" => "ubuntu1804"
      },
      "containers" => [
        %{
          "name" => "main",
          "image" => "ruby:2.6.1"
        },
        %{
          "name" => "db",
          "image" => "postgres:9.6",
          "env_vars" => [
            %{"name" => "POSTGRES_PASSWORD", "value" => "keyboard-cat"}
          ]
        }
      ]
    },
    "env_vars" => [
      %{"name" => "IGOR", "value" => "TRUE"},
      %{"name" => "SEMAPHORE_WORKFLOW_TRIGGERED_BY_HOOK", "value" => "true"}
    ],
    "files" => [
      %{"path" => "/var/log/sem", "content" => "ZXRlcm5hbCBzdW5zaGluZQo="}
    ],
    "secrets" => [
      %{"name" => "aws-secrets"}
    ],
    "commands" => [
      "echo 'here'"
    ],
    "epilogue_always_commands" => [
      "echo 'always'"
    ],
    "epilogue_on_pass_commands" => [
      "echo 'on pass'"
    ],
    "epilogue_on_fail_commands" => [
      "echo 'on fail'"
    ],
    "project_id" => @project_id
  }

  @oidc_token_value "very-secret-oidc-token-value"

  setup do
    GrpcMock.stub(Support.FakeServers.RepositoryApi, :describe, fn _, _ ->
      key = "--BEGIN....lalalala..private_key...END---"

      repository =
        InternalApi.Repository.Repository.new(
          name: "zebra",
          url: "git@github.com:/test-org/test-repo.git",
          provider: "github"
        )

      InternalApi.Repository.DescribeResponse.new(repository: repository, private_ssh_key: key)
    end)

    GrpcMock.stub(Support.FakeServers.ProjecthubApi, :describe, fn _, _ ->
      alias InternalApi.Projecthub.ResponseMeta
      alias InternalApi.Projecthub.Project
      meta = ResponseMeta.new(status: ResponseMeta.Status.new(code: ResponseMeta.Code.value(:OK)))

      project =
        Project.new(
          metadata: Project.Metadata.new(name: "zebra"),
          spec:
            Project.Spec.new(
              repository:
                Project.Spec.Repository.new(url: "git@github.com:/test-org/test-repo.git"),
              cache_id: @cache_id,
              artifact_store_id: Ecto.UUID.generate()
            )
          # private_git_key: "--BEGIN....lalalala..private_key...END---",
        )

      InternalApi.Projecthub.DescribeResponse.new(metadata: meta, project: project)
    end)

    GrpcMock.stub(Support.FakeServers.Loghub2Api, :generate_token, fn _, _ ->
      InternalApi.Loghub2.GenerateTokenResponse.new(
        token: "very-sensitive-jwt-token",
        type: InternalApi.Loghub2.TokenType.value(:PUSH)
      )
    end)

    GrpcMock.stub(Support.FakeServers.OrganizationApi, :describe, fn _, _ ->
      status = InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK))

      organization =
        InternalApi.Organization.Organization.new(
          org_username: "zebraz-org",
          org_id: "9878dc83-oooo-4b67-a417-f31f2fa0f105"
        )

      InternalApi.Organization.DescribeResponse.new(
        status: status,
        organization: organization
      )
    end)

    GrpcMock.stub(Support.FakeServers.ArtifactApi, :generate_token, fn _, _ ->
      %InternalApi.Artifacthub.GenerateTokenResponse{
        token: @artifact_token
      }
    end)

    GrpcMock.stub(Support.FakeServers.CacheApi, :describe, fn req, _ ->
      InternalApi.Cache.DescribeResponse.new(
        status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
        cache:
          InternalApi.Cache.Cache.new(
            id: req.cache_id,
            credential: "--BEGIN....lalalala...cache_key...END---",
            url: "localhost:29920"
          )
      )
    end)

    GrpcMock.stub(Support.FakeServers.SecretsApi, :checkout_many, fn req, _ ->
      if req.checkout_metadata do
        InternalApi.Secrethub.CheckoutManyResponse.new(
          secrets: [
            InternalApi.Secrethub.Secret.new(
              metadata: InternalApi.Secrethub.Secret.Metadata.new(name: "aws-secrets"),
              data:
                InternalApi.Secrethub.Secret.Data.new(
                  env_vars: [
                    InternalApi.Secrethub.Secret.EnvVar.new(name: "A", value: "B"),
                    InternalApi.Secrethub.Secret.EnvVar.new(name: "T", value: "C")
                  ],
                  files: [
                    InternalApi.Secrethub.Secret.File.new(
                      path: "/home/a/b",
                      content: "QWxsIHlvdXIgYmFzZSBiZWxvbmcgdG8gdXMK"
                    )
                  ]
                )
            )
          ]
        )
      else
        alias InternalApi.Secrethub.ResponseMeta

        InternalApi.Secrethub.CheckoutManyResponse.new(
          metadata:
            ResponseMeta.new(
              ResponseMeta.Status.new(
                code: ResponseMeta.Code.value(:FAILED_PRECONDITION),
                message: "checkout_metadata is required"
              )
            )
        )
      end
    end)

    GrpcMock.stub(Support.FakeServers.SecretsApi, :generate_open_id_connect_token, fn _, _ ->
      InternalApi.Secrethub.GenerateOpenIDConnectTokenResponse.new(token: @oidc_token_value)
    end)

    GrpcMock.stub(Support.FakeServers.RepoProxyApi, :describe, fn _, _ ->
      status = InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK))

      hook =
        InternalApi.RepoProxy.Hook.new(
          hook_id: "",
          head_commit_sha: "8d762d04c7c753c2181030a9385b496559e5a885",
          commit_message: "",
          commit_range: "123...456",
          repo_host_url: "",
          repo_host_username: "",
          repo_host_email: "",
          repo_host_avatar_url: "",
          user_id: "",
          semaphore_email: "",
          repo_slug: "test-org/test-repo",
          git_ref: "refs/heads/master",
          git_ref_type: InternalApi.RepoProxy.Hook.Type.value(:BRANCH),
          pr_slug: "",
          pr_name: "",
          pr_number: "",
          pr_sha: "",
          pr_mergeable: false,
          tag_name: "",
          branch_name: "master",
          pr_branch_name: ""
        )

      %InternalApi.RepoProxy.DescribeResponse{status: status, hook: hook}
    end)

    GrpcMock.stub(Support.FakeServers.SelfHosted, :list, fn _, _ ->
      InternalApi.SelfHosted.ListResponse.new(
        agent_types: [
          InternalApi.SelfHosted.AgentType.new(
            organization_id: "9878dc83-oooo-4b67-a417-f31f2fa0f105",
            name: "s1-test-1"
          )
        ]
      )
    end)

    :ok
  end

  test "when pending job with spec exists => creates job req" do
    {:ok, task} = Support.Factories.Task.create()
    {:ok, job} = Support.Factories.Job.create(:pending, %{spec: @job_spec, build_id: task.id})

    assert job.aasm_state == "pending"

    {:ok, job} = Worker.process(job)

    assert job.aasm_state == "enqueued"

    assert MapSet.new(Map.keys(job.request)) ==
             MapSet.new([
               "job_id",
               "job_name",
               "commands",
               "ssh_public_keys",
               "files",
               "env_vars",
               "callbacks",
               "epilogue_always_commands",
               "epilogue_on_fail_commands",
               "epilogue_on_pass_commands",
               "logger"
             ])

    assert job.request["job_id"] == job.id
    assert job.request["job_name"] == job.name

    assert job.request["files"] == [
             %{
               "path" => "/home/semaphore/.ssh/semaphore_cache_key",
               "content" => Base.encode64("--BEGIN....lalalala...cache_key...END---"),
               "mode" => "0600"
             },
             %{
               "path" => ".ssh/id_rsa",
               "content" => Base.encode64("--BEGIN....lalalala..private_key...END---"),
               "mode" => "0600"
             },
             %{
               "path" => "/home/a/b",
               "content" => Base.encode64("All your base belong to us\n"),
               "mode" => "0644"
             },
             %{
               "path" => "/var/log/sem",
               "content" => Base.encode64("eternal sunshine\n"),
               "mode" => "0644"
             }
           ]

    assert length(job.request["ssh_public_keys"]) == 1

    assert job.request["env_vars"] == [
             %{
               "name" => "PAGER",
               "value" => Base.encode64("cat")
             },
             %{
               "name" => "DISPLAY",
               "value" => Base.encode64(":99")
             },
             %{
               "name" => "GIT_TERMINAL_PROMPT",
               "value" => Base.encode64("0")
             },
             %{
               "name" => "TERM",
               "value" => Base.encode64("xterm")
             },
             %{
               "name" => "CI",
               "value" => Base.encode64("true")
             },
             %{
               "name" => "SEMAPHORE",
               "value" => Base.encode64("true")
             },
             %{
               "name" => "SEMAPHORE_PROJECT_NAME",
               "value" => Base.encode64("zebra")
             },
             %{
               "name" => "SEMAPHORE_PROJECT_ID",
               "value" => Base.encode64(Factories.Job.project_id())
             },
             %{
               "name" => "SEMAPHORE_JOB_NAME",
               "value" => Base.encode64(job.name)
             },
             %{
               "name" => "SEMAPHORE_JOB_ID",
               "value" => Base.encode64(job.id)
             },
             %{
               "name" => "SEMAPHORE_JOB_CREATION_TIME",
               "value" => Base.encode64(to_string(DateTime.to_unix(job.created_at)))
             },
             %{
               "name" => "SEMAPHORE_JOB_TYPE",
               "value" => Base.encode64("pipeline_job")
             },
             %{
               "name" => "SEMAPHORE_AGENT_MACHINE_TYPE",
               "value" => Base.encode64("e1-standard-2")
             },
             %{
               "name" => "SEMAPHORE_AGENT_MACHINE_OS_IMAGE",
               "value" => Base.encode64("ubuntu1804")
             },
             %{
               "name" => "SEMAPHORE_AGENT_MACHINE_ENVIRONMENT_TYPE",
               "value" => Base.encode64("VM")
             },
             %{
               "name" => "SEMAPHORE_ORGANIZATION_URL",
               "value" => Base.encode64("https://zebraz-org.semaphore.test")
             },
             %{
               "name" => "SEMAPHORE_ARTIFACT_TOKEN",
               "value" => Base.encode64(@artifact_token)
             },
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
             },
             %{
               "name" => "SEMAPHORE_TOOLBOX_METRICS_ENABLED",
               "value" => Base.encode64("true")
             },
             %{
               "name" => "SEMAPHORE_OIDC_TOKEN",
               "value" => Base.encode64(@oidc_token_value)
             },
             %{
               "name" => "SEMAPHORE_GIT_PROVIDER",
               "value" => Base.encode64("github")
             },
             %{
               "name" => "SEMAPHORE_GIT_URL",
               "value" => Base.encode64("git@github.com:/test-org/test-repo.git")
             },
             %{
               "name" => "SEMAPHORE_GIT_REPO_NAME",
               "value" => Base.encode64("zebra")
             },
             %{
               "name" => "SEMAPHORE_GIT_DIR",
               "value" => Base.encode64("zebra")
             },
             %{
               "name" => "SEMAPHORE_GIT_SHA",
               "value" => Base.encode64("8d762d04c7c753c2181030a9385b496559e5a885")
             },
             %{
               "name" => "SEMAPHORE_GIT_REPO_SLUG",
               "value" => Base.encode64("test-org/test-repo")
             },
             %{
               "name" => "SEMAPHORE_GIT_REF",
               "value" => Base.encode64("refs/heads/master")
             },
             %{
               "name" => "SEMAPHORE_GIT_COMMIT_RANGE",
               "value" => Base.encode64("123...456")
             },
             %{
               "name" => "SEMAPHORE_GIT_REF_TYPE",
               "value" => Base.encode64("branch")
             },
             %{
               "name" => "SEMAPHORE_GIT_BRANCH",
               "value" => Base.encode64("master")
             },
             %{
               "name" => "SEMAPHORE_GIT_WORKING_BRANCH",
               "value" => Base.encode64("master")
             },
             %{
               "name" => "A",
               "value" => Base.encode64("B")
             },
             %{
               "name" => "T",
               "value" => Base.encode64("C")
             },
             %{
               "name" => "IGOR",
               "value" => Base.encode64("TRUE")
             },
             %{
               "name" => "SEMAPHORE_WORKFLOW_TRIGGERED_BY_HOOK",
               "value" => Base.encode64("true")
             }
           ]

    assert job.request["commands"] == [
             %{"directive" => "echo 'here'"}
           ]

    assert job.request["epilogue_always_commands"] == [
             %{"directive" => "echo 'always'"}
           ]

    assert job.request["epilogue_on_fail_commands"] == [
             %{"directive" => "echo 'on fail'"}
           ]

    assert job.request["epilogue_on_pass_commands"] == [
             %{"directive" => "echo 'on pass'"}
           ]

    assert is_map(job.request["callbacks"])

    assert job.request["callbacks"]["teardown_finished"] ==
             "https://s2-callback.semaphoretest.xyz/teardown_finished/#{job.id}"

    assert job.request["callbacks"]["finished"] ==
             "https://s2-callback.semaphoretest.xyz/finished/#{job.id}"

    refute is_nil(job.request["callbacks"]["token"])
    refute job.request["callbacks"]["token"] == ""

    assert job.request["logger"] == %{
             "method" => "pull"
           }
  end

  test "when pending debug job with spec exists => creates job req" do
    {:ok, task} = Support.Factories.Task.create()
    {:ok, job} = Support.Factories.Job.create(:finished, %{spec: @job_spec, build_id: task.id})

    {:ok, debug_job} = Support.Factories.Job.create(:pending, %{spec: @job_spec, build_id: nil})
    {:ok, _debug} = Support.Factories.Debug.create_for_job(job.id, debug_job.id)

    {:ok, debug_job} = Worker.process(debug_job)

    assert job.aasm_state == "finished"
    assert debug_job.aasm_state == "enqueued"

    assert MapSet.new(Map.keys(debug_job.request)) ==
             MapSet.new([
               "job_id",
               "job_name",
               "commands",
               "ssh_public_keys",
               "files",
               "env_vars",
               "callbacks",
               "epilogue_always_commands",
               "epilogue_on_fail_commands",
               "epilogue_on_pass_commands",
               "logger"
             ])

    assert debug_job.request["job_id"] == debug_job.id
    assert debug_job.request["job_name"] == debug_job.name

    assert debug_job.request["files"] == [
             %{
               "path" => "/home/semaphore/.ssh/semaphore_cache_key",
               "content" => Base.encode64("--BEGIN....lalalala...cache_key...END---"),
               "mode" => "0600"
             },
             %{
               "path" => ".ssh/id_rsa",
               "content" => Base.encode64("--BEGIN....lalalala..private_key...END---"),
               "mode" => "0600"
             },
             %{
               "path" => "/home/a/b",
               "content" => Base.encode64("All your base belong to us\n"),
               "mode" => "0644"
             },
             %{
               "path" => "/var/log/sem",
               "content" => Base.encode64("eternal sunshine\n"),
               "mode" => "0644"
             }
           ]

    assert length(debug_job.request["ssh_public_keys"]) == 1

    assert debug_job.request["env_vars"] == [
             %{
               "name" => "PAGER",
               "value" => Base.encode64("cat")
             },
             %{
               "name" => "DISPLAY",
               "value" => Base.encode64(":99")
             },
             %{
               "name" => "GIT_TERMINAL_PROMPT",
               "value" => Base.encode64("0")
             },
             %{
               "name" => "TERM",
               "value" => Base.encode64("xterm")
             },
             %{
               "name" => "CI",
               "value" => Base.encode64("true")
             },
             %{
               "name" => "SEMAPHORE",
               "value" => Base.encode64("true")
             },
             %{
               "name" => "SEMAPHORE_PROJECT_NAME",
               "value" => Base.encode64("zebra")
             },
             %{
               "name" => "SEMAPHORE_PROJECT_ID",
               "value" => Base.encode64(Factories.Job.project_id())
             },
             %{
               "name" => "SEMAPHORE_JOB_NAME",
               "value" => Base.encode64(debug_job.name)
             },
             %{
               "name" => "SEMAPHORE_JOB_ID",
               "value" => Base.encode64(debug_job.id)
             },
             %{
               "name" => "SEMAPHORE_JOB_CREATION_TIME",
               "value" => Base.encode64(to_string(DateTime.to_unix(debug_job.created_at)))
             },
             %{
               "name" => "SEMAPHORE_JOB_TYPE",
               "value" => Base.encode64("debug_job")
             },
             %{
               "name" => "SEMAPHORE_AGENT_MACHINE_TYPE",
               "value" => Base.encode64("e1-standard-2")
             },
             %{
               "name" => "SEMAPHORE_AGENT_MACHINE_OS_IMAGE",
               "value" => Base.encode64("ubuntu1804")
             },
             %{
               "name" => "SEMAPHORE_AGENT_MACHINE_ENVIRONMENT_TYPE",
               "value" => Base.encode64("VM")
             },
             %{
               "name" => "SEMAPHORE_ORGANIZATION_URL",
               "value" => Base.encode64("https://zebraz-org.semaphore.test")
             },
             %{
               "name" => "SEMAPHORE_ARTIFACT_TOKEN",
               "value" => Base.encode64(@artifact_token)
             },
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
             },
             %{
               "name" => "SEMAPHORE_TOOLBOX_METRICS_ENABLED",
               "value" => Base.encode64("true")
             },
             %{
               "name" => "SEMAPHORE_OIDC_TOKEN",
               "value" => Base.encode64(@oidc_token_value)
             },
             %{
               "name" => "SEMAPHORE_GIT_PROVIDER",
               "value" => Base.encode64("github")
             },
             %{
               "name" => "SEMAPHORE_GIT_URL",
               "value" => Base.encode64("git@github.com:/test-org/test-repo.git")
             },
             %{
               "name" => "SEMAPHORE_GIT_REPO_NAME",
               "value" => Base.encode64("zebra")
             },
             %{
               "name" => "SEMAPHORE_GIT_DIR",
               "value" => Base.encode64("zebra")
             },
             %{
               "name" => "SEMAPHORE_GIT_SHA",
               "value" => Base.encode64("8d762d04c7c753c2181030a9385b496559e5a885")
             },
             %{
               "name" => "SEMAPHORE_GIT_REPO_SLUG",
               "value" => Base.encode64("test-org/test-repo")
             },
             %{
               "name" => "SEMAPHORE_GIT_REF",
               "value" => Base.encode64("refs/heads/master")
             },
             %{
               "name" => "SEMAPHORE_GIT_COMMIT_RANGE",
               "value" => Base.encode64("123...456")
             },
             %{
               "name" => "SEMAPHORE_GIT_REF_TYPE",
               "value" => Base.encode64("branch")
             },
             %{
               "name" => "SEMAPHORE_GIT_BRANCH",
               "value" => Base.encode64("master")
             },
             %{
               "name" => "SEMAPHORE_GIT_WORKING_BRANCH",
               "value" => Base.encode64("master")
             },
             %{
               "name" => "A",
               "value" => Base.encode64("B")
             },
             %{
               "name" => "T",
               "value" => Base.encode64("C")
             },
             %{
               "name" => "IGOR",
               "value" => Base.encode64("TRUE")
             },
             %{
               "name" => "SEMAPHORE_WORKFLOW_TRIGGERED_BY_HOOK",
               "value" => Base.encode64("true")
             }
           ]

    assert debug_job.request["commands"] == [
             %{"directive" => "echo 'here'"}
           ]

    assert debug_job.request["epilogue_always_commands"] == [
             %{"directive" => "echo 'always'"}
           ]

    assert debug_job.request["epilogue_on_fail_commands"] == [
             %{"directive" => "echo 'on fail'"}
           ]

    assert debug_job.request["epilogue_on_pass_commands"] == [
             %{"directive" => "echo 'on pass'"}
           ]

    assert is_map(debug_job.request["callbacks"])

    assert debug_job.request["callbacks"]["teardown_finished"] ==
             "https://s2-callback.semaphoretest.xyz/teardown_finished/#{debug_job.id}"

    assert debug_job.request["callbacks"]["finished"] ==
             "https://s2-callback.semaphoretest.xyz/finished/#{debug_job.id}"

    assert debug_job.request["logger"] == %{
             "method" => "pull"
           }
  end

  describe "job.initializing.duration metric" do
    test "cloud job => tagged with cloud and its machine type" do
      {:ok, task} = Support.Factories.Task.create()

      {:ok, job} =
        Support.Factories.Job.create(:pending, %{
          spec: @job_spec,
          build_id: task.id,
          machine_type: "e1-standard-2"
        })

      with_mock Watchman, [:passthrough], submit: fn _, _, _ -> nil end do
        {:ok, _} = Worker.process(job)

        assert_called(
          Watchman.submit(
            {"job.initializing.duration", ["cloud", "e1-standard-2"]},
            :_,
            :timing
          )
        )
      end
    end

    test "self-hosted job => tagged with self_hosted only" do
      {:ok, task} = Support.Factories.Task.create()

      {:ok, job} =
        Support.Factories.Job.create(:pending, %{
          spec: @job_spec,
          build_id: task.id,
          machine_type: "s1-test-1"
        })

      with_mock Watchman, [:passthrough], submit: fn _, _, _ -> nil end do
        {:ok, _} = Worker.process(job)

        assert_called(
          Watchman.submit({"job.initializing.duration", ["self_hosted"]}, :_, :timing)
        )
      end
    end
  end

  describe "self-hosted" do
    test "when pending self-hosted job with spec exists => creates job req" do
      {:ok, task} = Support.Factories.Task.create()

      {:ok, job} =
        Support.Factories.Job.create(:pending, %{
          spec: @job_spec,
          build_id: task.id,
          machine_type: "s1-test-1"
        })

      {:ok, job} = Worker.process(job)

      assert job.aasm_state == "enqueued"

      assert MapSet.new(Map.keys(job.request)) ==
               MapSet.new([
                 "job_id",
                 "job_name",
                 "commands",
                 "ssh_public_keys",
                 "files",
                 "env_vars",
                 "callbacks",
                 "epilogue_always_commands",
                 "epilogue_on_fail_commands",
                 "epilogue_on_pass_commands",
                 "logger"
               ])

      assert job.request["files"] == [
               %{
                 "path" => ".ssh/id_rsa",
                 "content" => Base.encode64("--BEGIN....lalalala..private_key...END---"),
                 "mode" => "0600"
               },
               %{
                 "path" => "/home/a/b",
                 "content" => Base.encode64("All your base belong to us\n"),
                 "mode" => "0644"
               },
               %{
                 "path" => "/var/log/sem",
                 "content" => Base.encode64("eternal sunshine\n"),
                 "mode" => "0644"
               }
             ]

      assert job.request["ssh_public_keys"] == []

      assert job.request["env_vars"] == [
               %{
                 "name" => "TERM",
                 "value" => Base.encode64("xterm")
               },
               %{
                 "name" => "CI",
                 "value" => Base.encode64("true")
               },
               %{
                 "name" => "SEMAPHORE",
                 "value" => Base.encode64("true")
               },
               %{
                 "name" => "SEMAPHORE_PROJECT_NAME",
                 "value" => Base.encode64("zebra")
               },
               %{
                 "name" => "SEMAPHORE_PROJECT_ID",
                 "value" => Base.encode64(Factories.Job.project_id())
               },
               %{
                 "name" => "SEMAPHORE_JOB_NAME",
                 "value" => Base.encode64(job.name)
               },
               %{
                 "name" => "SEMAPHORE_JOB_ID",
                 "value" => Base.encode64(job.id)
               },
               %{
                 "name" => "SEMAPHORE_JOB_CREATION_TIME",
                 "value" => Base.encode64(to_string(DateTime.to_unix(job.created_at)))
               },
               %{
                 "name" => "SEMAPHORE_JOB_TYPE",
                 "value" => Base.encode64("pipeline_job")
               },
               %{
                 "name" => "SEMAPHORE_AGENT_MACHINE_TYPE",
                 "value" => Base.encode64("s1-test-1")
               },
               %{
                 "name" => "SEMAPHORE_AGENT_MACHINE_OS_IMAGE",
                 "value" => Base.encode64("ubuntu1804")
               },
               %{
                 "name" => "SEMAPHORE_AGENT_MACHINE_ENVIRONMENT_TYPE",
                 "value" => Base.encode64("VM")
               },
               %{
                 "name" => "SEMAPHORE_ORGANIZATION_URL",
                 "value" => Base.encode64("https://zebraz-org.semaphore.test")
               },
               %{
                 "name" => "SEMAPHORE_ARTIFACT_TOKEN",
                 "value" => Base.encode64(@artifact_token)
               },
               %{
                 "name" => "SEMAPHORE_TOOLBOX_METRICS_ENABLED",
                 "value" => Base.encode64("false")
               },
               %{
                 "name" => "SEMAPHORE_OIDC_TOKEN",
                 "value" => Base.encode64(@oidc_token_value)
               },
               %{
                 "name" => "SEMAPHORE_GIT_PROVIDER",
                 "value" => Base.encode64("github")
               },
               %{
                 "name" => "SEMAPHORE_GIT_URL",
                 "value" => Base.encode64("git@github.com:/test-org/test-repo.git")
               },
               %{
                 "name" => "SEMAPHORE_GIT_REPO_NAME",
                 "value" => Base.encode64("zebra")
               },
               %{
                 "name" => "SEMAPHORE_GIT_DIR",
                 "value" => Base.encode64("zebra")
               },
               %{
                 "name" => "SEMAPHORE_GIT_SHA",
                 "value" => Base.encode64("8d762d04c7c753c2181030a9385b496559e5a885")
               },
               %{
                 "name" => "SEMAPHORE_GIT_REPO_SLUG",
                 "value" => Base.encode64("test-org/test-repo")
               },
               %{
                 "name" => "SEMAPHORE_GIT_REF",
                 "value" => Base.encode64("refs/heads/master")
               },
               %{
                 "name" => "SEMAPHORE_GIT_COMMIT_RANGE",
                 "value" => Base.encode64("123...456")
               },
               %{
                 "name" => "SEMAPHORE_GIT_REF_TYPE",
                 "value" => Base.encode64("branch")
               },
               %{
                 "name" => "SEMAPHORE_GIT_BRANCH",
                 "value" => Base.encode64("master")
               },
               %{
                 "name" => "SEMAPHORE_GIT_WORKING_BRANCH",
                 "value" => Base.encode64("master")
               },
               %{
                 "name" => "A",
                 "value" => Base.encode64("B")
               },
               %{
                 "name" => "T",
                 "value" => Base.encode64("C")
               },
               %{
                 "name" => "IGOR",
                 "value" => Base.encode64("TRUE")
               },
               %{
                 "name" => "SEMAPHORE_WORKFLOW_TRIGGERED_BY_HOOK",
                 "value" => Base.encode64("true")
               }
             ]

      assert job.request["commands"] == [
               %{"directive" => "echo 'here'"}
             ]

      assert job.request["epilogue_always_commands"] == [
               %{"directive" => "echo 'always'"}
             ]

      assert job.request["epilogue_on_fail_commands"] == [
               %{"directive" => "echo 'on fail'"}
             ]

      assert job.request["epilogue_on_pass_commands"] == [
               %{"directive" => "echo 'on pass'"}
             ]

      assert is_map(job.request["callbacks"])

      assert job.request["callbacks"]["teardown_finished"] ==
               "https://s2-callback.semaphoretest.xyz/teardown_finished/#{job.id}"

      assert job.request["callbacks"]["finished"] ==
               "https://s2-callback.semaphoretest.xyz/finished/#{job.id}"

      refute is_nil(job.request["callbacks"]["token"])
      assert job.request["callbacks"]["token"] == ""

      assert job.request["logger"] == %{
               "method" => "push",
               "url" => "https://zebraz-org.semaphore.test/api/v1/logs/#{job.id}",
               "token" => "very-sensitive-jwt-token"
             }
    end
  end

  test "when pending job with containers definition exists => creates job req" do
    {:ok, task} = Support.Factories.Task.create()

    {:ok, job} =
      Support.Factories.Job.create(:pending, %{
        spec: @job_spec_with_containers,
        build_id: task.id
      })

    {:ok, job} = Worker.process(job)

    assert job.aasm_state == "enqueued"

    assert MapSet.new(Map.keys(job.request)) ==
             MapSet.new([
               "job_id",
               "job_name",
               "executor",
               "compose",
               "commands",
               "ssh_public_keys",
               "files",
               "env_vars",
               "callbacks",
               "epilogue_always_commands",
               "epilogue_on_fail_commands",
               "epilogue_on_pass_commands",
               "logger"
             ])

    assert job.request["job_id"] == job.id
    assert job.request["job_name"] == job.name
    assert job.request["executor"] == "dockercompose"

    assert job.request["compose"] == %{
             "containers" => [
               %{
                 "command" => "",
                 "env_vars" => [],
                 "files" => [],
                 "image" => "ruby:2.6.1",
                 "name" => "main"
               },
               %{
                 "command" => "",
                 "env_vars" => [
                   %{
                     "name" => "POSTGRES_PASSWORD",
                     "value" => "a2V5Ym9hcmQtY2F0"
                   }
                 ],
                 "files" => [],
                 "image" => "postgres:9.6",
                 "name" => "db"
               }
             ],
             "image_pull_credentials" => [],
             "host_setup_commands" => []
           }

    assert length(job.request["ssh_public_keys"]) == 1

    assert job.request["files"] == [
             %{
               "path" => "~/.ssh/semaphore_cache_key",
               "content" => Base.encode64("--BEGIN....lalalala...cache_key...END---"),
               "mode" => "0600"
             },
             %{
               "path" => ".ssh/id_rsa",
               "content" => Base.encode64("--BEGIN....lalalala..private_key...END---"),
               "mode" => "0600"
             },
             %{
               "path" => "/home/a/b",
               "content" => Base.encode64("All your base belong to us\n"),
               "mode" => "0644"
             },
             %{
               "path" => "/var/log/sem",
               "content" => Base.encode64("eternal sunshine\n"),
               "mode" => "0644"
             }
           ]

    assert job.request["env_vars"] == [
             %{
               "name" => "PAGER",
               "value" => Base.encode64("cat")
             },
             %{
               "name" => "DISPLAY",
               "value" => Base.encode64(":99")
             },
             %{
               "name" => "GIT_TERMINAL_PROMPT",
               "value" => Base.encode64("0")
             },
             %{
               "name" => "TERM",
               "value" => Base.encode64("xterm")
             },
             %{
               "name" => "CI",
               "value" => Base.encode64("true")
             },
             %{
               "name" => "SEMAPHORE",
               "value" => Base.encode64("true")
             },
             %{
               "name" => "SEMAPHORE_PROJECT_NAME",
               "value" => Base.encode64("zebra")
             },
             %{
               "name" => "SEMAPHORE_PROJECT_ID",
               "value" => Base.encode64(Factories.Job.project_id())
             },
             %{
               "name" => "SEMAPHORE_JOB_NAME",
               "value" => Base.encode64(job.name)
             },
             %{
               "name" => "SEMAPHORE_JOB_ID",
               "value" => Base.encode64(job.id)
             },
             %{
               "name" => "SEMAPHORE_JOB_CREATION_TIME",
               "value" => Base.encode64(to_string(DateTime.to_unix(job.created_at)))
             },
             %{
               "name" => "SEMAPHORE_JOB_TYPE",
               "value" => Base.encode64("pipeline_job")
             },
             %{
               "name" => "SEMAPHORE_AGENT_MACHINE_TYPE",
               "value" => Base.encode64("e1-standard-2")
             },
             %{
               "name" => "SEMAPHORE_AGENT_MACHINE_OS_IMAGE",
               "value" => Base.encode64("ubuntu1804")
             },
             %{
               "name" => "SEMAPHORE_AGENT_MACHINE_ENVIRONMENT_TYPE",
               "value" => Base.encode64("container")
             },
             %{
               "name" => "SEMAPHORE_ORGANIZATION_URL",
               "value" => Base.encode64("https://zebraz-org.semaphore.test")
             },
             %{
               "name" => "SEMAPHORE_ARTIFACT_TOKEN",
               "value" => Base.encode64(@artifact_token)
             },
             %{
               "name" => "SSH_PRIVATE_KEY_PATH",
               "value" => Base.encode64("~/.ssh/semaphore_cache_key")
             },
             %{
               "name" => "SEMAPHORE_CACHE_BACKEND",
               "value" => Base.encode64("sftp")
             },
             %{
               "name" => "SEMAPHORE_CACHE_PRIVATE_KEY_PATH",
               "value" => Base.encode64("~/.ssh/semaphore_cache_key")
             },
             %{
               "name" => "SEMAPHORE_CACHE_USERNAME",
               "value" => Base.encode64(String.replace(@cache_id, "-", ""))
             },
             %{
               "name" => "SEMAPHORE_CACHE_URL",
               "value" => Base.encode64("localhost:29920")
             },
             %{
               "name" => "SEMAPHORE_TOOLBOX_METRICS_ENABLED",
               "value" => Base.encode64("true")
             },
             %{
               "name" => "SEMAPHORE_OIDC_TOKEN",
               "value" => Base.encode64(@oidc_token_value)
             },
             %{
               "name" => "SEMAPHORE_GIT_PROVIDER",
               "value" => Base.encode64("github")
             },
             %{
               "name" => "SEMAPHORE_GIT_URL",
               "value" => Base.encode64("git@github.com:/test-org/test-repo.git")
             },
             %{
               "name" => "SEMAPHORE_GIT_REPO_NAME",
               "value" => Base.encode64("zebra")
             },
             %{
               "name" => "SEMAPHORE_GIT_DIR",
               "value" => Base.encode64("zebra")
             },
             %{
               "name" => "SEMAPHORE_GIT_SHA",
               "value" => Base.encode64("8d762d04c7c753c2181030a9385b496559e5a885")
             },
             %{
               "name" => "SEMAPHORE_GIT_REPO_SLUG",
               "value" => Base.encode64("test-org/test-repo")
             },
             %{
               "name" => "SEMAPHORE_GIT_REF",
               "value" => Base.encode64("refs/heads/master")
             },
             %{
               "name" => "SEMAPHORE_GIT_COMMIT_RANGE",
               "value" => Base.encode64("123...456")
             },
             %{
               "name" => "SEMAPHORE_GIT_REF_TYPE",
               "value" => Base.encode64("branch")
             },
             %{
               "name" => "SEMAPHORE_GIT_BRANCH",
               "value" => Base.encode64("master")
             },
             %{
               "name" => "SEMAPHORE_GIT_WORKING_BRANCH",
               "value" => Base.encode64("master")
             },
             %{
               "name" => "A",
               "value" => Base.encode64("B")
             },
             %{
               "name" => "T",
               "value" => Base.encode64("C")
             },
             %{
               "name" => "IGOR",
               "value" => Base.encode64("TRUE")
             },
             %{
               "name" => "SEMAPHORE_WORKFLOW_TRIGGERED_BY_HOOK",
               "value" => Base.encode64("true")
             }
           ]

    assert job.request["commands"] == [
             %{"directive" => "echo 'here'"}
           ]

    assert job.request["epilogue_always_commands"] == [
             %{"directive" => "echo 'always'"}
           ]

    assert job.request["epilogue_on_fail_commands"] == [
             %{"directive" => "echo 'on fail'"}
           ]

    assert job.request["epilogue_on_pass_commands"] == [
             %{"directive" => "echo 'on pass'"}
           ]

    assert is_map(job.request["callbacks"])

    assert job.request["callbacks"]["teardown_finished"] ==
             "https://s2-callback.semaphoretest.xyz/teardown_finished/#{job.id}"

    assert job.request["callbacks"]["finished"] ==
             "https://s2-callback.semaphoretest.xyz/finished/#{job.id}"

    refute is_nil(job.request["callbacks"]["token"])
    refute job.request["callbacks"]["token"] == ""

    assert job.request["logger"] == %{
             "method" => "pull"
           }
  end

  test "when project doesn't exist => doesn't process the job" do
    {:ok, task} = Support.Factories.Task.create()
    {:ok, job} = Support.Factories.Job.create(:pending, %{spec: @job_spec, build_id: task.id})

    GrpcMock.stub(Support.FakeServers.ProjecthubApi, :describe, fn _, _ ->
      alias InternalApi.Projecthub.ResponseMeta

      meta =
        ResponseMeta.new(
          status: ResponseMeta.Status.new(code: ResponseMeta.Code.value(:FAILED_PRECONDITION))
        )

      InternalApi.Projecthub.DescribeResponse.new(metadata: meta)
    end)

    assert {:ok, job} = Worker.process(job)

    assert Job.finished?(job)
    assert Job.failed?(job)
    assert job.failure_reason == "Project #{Factories.Job.project_id()} not found"
  end

  test "when we can't connect to project api => doesn't process the job" do
    GrpcMock.stub(Support.FakeServers.ProjecthubApi, :describe, fn _, _ ->
      raise "muahhahaaha"
    end)

    {:ok, task} = Support.Factories.Task.create()
    {:ok, job} = Support.Factories.Job.create(:pending, %{spec: @job_spec, build_id: task.id})

    assert {:error, :communication_error} = Worker.process(job)

    assert job.aasm_state == "pending"
  end

  describe "when a helper task is slower than the await timeout" do
    setup do
      Application.put_env(:zebra, :job_request_factory_await_timeout, 200)
      on_exit(fn -> Application.delete_env(:zebra, :job_request_factory_await_timeout) end)
    end

    test "slow key generation => skips the job and leaves it pending" do
      {:ok, task} = Support.Factories.Task.create()
      {:ok, job} = Support.Factories.Job.create(:pending, %{spec: @job_spec, build_id: task.id})

      with_mock Zebra.RSA, generate: fn -> :timer.sleep(2_000) end do
        capture_log(fn ->
          assert {:error, {:timeout, :rsa}} = Worker.process(job)
        end)
      end

      assert Job.reload(job).aasm_state == "pending"
    end

    test "slow project api => skips the job and leaves it pending" do
      GrpcMock.stub(Support.FakeServers.ProjecthubApi, :describe, fn _, _ ->
        :timer.sleep(2_000)
        raise "too late"
      end)

      {:ok, task} = Support.Factories.Task.create()
      {:ok, job} = Support.Factories.Job.create(:pending, %{spec: @job_spec, build_id: task.id})

      with_mock Zebra.RSA,
        generate: fn -> %Zebra.RSA{private_key: "private", public_key: "public"} end do
        capture_log(fn ->
          assert {:error, {:timeout, :project}} = Worker.process(job)
        end)
      end

      assert Job.reload(job).aasm_state == "pending"
    end
  end

  test "when we can't connect to loghub2 api => doesn't process self-hosted job" do
    GrpcMock.stub(Support.FakeServers.Loghub2Api, :generate_token, fn _, _ ->
      raise "muahhahaaha"
    end)

    {:ok, task} = Support.Factories.Task.create()

    {:ok, job} =
      Support.Factories.Job.create(:pending, %{
        spec: @job_spec,
        build_id: task.id,
        machine_type: "s1-test-1"
      })

    assert {:error, :communication_error} = Worker.process(job)

    assert job.aasm_state == "pending"
  end

  test "when we can't connect to loghub2 api => process hosted job" do
    GrpcMock.stub(Support.FakeServers.Loghub2Api, :generate_token, fn _, _ ->
      raise "muahhahaaha"
    end)

    {:ok, task} = Support.Factories.Task.create()
    {:ok, job} = Support.Factories.Job.create(:pending, %{spec: @job_spec, build_id: task.id})
    {:ok, job} = Worker.process(job)

    assert Job.enqueued?(job)
  end

  test "when we can't connect to secrets api => doesn't process the job" do
    GrpcMock.stub(Support.FakeServers.SecretsApi, :checkout_many, fn _, _ ->
      raise "muahhahaaha"
    end)

    {:ok, task} = Support.Factories.Task.create()
    {:ok, job} = Support.Factories.Job.create(:pending, %{spec: @job_spec, build_id: task.id})

    assert {:error, :communication_error} = Worker.process(job)

    assert job.aasm_state == "pending"
  end

  test "when we can't find a secret => force fails the job" do
    GrpcMock.stub(Support.FakeServers.SecretsApi, :checkout_many, fn _, _ ->
      InternalApi.Secrethub.CheckoutManyResponse.new(secrets: [])
    end)

    {:ok, task} = Support.Factories.Task.create()
    {:ok, job} = Support.Factories.Job.create(:pending, %{spec: @job_spec, build_id: task.id})

    assert {:ok, job} = Worker.process(job)

    assert Job.finished?(job)
    assert Job.failed?(job)
    assert job.failure_reason == "Secret aws-secrets not found"
  end

  test "when a secret sets a reserved env var => force fails the job" do
    GrpcMock.stub(Support.FakeServers.SecretsApi, :checkout_many, fn _, _ ->
      InternalApi.Secrethub.CheckoutManyResponse.new(
        secrets: [
          InternalApi.Secrethub.Secret.new(
            metadata: InternalApi.Secrethub.Secret.Metadata.new(name: "aws-secrets"),
            data:
              InternalApi.Secrethub.Secret.Data.new(
                env_vars: [
                  InternalApi.Secrethub.Secret.EnvVar.new(
                    name: "SEMAPHORE_GIT_BRANCH",
                    value: "main"
                  )
                ]
              )
          )
        ]
      )
    end)

    {:ok, task} = Support.Factories.Task.create()
    {:ok, job} = Support.Factories.Job.create(:pending, %{spec: @job_spec, build_id: task.id})

    capture_log(fn -> send(self(), {:result, Worker.process(job)}) end)
    assert_received {:result, {:ok, job}}

    assert Job.finished?(job)
    assert Job.failed?(job)

    assert job.failure_reason ==
             "Reserved environment variables cannot be set: SEMAPHORE_GIT_BRANCH (secret 'aws-secrets')"
  end

  test "when the spec overrides a platform env var => force fails the job without an OIDC token" do
    test_pid = self()

    GrpcMock.stub(Support.FakeServers.SecretsApi, :generate_open_id_connect_token, fn _, _ ->
      send(test_pid, :oidc_token_generated)
      InternalApi.Secrethub.GenerateOpenIDConnectTokenResponse.new(token: @oidc_token_value)
    end)

    spec =
      Map.update!(@job_spec, "env_vars", fn env_vars ->
        env_vars ++
          [
            %{"name" => "SEMAPHORE_WORKFLOW_TRIGGERED_BY_API", "value" => "false"},
            %{"name" => "SEMAPHORE_WORKFLOW_TRIGGERED_BY_API", "value" => "true"}
          ]
      end)

    {:ok, task} = Support.Factories.Task.create()
    {:ok, job} = Support.Factories.Job.create(:pending, %{spec: spec, build_id: task.id})

    capture_log(fn -> send(self(), {:result, Worker.process(job)}) end)
    assert_received {:result, {:ok, job}}

    assert Job.finished?(job)
    assert Job.failed?(job)

    assert job.failure_reason ==
             "Reserved environment variables cannot be set: SEMAPHORE_WORKFLOW_TRIGGERED_BY_API (job env_vars)"

    refute_received :oidc_token_generated
  end

  test "when the spec sets a reserved env var => fails before checking out secrets or minting tokens" do
    test_pid = self()

    GrpcMock.stub(Support.FakeServers.SecretsApi, :checkout_many, fn _, _ ->
      send(test_pid, :secrets_checked_out)
      InternalApi.Secrethub.CheckoutManyResponse.new(secrets: [])
    end)

    GrpcMock.stub(Support.FakeServers.ArtifactApi, :generate_token, fn _, _ ->
      send(test_pid, :artifact_token_generated)
      %InternalApi.Artifacthub.GenerateTokenResponse{token: @artifact_token}
    end)

    GrpcMock.stub(Support.FakeServers.Loghub2Api, :generate_token, fn _, _ ->
      send(test_pid, :loghub2_token_generated)

      InternalApi.Loghub2.GenerateTokenResponse.new(
        token: "very-sensitive-jwt-token",
        type: InternalApi.Loghub2.TokenType.value(:PUSH)
      )
    end)

    spec =
      Map.update!(@job_spec, "env_vars", fn env_vars ->
        env_vars ++ [%{"name" => "SEMAPHORE_GIT_BRANCH", "value" => "main"}]
      end)

    {:ok, task} = Support.Factories.Task.create()

    {:ok, job} =
      Support.Factories.Job.create(:pending, %{
        spec: spec,
        build_id: task.id,
        machine_type: "s1-test-1"
      })

    capture_log(fn -> send(self(), {:result, Worker.process(job)}) end)
    assert_received {:result, {:ok, job}}

    assert Job.finished?(job)
    assert Job.failed?(job)

    assert job.failure_reason ==
             "Reserved environment variables cannot be set: SEMAPHORE_GIT_BRANCH (job env_vars)"

    refute_received :secrets_checked_out
    refute_received :artifact_token_generated
    refute_received :loghub2_token_generated
  end

  test "when a job outside a pipeline sets a plumber-owned env var => force fails the job" do
    {:ok, job} = Support.Factories.Job.create(:pending, %{spec: @job_spec, build_id: nil})

    capture_log(fn -> send(self(), {:result, Worker.process(job)}) end)
    assert_received {:result, {:ok, job}}

    assert Job.finished?(job)
    assert Job.failed?(job)

    assert job.failure_reason ==
             "Reserved environment variables cannot be set: SEMAPHORE_WORKFLOW_TRIGGERED_BY_HOOK (job env_vars)"
  end

  test "when a debug job sets a zebra-owned env var => force fails the job" do
    {:ok, task} = Support.Factories.Task.create()
    {:ok, job} = Support.Factories.Job.create(:finished, %{spec: @job_spec, build_id: task.id})

    spec =
      Map.update!(@job_spec, "env_vars", fn env_vars ->
        env_vars ++ [%{"name" => "SEMAPHORE_GIT_BRANCH", "value" => "main"}]
      end)

    {:ok, debug_job} = Support.Factories.Job.create(:pending, %{spec: spec, build_id: nil})
    {:ok, _debug} = Support.Factories.Debug.create_for_job(job.id, debug_job.id)

    capture_log(fn -> send(self(), {:result, Worker.process(debug_job)}) end)
    assert_received {:result, {:ok, debug_job}}

    assert Job.finished?(debug_job)
    assert Job.failed?(debug_job)

    assert debug_job.failure_reason ==
             "Reserved environment variables cannot be set: SEMAPHORE_GIT_BRANCH (job env_vars)"
  end

  test "when debugging a job outside a pipeline that sets a plumber-owned env var => force fails the job" do
    {:ok, job} = Support.Factories.Job.create(:finished, %{spec: @job_spec, build_id: nil})
    {:ok, debug_job} = Support.Factories.Job.create(:pending, %{spec: @job_spec, build_id: nil})
    {:ok, _debug} = Support.Factories.Debug.create_for_job(job.id, debug_job.id)

    capture_log(fn -> send(self(), {:result, Worker.process(debug_job)}) end)
    assert_received {:result, {:ok, debug_job}}

    assert Job.finished?(debug_job)
    assert Job.failed?(debug_job)

    assert debug_job.failure_reason ==
             "Reserved environment variables cannot be set: SEMAPHORE_WORKFLOW_TRIGGERED_BY_HOOK (job env_vars)"
  end

  test "when the debugged job can't be found => applies the strict rule" do
    {:ok, debug_job} = Support.Factories.Job.create(:pending, %{spec: @job_spec, build_id: nil})
    {:ok, _debug} = Support.Factories.Debug.create_for_job(Ecto.UUID.generate(), debug_job.id)

    capture_log(fn -> send(self(), {:result, Worker.process(debug_job)}) end)
    assert_received {:result, {:ok, debug_job}}

    assert Job.failed?(debug_job)

    assert debug_job.failure_reason ==
             "Reserved environment variables cannot be set: SEMAPHORE_WORKFLOW_TRIGGERED_BY_HOOK (job env_vars)"
  end

  test "when a container with a multi-codepoint name sets a reserved env var => stores a fitting failure_reason" do
    name = "x" <> String.duplicate("\u0301", 300)

    spec =
      put_in(@job_spec_with_containers, ["agent", "containers"], [
        %{
          "name" => name,
          "image" => "ruby:2.6.1",
          "env_vars" => [%{"name" => "SEMAPHORE_JOB_ID", "value" => "x"}]
        }
      ])

    {:ok, task} = Support.Factories.Task.create()
    {:ok, job} = Support.Factories.Job.create(:pending, %{spec: spec, build_id: task.id})

    capture_log(fn -> send(self(), {:result, Worker.process(job)}) end)
    assert_received {:result, {:ok, job}}

    assert Job.failed?(job)
    assert job.failure_reason =~ "SEMAPHORE_JOB_ID (container 'x"
    assert job.failure_reason |> String.codepoints() |> length() <= 255
  end

  test "when an image pull secret sets a reserved env var => force fails the job" do
    GrpcMock.stub(Support.FakeServers.SecretsApi, :checkout_many, fn _, _ ->
      InternalApi.Secrethub.CheckoutManyResponse.new(
        secrets: [
          InternalApi.Secrethub.Secret.new(
            metadata: InternalApi.Secrethub.Secret.Metadata.new(name: "registry"),
            data:
              InternalApi.Secrethub.Secret.Data.new(
                env_vars: [
                  InternalApi.Secrethub.Secret.EnvVar.new(
                    name: "SEMAPHORE_OIDC_TOKEN",
                    value: "x"
                  )
                ]
              )
          )
        ]
      )
    end)

    spec =
      @job_spec_with_containers
      |> Map.put("secrets", [])
      |> put_in(["agent", "image_pull_secrets"], [%{"name" => "registry"}])

    {:ok, task} = Support.Factories.Task.create()
    {:ok, job} = Support.Factories.Job.create(:pending, %{spec: spec, build_id: task.id})

    capture_log(fn -> send(self(), {:result, Worker.process(job)}) end)
    assert_received {:result, {:ok, job}}

    assert Job.finished?(job)
    assert Job.failed?(job)

    assert job.failure_reason ==
             "Reserved environment variables cannot be set: SEMAPHORE_OIDC_TOKEN (image pull secret 'registry')"
  end

  test "when the spec has an env var name that is not a shell identifier => force fails the job" do
    spec =
      Map.update!(@job_spec, "env_vars", fn env_vars ->
        env_vars ++ [%{"name" => "SEMAPHORE_WORKFLOW_TRIGGERED_BY_API=true #", "value" => "x"}]
      end)

    {:ok, task} = Support.Factories.Task.create()
    {:ok, job} = Support.Factories.Job.create(:pending, %{spec: spec, build_id: task.id})

    capture_log(fn -> send(self(), {:result, Worker.process(job)}) end)
    assert_received {:result, {:ok, job}}

    assert Job.finished?(job)
    assert Job.failed?(job)

    assert job.failure_reason ==
             "Invalid environment variable names: 'SEMAPHORE_WORKFLOW_TRIGGERED_BY_API=true #' (job env_vars)"
  end

  test "when a service container uses a dotted env var name => creates job req" do
    spec =
      put_in(@job_spec_with_containers, ["agent", "containers"], [
        %{"name" => "main", "image" => "ruby:2.6.1"},
        %{
          "name" => "es",
          "image" => "elasticsearch:8.15.0",
          "env_vars" => [%{"name" => "discovery.type", "value" => "single-node"}]
        }
      ])

    {:ok, task} = Support.Factories.Task.create()
    {:ok, job} = Support.Factories.Job.create(:pending, %{spec: spec, build_id: task.id})

    {:ok, job} = Worker.process(job)

    assert job.aasm_state == "enqueued"

    [_main, es] = job.request["compose"]["containers"]
    assert Enum.any?(es["env_vars"], &(&1["name"] == "discovery.type"))
  end

  test "when a container secret sets a reserved env var => force fails the job" do
    GrpcMock.stub(Support.FakeServers.SecretsApi, :checkout_many, fn _, _ ->
      InternalApi.Secrethub.CheckoutManyResponse.new(
        secrets: [
          InternalApi.Secrethub.Secret.new(
            metadata: InternalApi.Secrethub.Secret.Metadata.new(name: "db-secrets"),
            data:
              InternalApi.Secrethub.Secret.Data.new(
                env_vars: [
                  InternalApi.Secrethub.Secret.EnvVar.new(name: "SEMAPHORE_JOB_ID", value: "x")
                ]
              )
          )
        ]
      )
    end)

    spec =
      @job_spec_with_containers
      |> Map.put("secrets", [])
      |> put_in(["agent", "containers"], [
        %{"name" => "main", "image" => "ruby:2.6.1", "secrets" => [%{"name" => "db-secrets"}]}
      ])

    {:ok, task} = Support.Factories.Task.create()
    {:ok, job} = Support.Factories.Job.create(:pending, %{spec: spec, build_id: task.id})

    capture_log(fn -> send(self(), {:result, Worker.process(job)}) end)
    assert_received {:result, {:ok, job}}

    assert Job.finished?(job)
    assert Job.failed?(job)

    assert job.failure_reason ==
             "Reserved environment variables cannot be set: SEMAPHORE_JOB_ID (secret 'db-secrets')"
  end

  describe "platform env vars injected by zebra" do
    setup do
      flagged = [
        "cache_cli_parallel_archive_method",
        "test_results_no_trim",
        "git_clone_slow_retry"
      ]

      Mox.stub(Support.MockedProvider, :provide_features, fn _, _ ->
        {:ok, features} = Support.StubbedProvider.provide_features()

        {:ok,
         Enum.map(features, fn feature ->
           if feature.type in flagged,
             do: %{feature | quantity: 1, state: :enabled},
             else: feature
         end)}
      end)

      :ok
    end

    @user_settable [
      "SEMAPHORE_CACHE_BACKEND",
      "SEMAPHORE_CACHE_URL",
      "SEMAPHORE_CACHE_USERNAME",
      "SEMAPHORE_CACHE_PRIVATE_KEY_PATH",
      "SEMAPHORE_GIT_CLONE_SLOW_RETRY",
      "SEMAPHORE_GIT_DIR",
      "SEMAPHORE_CACHE_ARCHIVE_METHOD",
      "SEMAPHORE_TOOLBOX_METRICS_ENABLED",
      "SEMAPHORE_TEST_RESULTS_NO_TRIM",
      "SEMAPHORE_CACHE_S3_BUCKET",
      "SEMAPHORE_CACHE_S3_REGION",
      "SEMAPHORE_CACHE_S3_KEY",
      "SEMAPHORE_CACHE_S3_SECRET",
      "SEMAPHORE_CACHE_S3_SESSION_TOKEN",
      "SEMAPHORE_REGISTRY_HOST",
      "SEMAPHORE_REGISTRY_URL",
      "SEMAPHORE_REGISTRY_USERNAME",
      "SEMAPHORE_REGISTRY_PASSWORD"
    ]

    for machine_type <- ["e1-standard-2", "s1-test-1"] do
      test "are all reserved or documented as user-settable on #{machine_type}" do
        {:ok, task} = Support.Factories.Task.create()

        {:ok, job} =
          Support.Factories.Job.create(:pending, %{
            spec: @job_spec,
            build_id: task.id,
            machine_type: unquote(machine_type)
          })

        {:ok, job} = Worker.process(job)
        assert job.aasm_state == "enqueued"

        user_names = Enum.map(@job_spec["env_vars"], & &1["name"])

        injected =
          job.request["env_vars"]
          |> Enum.map(& &1["name"])
          |> Enum.filter(&String.starts_with?(&1, "SEMAPHORE"))
          |> Enum.reject(&(&1 in user_names))

        assert "SEMAPHORE_OIDC_TOKEN" in injected
        assert "SEMAPHORE_TEST_RESULTS_NO_TRIM" in injected

        unreserved = Enum.reject(injected, &(EnvVarPolicy.reserved?(&1) or &1 in @user_settable))

        assert unreserved == []
      end
    end

    test "include the flag-gated hosted-only ones" do
      {:ok, task} = Support.Factories.Task.create()
      {:ok, job} = Support.Factories.Job.create(:pending, %{spec: @job_spec, build_id: task.id})

      {:ok, job} = Worker.process(job)
      names = Enum.map(job.request["env_vars"], & &1["name"])

      assert "SEMAPHORE_CACHE_ARCHIVE_METHOD" in names
      assert "SEMAPHORE_GIT_CLONE_SLOW_RETRY" in names
    end
  end

  describe "jobs of organizations on the secondary agent provider" do
    @s3_secret "s3-secret-access-key"
    @s3_session_token "s3-session-token"
    @registry_host "registry.example.com"
    @registry_password "registry-password"

    setup do
      Application.put_env(:zebra, :chmura_secondary_endpoint, "localhost:50051")
      on_exit(fn -> Application.delete_env(:zebra, :chmura_secondary_endpoint) end)

      test_pid = self()

      GrpcMock.stub(Support.FakeServers.CacheApi, :get_s3_credentials, fn req, _ ->
        send(test_pid, {:get_s3_credentials, req})
        s3_credentials_response()
      end)

      GrpcMock.stub(Support.FakeServers.RegistryApi, :get_credentials, fn req, _ ->
        send(test_pid, {:get_registry_credentials, req})
        registry_credentials_response(req.organization_id)
      end)

      :ok
    end

    test "get S3 cache and registry credentials instead of the SFTP cache" do
      enable_secondary_provider()
      job = create_pending_job(%{execution_time_limit: 60 * 60})

      {:ok, job} = Worker.process(job)
      assert job.aasm_state == "enqueued"

      names = Enum.map(job.request["env_vars"], & &1["name"])

      assert names |> Enum.drop_while(&(&1 != "SEMAPHORE_ARTIFACT_TOKEN")) |> Enum.take(12) == [
               "SEMAPHORE_ARTIFACT_TOKEN",
               "SEMAPHORE_CACHE_BACKEND",
               "SEMAPHORE_CACHE_S3_BUCKET",
               "SEMAPHORE_CACHE_S3_REGION",
               "SEMAPHORE_CACHE_S3_KEY",
               "SEMAPHORE_CACHE_S3_SECRET",
               "SEMAPHORE_CACHE_S3_SESSION_TOKEN",
               "SEMAPHORE_REGISTRY_HOST",
               "SEMAPHORE_REGISTRY_URL",
               "SEMAPHORE_REGISTRY_USERNAME",
               "SEMAPHORE_REGISTRY_PASSWORD",
               "SEMAPHORE_TOOLBOX_METRICS_ENABLED"
             ]

      assert env_value(job, "SEMAPHORE_CACHE_BACKEND") == "s3"
      assert env_value(job, "SEMAPHORE_CACHE_S3_BUCKET") == "cache-bucket"
      assert env_value(job, "SEMAPHORE_CACHE_S3_REGION") == "us-east-1"
      assert env_value(job, "SEMAPHORE_CACHE_S3_KEY") == "s3-access-key-id"
      assert env_value(job, "SEMAPHORE_CACHE_S3_SECRET") == @s3_secret
      assert env_value(job, "SEMAPHORE_CACHE_S3_SESSION_TOKEN") == @s3_session_token
      assert env_value(job, "SEMAPHORE_REGISTRY_HOST") == @registry_host

      assert env_value(job, "SEMAPHORE_REGISTRY_URL") ==
               "#{@registry_host}/orgs/#{job.organization_id}"

      assert env_value(job, "SEMAPHORE_REGISTRY_USERNAME") == "AWS"
      assert env_value(job, "SEMAPHORE_REGISTRY_PASSWORD") == @registry_password

      refute "SSH_PRIVATE_KEY_PATH" in names
      refute "SEMAPHORE_CACHE_URL" in names

      refute Enum.any?(
               job.request["files"],
               &String.ends_with?(&1["path"], "semaphore_cache_key")
             )

      assert_received {:get_s3_credentials, s3_request}
      assert s3_request.project_id == job.project_id
      assert s3_request.min_validity_seconds == 2 * 60 * 60

      assert_received {:get_registry_credentials, registry_request}
      assert registry_request.organization_id == job.organization_id
      assert registry_request.min_validity_seconds == 2 * 60 * 60
    end

    test "credentials are asked to last at most 12 hours" do
      enable_secondary_provider()
      job = create_pending_job(%{execution_time_limit: 24 * 60 * 60})

      {:ok, _job} = Worker.process(job)

      assert_received {:get_s3_credentials, %{min_validity_seconds: 43_200}}
      assert_received {:get_registry_credentials, %{min_validity_seconds: 43_200}}
    end

    test "jobs of other organizations keep the SFTP cache and get no registry" do
      job = create_pending_job()

      {:ok, job} = Worker.process(job)
      assert job.aasm_state == "enqueued"

      names = Enum.map(job.request["env_vars"], & &1["name"])

      assert env_value(job, "SEMAPHORE_CACHE_BACKEND") == "sftp"
      assert "SSH_PRIVATE_KEY_PATH" in names
      assert "SEMAPHORE_CACHE_URL" in names
      refute Enum.any?(names, &String.starts_with?(&1, "SEMAPHORE_CACHE_S3_"))
      refute Enum.any?(names, &String.starts_with?(&1, "SEMAPHORE_REGISTRY_"))

      assert Enum.any?(
               job.request["files"],
               &(&1["path"] == "/home/semaphore/.ssh/semaphore_cache_key")
             )

      refute_received {:get_s3_credentials, _}
      refute_received {:get_registry_credentials, _}
    end

    test "self-hosted jobs get neither" do
      enable_secondary_provider()
      job = create_pending_job(%{machine_type: "s1-test-1"})

      {:ok, job} = Worker.process(job)
      assert job.aasm_state == "enqueued"

      refute Enum.any?(job.request["env_vars"], &platform_cache_or_registry_var?/1)
      refute_received {:get_s3_credentials, _}
      refute_received {:get_registry_credentials, _}
    end

    test "forked pull requests get neither" do
      enable_secondary_provider()
      stub_forked_pull_request()
      job = create_pending_job()

      {:ok, job} = Worker.process(job)
      assert job.aasm_state == "enqueued"

      refute Enum.any?(job.request["env_vars"], &platform_cache_or_registry_var?/1)
      refute_received {:get_s3_credentials, _}
      refute_received {:get_registry_credentials, _}
    end

    test "a job whose secret sets a SEMAPHORE_CACHE_* variable gets none of the S3 ones" do
      enable_secondary_provider()
      stub_secret_env_vars([{"A", "B"}, {"SEMAPHORE_CACHE_S3_BUCKET", "own-bucket"}])
      job = create_pending_job()

      {:ok, job} = Worker.process(job)
      assert job.aasm_state == "enqueued"

      assert Enum.filter(
               job.request["env_vars"],
               &String.starts_with?(&1["name"], "SEMAPHORE_CACHE_")
             ) ==
               [%{"name" => "SEMAPHORE_CACHE_S3_BUCKET", "value" => Base.encode64("own-bucket")}]

      assert env_value(job, "SEMAPHORE_REGISTRY_PASSWORD") == @registry_password
    end

    test "a job whose YAML sets a SEMAPHORE_REGISTRY_* variable gets none of the registry ones" do
      enable_secondary_provider()

      spec =
        Map.update!(
          @job_spec,
          "env_vars",
          &(&1 ++ [%{"name" => "SEMAPHORE_REGISTRY_URL", "value" => "own.example.com/team"}])
        )

      job = create_pending_job(%{spec: spec})

      {:ok, job} = Worker.process(job)
      assert job.aasm_state == "enqueued"

      assert Enum.filter(
               job.request["env_vars"],
               &String.starts_with?(&1["name"], "SEMAPHORE_REGISTRY_")
             ) ==
               [
                 %{
                   "name" => "SEMAPHORE_REGISTRY_URL",
                   "value" => Base.encode64("own.example.com/team")
                 }
               ]

      assert env_value(job, "SEMAPHORE_CACHE_BACKEND") == "s3"
    end

    test "the credentials are blanked when the request is sanitized" do
      enable_secondary_provider()
      job = create_pending_job()

      {:ok, job} = Worker.process(job)
      sanitized = JobRequest.sanitize(job.request)

      for name <- [
            "SEMAPHORE_CACHE_S3_KEY",
            "SEMAPHORE_CACHE_S3_SECRET",
            "SEMAPHORE_CACHE_S3_SESSION_TOKEN",
            "SEMAPHORE_REGISTRY_PASSWORD"
          ] do
        assert raw_env_value(sanitized, name) == "{SANITIZED}"
      end

      for name <- [
            "SEMAPHORE_CACHE_BACKEND",
            "SEMAPHORE_CACHE_S3_BUCKET",
            "SEMAPHORE_CACHE_S3_REGION",
            "SEMAPHORE_REGISTRY_HOST",
            "SEMAPHORE_REGISTRY_URL",
            "SEMAPHORE_REGISTRY_USERNAME"
          ] do
        assert raw_env_value(sanitized, name) == raw_env_value(job.request, name)
      end
    end

    test "cachehub errors leave the job without the credentials, and it still runs" do
      enable_secondary_provider()

      GrpcMock.stub(Support.FakeServers.CacheApi, :get_s3_credentials, fn _, _ ->
        raise "boom"
      end)

      GrpcMock.stub(Support.FakeServers.RegistryApi, :get_credentials, fn _, _ ->
        raise "boom"
      end)

      job = create_pending_job()
      test_pid = self()

      log =
        capture_log(fn ->
          send(test_pid, {:processed, Worker.process(job)})
        end)

      assert_received {:processed, {:ok, job}}
      assert Job.enqueued?(job)
      refute Enum.any?(job.request["env_vars"], &platform_cache_or_registry_var?/1)

      assert log =~ "Cache env vars not injected into job"
      assert log =~ "Failed to fetch registry credentials from cachehub"
    end

    test "set only names that are reserved or documented as user-settable" do
      enable_secondary_provider()
      job = create_pending_job()

      {:ok, job} = Worker.process(job)

      user_names = Enum.map(@job_spec["env_vars"], & &1["name"])

      injected =
        job.request["env_vars"]
        |> Enum.map(& &1["name"])
        |> Enum.filter(&String.starts_with?(&1, "SEMAPHORE"))
        |> Enum.reject(&(&1 in user_names))

      assert "SEMAPHORE_CACHE_S3_SESSION_TOKEN" in injected
      assert "SEMAPHORE_REGISTRY_PASSWORD" in injected

      assert Enum.reject(injected, &(EnvVarPolicy.reserved?(&1) or &1 in @user_settable)) == []
    end
  end

  test "when the organization service raises an exception => doesn't process the job" do
    GrpcMock.stub(Support.FakeServers.OrganizationApi, :describe, fn _, _ ->
      raise "i refuse to return"
    end)

    {:ok, task} = Support.Factories.Task.create()
    {:ok, job} = Support.Factories.Job.create(:pending, %{spec: @job_spec, build_id: task.id})

    assert {:error, :communication_error} = Worker.process(job)

    assert job.aasm_state == "pending"
  end

  test "when the organization doesn't exist => doesn't process the job" do
    GrpcMock.stub(Support.FakeServers.OrganizationApi, :describe, fn _, _ ->
      InternalApi.Organization.DescribeResponse.new(
        status:
          InternalApi.ResponseStatus.new(
            code: InternalApi.ResponseStatus.Code.value(:BAD_PARAM),
            message: "Org not found"
          )
      )
    end)

    {:ok, task} = Support.Factories.Task.create()
    {:ok, job} = Support.Factories.Job.create(:pending, %{spec: @job_spec, build_id: task.id})

    assert {:ok, job} = Worker.process(job)

    assert Job.finished?(job)
    assert Job.failed?(job)
    assert job.failure_reason == "Organization #{Factories.Job.org_id()} not found"
  end

  test "when the artifacthub service raises an exception => doesn't process the job" do
    GrpcMock.stub(Support.FakeServers.ArtifactApi, :generate_token, fn _, _ ->
      raise "i refuse to return"
    end)

    {:ok, task} = Support.Factories.Task.create()
    {:ok, job} = Support.Factories.Job.create(:pending, %{spec: @job_spec, build_id: task.id})

    assert {:error, :communication_error} = Worker.process(job)
    assert job.aasm_state == "pending"
  end

  test "when the cache service raises an exception => ignore it" do
    GrpcMock.stub(Support.FakeServers.CacheApi, :describe, fn _, _ ->
      raise "i refuse to return"
    end)

    {:ok, task} = Support.Factories.Task.create()
    {:ok, job} = Support.Factories.Job.create(:pending, %{spec: @job_spec, build_id: task.id})

    assert {:ok, job} = Worker.process(job)

    assert Job.enqueued?(job)
  end

  test "when the cache key is invalid => don't include it" do
    GrpcMock.stub(Support.FakeServers.CacheApi, :describe, fn _, _ ->
      InternalApi.Cache.DescribeResponse.new(
        status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
        cache: InternalApi.Cache.Cache.new(credential: " ")
      )
    end)

    {:ok, task} = Support.Factories.Task.create()
    {:ok, job} = Support.Factories.Job.create(:pending, %{spec: @job_spec, build_id: task.id})

    assert {:ok, job} = Worker.process(job)

    assert Job.enqueued?(job)

    refute Enum.find(job.request["files"], fn f ->
             f["path"] == "/home/semaphore/.ssh/seamphore_cache_key"
           end)

    refute Enum.find(job.request["commands"], fn c ->
             c["directive"] == "ssh-add /home/semaphore/.ssh/semaphore_cache_key"
           end)
  end

  test "when cache env vars dropped despite project having cache_id => logs warning at factory level" do
    GrpcMock.stub(Support.FakeServers.CacheApi, :describe, fn _, _ ->
      InternalApi.Cache.DescribeResponse.new(
        status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
        cache: InternalApi.Cache.Cache.new(credential: " ")
      )
    end)

    {:ok, task} = Support.Factories.Task.create()
    {:ok, job} = Support.Factories.Job.create(:pending, %{spec: @job_spec, build_id: task.id})

    log =
      capture_log(fn ->
        assert {:ok, _job} = Worker.process(job)
      end)

    assert log =~ "Cache env vars not injected into job"
    assert log =~ job.id
    assert log =~ @cache_id
  end

  test "when we can't connect to repo_proxy api => doesn't process the job" do
    GrpcMock.stub(Support.FakeServers.RepoProxyApi, :describe, fn _, _ ->
      raise "muahhahaaha"
    end)

    {:ok, task} = Support.Factories.Task.create()
    {:ok, job} = Support.Factories.Job.create(:pending, %{spec: @job_spec, build_id: task.id})

    assert {:error, :communication_error} = Worker.process(job)

    assert job.aasm_state == "pending"
  end

  test "init uses continuous mode with parallelism fitted to the DB pool" do
    pool_size = Application.fetch_env!(:zebra, Zebra.LegacyRepo)[:pool_size]

    worker = Worker.init()

    assert %Zebra.Workers.DbWorker{
             concurrency_mode: :continuous,
             records_per_tick: 100,
             process_timeout: 15_000
           } = worker

    assert worker.parallelism ==
             Zebra.Workers.JobRequestFactory.Settings.fit_to_pool(10, pool_size)
  end

  defp enable_secondary_provider do
    Mox.stub(Support.MockedProvider, :provide_features, fn org_id, opts ->
      {:ok, features} = Support.StubbedProvider.provide_features(org_id, opts)

      {:ok,
       features ++
         [Support.StubbedProvider.feature("secondary_hosted_agent_provider", [:enabled])]}
    end)
  end

  defp create_pending_job(params \\ %{}) do
    {:ok, task} = Support.Factories.Task.create()

    {:ok, job} =
      Support.Factories.Job.create(
        :pending,
        Map.merge(%{spec: @job_spec, build_id: task.id}, params)
      )

    job
  end

  defp env_value(job, name), do: job.request |> raw_env_value(name) |> Base.decode64!()

  defp raw_env_value(request, name) do
    request["env_vars"] |> Enum.find(&(&1["name"] == name)) |> Map.fetch!("value")
  end

  defp platform_cache_or_registry_var?(%{"name" => name}) do
    String.starts_with?(name, ["SEMAPHORE_CACHE_", "SEMAPHORE_REGISTRY_"]) or
      name == "SSH_PRIVATE_KEY_PATH"
  end

  defp s3_credentials_response do
    InternalApi.Cache.GetS3CredentialsResponse.new(
      status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
      region: "us-east-1",
      bucket: "cache-bucket",
      prefix: "project-prefix",
      access_key_id: "s3-access-key-id",
      secret_access_key: @s3_secret,
      session_token: @s3_session_token
    )
  end

  defp registry_credentials_response(org_id) do
    InternalApi.Registry.GetCredentialsResponse.new(
      status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
      host: @registry_host,
      repository_prefix: "orgs/#{org_id}",
      username: "AWS",
      password: @registry_password
    )
  end

  defp stub_secret_env_vars(env_vars) do
    GrpcMock.stub(Support.FakeServers.SecretsApi, :checkout_many, fn _, _ ->
      InternalApi.Secrethub.CheckoutManyResponse.new(
        secrets: [
          InternalApi.Secrethub.Secret.new(
            metadata: InternalApi.Secrethub.Secret.Metadata.new(name: "aws-secrets"),
            data:
              InternalApi.Secrethub.Secret.Data.new(
                env_vars:
                  Enum.map(env_vars, fn {name, value} ->
                    InternalApi.Secrethub.Secret.EnvVar.new(name: name, value: value)
                  end)
              )
          )
        ]
      )
    end)
  end

  defp stub_forked_pull_request do
    GrpcMock.stub(Support.FakeServers.ProjecthubApi, :describe, fn _, _ ->
      alias InternalApi.Projecthub.ResponseMeta
      alias InternalApi.Projecthub.Project
      meta = ResponseMeta.new(status: ResponseMeta.Status.new(code: ResponseMeta.Code.value(:OK)))

      project =
        Project.new(
          metadata: Project.Metadata.new(name: "zebra"),
          spec:
            Project.Spec.new(
              repository:
                Project.Spec.Repository.new(
                  url: "git@github.com:/test-org/test-repo.git",
                  forked_pull_requests:
                    Project.Spec.Repository.ForkedPullRequests.new(
                      allowed_secrets: ["aws-secrets"]
                    )
                ),
              cache_id: @cache_id,
              artifact_store_id: Ecto.UUID.generate()
            )
        )

      InternalApi.Projecthub.DescribeResponse.new(metadata: meta, project: project)
    end)

    GrpcMock.stub(Support.FakeServers.RepoProxyApi, :describe, fn _, _ ->
      status = InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK))

      hook =
        InternalApi.RepoProxy.Hook.new(
          head_commit_sha: "8d762d04c7c753c2181030a9385b496559e5a885",
          commit_range: "123...456",
          repo_slug: "test-org/test-repo",
          git_ref: "refs/pull/1/merge",
          git_ref_type: InternalApi.RepoProxy.Hook.Type.value(:PR),
          pr_slug: "fork-org/test-repo",
          pr_name: "Change from a fork",
          pr_number: "1",
          pr_sha: "1f2e3d4c5b6a79881f2e3d4c5b6a79881f2e3d4c",
          branch_name: "master",
          pr_branch_name: "fork-branch"
        )

      %InternalApi.RepoProxy.DescribeResponse{status: status, hook: hook}
    end)
  end
end
