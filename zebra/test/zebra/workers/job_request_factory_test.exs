defmodule Zebra.Workers.JobRequestFactoryTest do
  alias Support.Factories
  use Zebra.DataCase

  alias Zebra.Models.Job
  alias Zebra.Workers.JobRequestFactory, as: Worker

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

  test "when we can't connect to repo_proxy api => doesn't process the job" do
    GrpcMock.stub(Support.FakeServers.RepoProxyApi, :describe, fn _, _ ->
      raise "muahhahaaha"
    end)

    {:ok, task} = Support.Factories.Task.create()
    {:ok, job} = Support.Factories.Job.create(:pending, %{spec: @job_spec, build_id: task.id})

    assert {:error, :communication_error} = Worker.process(job)

    assert job.aasm_state == "pending"
  end
end
