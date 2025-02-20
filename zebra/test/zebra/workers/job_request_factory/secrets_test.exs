# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
defmodule Zebra.Workers.JobRequestFactory.SecretsTest do
  use Zebra.DataCase

  alias Zebra.Workers.JobRequestFactory.Secrets

  @org_id Ecto.UUID.generate()
  @job_id Ecto.UUID.generate()
  @project_id Ecto.UUID.generate()
  @project InternalApi.Projecthub.Project.new(
             id: @project_id,
             forked_pull_requests:
               InternalApi.Projecthub.Project.Spec.Repository.ForkedPullRequests.new(
                 allowed_secrets: []
               )
           )
  @hook InternalApi.RepoProxy.Hook.new(
          git_ref_type: InternalApi.RepoProxy.Hook.Type.value(:BRANCH),
          hook_id: Ecto.UUID.generate(),
          user_id: Ecto.UUID.generate()
        )

  setup do
    raw_secrets = [
      InternalApi.Secrethub.Secret.new(
        metadata: InternalApi.Secrethub.Secret.Metadata.new(name: "secret-secrets"),
        data:
          InternalApi.Secrethub.Secret.Data.new(
            env_vars: [
              InternalApi.Secrethub.Secret.EnvVar.new(name: "O", value: "W"),
              InternalApi.Secrethub.Secret.EnvVar.new(name: "W", value: "W")
            ],
            files: [
              InternalApi.Secrethub.Secret.File.new(
                path: "/home/m/w",
                content: "QWxsIHlvdXIgYmFzZSBiZWxvbmcgdG8gdXMK"
              )
            ]
          ),
        org_config: InternalApi.Secrethub.Secret.OrgConfig.new()
      ),
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
          ),
        org_config: InternalApi.Secrethub.Secret.OrgConfig.new()
      ),
      InternalApi.Secrethub.Secret.new(
        metadata: InternalApi.Secrethub.Secret.Metadata.new(name: "restricted-secrets"),
        org_config:
          InternalApi.Secrethub.Secret.OrgConfig.new(
            project_access: InternalApi.Secrethub.Secret.OrgConfig.ProjectsAccess.value(:NONE),
            project_ids: []
          ),
        data:
          InternalApi.Secrethub.Secret.Data.new(
            env_vars: [
              InternalApi.Secrethub.Secret.EnvVar.new(name: "K", value: "Y"),
              InternalApi.Secrethub.Secret.EnvVar.new(name: "L", value: "M")
            ],
            files: [
              InternalApi.Secrethub.Secret.File.new(
                path: "/home/a/N",
                content: "QWxsIHlvdXIgYmFzZSBiZWxvbmcgdG8gdXMK"
              )
            ]
          )
      ),
      InternalApi.Secrethub.Secret.new(
        metadata: InternalApi.Secrethub.Secret.Metadata.new(name: "restricted-debug"),
        org_config:
          InternalApi.Secrethub.Secret.OrgConfig.new(
            project_access: InternalApi.Secrethub.Secret.OrgConfig.ProjectsAccess.value(:ALLOWED),
            project_ids: [],
            debug_access:
              InternalApi.Secrethub.Secret.OrgConfig.JobDebugAccess.value(:JOB_DEBUG_NO),
            attach_access:
              InternalApi.Secrethub.Secret.OrgConfig.JobAttachAccess.value(:JOB_ATTACH_YES)
          ),
        data:
          InternalApi.Secrethub.Secret.Data.new(
            env_vars: [
              InternalApi.Secrethub.Secret.EnvVar.new(name: "K", value: "Y"),
              InternalApi.Secrethub.Secret.EnvVar.new(name: "L", value: "M")
            ],
            files: [
              InternalApi.Secrethub.Secret.File.new(
                path: "/home/a/N",
                content: "QWxsIHlvdXIgYmFzZSBiZWxvbmcgdG8gdXMK"
              )
            ]
          )
      ),
      InternalApi.Secrethub.Secret.new(
        metadata: InternalApi.Secrethub.Secret.Metadata.new(name: "restricted-attach"),
        org_config:
          InternalApi.Secrethub.Secret.OrgConfig.new(
            project_access: InternalApi.Secrethub.Secret.OrgConfig.ProjectsAccess.value(:ALLOWED),
            project_ids: [],
            debug_access:
              InternalApi.Secrethub.Secret.OrgConfig.JobDebugAccess.value(:JOB_DEBUG_YES),
            attach_access:
              InternalApi.Secrethub.Secret.OrgConfig.JobAttachAccess.value(:JOB_ATTACH_NO)
          ),
        data:
          InternalApi.Secrethub.Secret.Data.new(
            env_vars: [
              InternalApi.Secrethub.Secret.EnvVar.new(name: "K", value: "Y"),
              InternalApi.Secrethub.Secret.EnvVar.new(name: "L", value: "M")
            ],
            files: [
              InternalApi.Secrethub.Secret.File.new(
                path: "/home/a/N",
                content: "QWxsIHlvdXIgYmFzZSBiZWxvbmcgdG8gdXMK"
              )
            ]
          )
      ),
      InternalApi.Secrethub.Secret.new(
        metadata: InternalApi.Secrethub.Secret.Metadata.new(name: "not-org-secret"),
        org_config: nil,
        data:
          InternalApi.Secrethub.Secret.Data.new(
            env_vars: [
              InternalApi.Secrethub.Secret.EnvVar.new(name: "K", value: "Y"),
              InternalApi.Secrethub.Secret.EnvVar.new(name: "L", value: "M")
            ],
            files: [
              InternalApi.Secrethub.Secret.File.new(
                path: "/home/a/N",
                content: "QWxsIHlvdXIgYmFzZSBiZWxvbmcgdG8gdXMK"
              )
            ]
          )
      )
    ]

    GrpcMock.stub(Support.FakeServers.SecretsApi, :checkout_many, fn req, _ ->
      secrets =
        raw_secrets
        |> Enum.filter(fn s -> Enum.member?(req.names, s.metadata.name) end)

      if req.checkout_metadata do
        InternalApi.Secrethub.CheckoutManyResponse.new(secrets: secrets)
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

    GrpcMock.stub(Support.FakeServers.SecretsApi, :describe_many, fn req, _ ->
      secrets =
        raw_secrets
        |> Enum.filter(fn s -> Enum.member?(req.names, s.metadata.name) end)
        # credo:disable-for-next-line Credo.Check.Refactor.FilterFilter
        |> Enum.filter(fn s ->
          if s.org_config do
            (Enum.member?(s.org_config.project_ids, req.project_id) and
               s.org_config.projects_access !=
                 InternalApi.Secrethub.Secret.OrgConfig.ProjectsAccess.value(:NONE)) or
              s.org_config.projects_access ==
                InternalApi.Secrethub.Secret.OrgConfig.ProjectsAccess.value(:ALL)
          else
            true
          end
        end)

      InternalApi.Secrethub.DescribeManyResponse.new(secrets: secrets)
    end)

    :ok
  end

  describe ".load" do
    test "when there are no requested secrets => returns empty result" do
      job_spec =
        Semaphore.Jobs.V1alpha.Job.Spec.new(
          agent:
            Semaphore.Jobs.V1alpha.Job.Spec.Agent.new(
              machine:
                Semaphore.Jobs.V1alpha.Job.Spec.Agent.Machine.new(
                  type: "e1-standard-2",
                  os_image: "ubuntu1804"
                ),
              containers: [
                Semaphore.Jobs.V1alpha.Job.Spec.Agent.Container.new(
                  name: "main",
                  image: "ruby:2.6.1"
                ),
                Semaphore.Jobs.V1alpha.Job.Spec.Agent.Container.new(
                  name: "db",
                  image: "postgres:9.6"
                )
              ],
              image_pull_secrets: []
            ),
          secrets: []
        )

      assert Secrets.load(@org_id, @job_id, job_spec, @project, @hook) ==
               {:ok,
                %Secrets{
                  job_secrets: [],
                  image_pull_secrets: [],
                  container_secrets: [[], []]
                }}
    end

    test "good checkout metadata" do
      pipeline_id = Ecto.UUID.generate()
      workflow_id = Ecto.UUID.generate()

      job_spec =
        Semaphore.Jobs.V1alpha.Job.Spec.new(
          project_id: @project_id,
          agent:
            Semaphore.Jobs.V1alpha.Job.Spec.Agent.new(
              machine:
                Semaphore.Jobs.V1alpha.Job.Spec.Agent.Machine.new(
                  type: "e1-standard-2",
                  os_image: "ubuntu1804"
                ),
              containers: [
                Semaphore.Jobs.V1alpha.Job.Spec.Agent.Container.new(
                  name: "main",
                  image: "ruby:2.6.1"
                ),
                Semaphore.Jobs.V1alpha.Job.Spec.Agent.Container.new(
                  name: "db",
                  image: "postgres:9.6"
                )
              ],
              image_pull_secrets: []
            ),
          secrets: [],
          env_vars: [
            Semaphore.Jobs.V1alpha.Job.Spec.EnvVar.new(
              name: "SEMAPHORE_PIPELINE_ID",
              value: pipeline_id
            ),
            Semaphore.Jobs.V1alpha.Job.Spec.EnvVar.new(
              name: "SEMAPHORE_WORKFLOW_ID",
              value: workflow_id
            )
          ]
        )

      # in stub we check if data is correct and raise if not ok
      GrpcMock.stub(Support.FakeServers.SecretsApi, :checkout_many, fn req, _ ->
        meta = req.checkout_metadata

        with @job_id <- meta.job_id,
             true <- meta.hook_id == @hook.hook_id,
             true <- meta.user_id == @hook.user_id,
             true <- meta.project_id == job_spec.project_id,
             ^pipeline_id <- meta.pipeline_id,
             ^workflow_id <- meta.workflow_id do
          InternalApi.Secrethub.CheckoutManyResponse.new(secrets: [])
        else
          _ ->
            raise "checkout_metadata"
        end
      end)

      assert Secrets.load(@org_id, @job_id, job_spec, @project, @hook) ==
               {:ok,
                %Secrets{
                  job_secrets: [],
                  image_pull_secrets: [],
                  container_secrets: [[], []]
                }}
    end

    test "when there are several requested secrets => fetches them from API" do
      job_spec =
        Semaphore.Jobs.V1alpha.Job.Spec.new(
          agent:
            Semaphore.Jobs.V1alpha.Job.Spec.Agent.new(
              machine:
                Semaphore.Jobs.V1alpha.Job.Spec.Agent.Machine.new(
                  type: "e1-standard-2",
                  os_image: "ubuntu1804"
                ),
              containers: [
                Semaphore.Jobs.V1alpha.Job.Spec.Agent.Container.new(
                  name: "ruby",
                  secrets: [
                    Semaphore.Jobs.V1alpha.Job.Spec.Secret.new(name: "aws-secrets")
                  ]
                )
              ],
              image_pull_secrets: [
                Semaphore.Jobs.V1alpha.Job.Spec.Secret.new(name: "aws-secrets")
              ]
            ),
          secrets: [
            Semaphore.Jobs.V1alpha.Job.Spec.Secret.new(name: "aws-secrets")
          ]
        )

      assert Secrets.load(@org_id, @job_id, job_spec, @project, @hook) ==
               {:ok,
                %Secrets{
                  container_secrets: [
                    [
                      %Zebra.Workers.JobRequestFactory.Secrets.Secret{
                        env_vars: [
                          %{"name" => "A", "value" => "Qg=="},
                          %{"name" => "T", "value" => "Qw=="}
                        ],
                        files: [
                          %{
                            "mode" => "0644",
                            "path" => "/home/a/b",
                            "content" => "QWxsIHlvdXIgYmFzZSBiZWxvbmcgdG8gdXMK"
                          }
                        ],
                        name: "aws-secrets"
                      }
                    ]
                  ],
                  image_pull_secrets: [
                    %Zebra.Workers.JobRequestFactory.Secrets.Secret{
                      env_vars: [
                        %{
                          "name" => "A",
                          "value" => "Qg=="
                        },
                        %{
                          "name" => "T",
                          "value" => "Qw=="
                        }
                      ],
                      files: [
                        %{
                          "mode" => "0644",
                          "path" => "/home/a/b",
                          "content" => "QWxsIHlvdXIgYmFzZSBiZWxvbmcgdG8gdXMK"
                        }
                      ],
                      name: "aws-secrets"
                    }
                  ],
                  job_secrets: [
                    %Zebra.Workers.JobRequestFactory.Secrets.Secret{
                      env_vars: [
                        %{
                          "name" => "A",
                          "value" => "Qg=="
                        },
                        %{
                          "name" => "T",
                          "value" => "Qw=="
                        }
                      ],
                      files: [
                        %{
                          "mode" => "0644",
                          "path" => "/home/a/b",
                          "content" => "QWxsIHlvdXIgYmFzZSBiZWxvbmcgdG8gdXMK"
                        }
                      ],
                      name: "aws-secrets"
                    }
                  ]
                }}
    end

    test "when some secrets are filtered out" do
      job_spec =
        Semaphore.Jobs.V1alpha.Job.Spec.new(
          agent:
            Semaphore.Jobs.V1alpha.Job.Spec.Agent.new(
              machine:
                Semaphore.Jobs.V1alpha.Job.Spec.Agent.Machine.new(
                  type: "e1-standard-2",
                  os_image: "ubuntu1804"
                ),
              containers: [
                Semaphore.Jobs.V1alpha.Job.Spec.Agent.Container.new(
                  name: "ruby",
                  secrets: [
                    Semaphore.Jobs.V1alpha.Job.Spec.Secret.new(name: "aws-secrets"),
                    Semaphore.Jobs.V1alpha.Job.Spec.Secret.new(name: "secret-secrets")
                  ]
                )
              ],
              image_pull_secrets: [
                Semaphore.Jobs.V1alpha.Job.Spec.Secret.new(name: "aws-secrets"),
                Semaphore.Jobs.V1alpha.Job.Spec.Secret.new(name: "secret-secrets")
              ]
            ),
          secrets: [
            Semaphore.Jobs.V1alpha.Job.Spec.Secret.new(name: "aws-secrets"),
            Semaphore.Jobs.V1alpha.Job.Spec.Secret.new(name: "secret-secrets")
          ]
        )

      hook =
        InternalApi.RepoProxy.Hook.new(
          git_ref_type: InternalApi.RepoProxy.Hook.Type.value(:PR),
          pr_slug: "foo/bar",
          repo_slug: "bar/bar"
        )

      api_project =
        InternalApi.Projecthub.Project.new(
          metadata: InternalApi.Projecthub.Project.Metadata.new(),
          spec:
            InternalApi.Projecthub.Project.Spec.new(
              repository:
                InternalApi.Projecthub.Project.Spec.Repository.new(
                  forked_pull_requests:
                    InternalApi.Projecthub.Project.Spec.Repository.ForkedPullRequests.new(
                      allowed_secrets: ["secret-secrets"]
                    )
                )
            )
        )

      project = Zebra.Models.Project.from_api(api_project)

      assert Secrets.load(@org_id, @job_id, job_spec, project, hook) ==
               {:ok,
                %Secrets{
                  container_secrets: [
                    [
                      %Zebra.Workers.JobRequestFactory.Secrets.Secret{
                        env_vars: [
                          %{"name" => "O", "value" => "Vw=="},
                          %{"name" => "W", "value" => "Vw=="}
                        ],
                        files: [
                          %{
                            "mode" => "0644",
                            "path" => "/home/m/w",
                            "content" => "QWxsIHlvdXIgYmFzZSBiZWxvbmcgdG8gdXMK"
                          }
                        ],
                        name: "secret-secrets"
                      }
                    ]
                  ],
                  image_pull_secrets: [
                    %Zebra.Workers.JobRequestFactory.Secrets.Secret{
                      env_vars: [
                        %{
                          "name" => "O",
                          "value" => "Vw=="
                        },
                        %{
                          "name" => "W",
                          "value" => "Vw=="
                        }
                      ],
                      files: [
                        %{
                          "mode" => "0644",
                          "path" => "/home/m/w",
                          "content" => "QWxsIHlvdXIgYmFzZSBiZWxvbmcgdG8gdXMK"
                        }
                      ],
                      name: "secret-secrets"
                    }
                  ],
                  job_secrets: [
                    %Zebra.Workers.JobRequestFactory.Secrets.Secret{
                      env_vars: [
                        %{
                          "name" => "O",
                          "value" => "Vw=="
                        },
                        %{
                          "name" => "W",
                          "value" => "Vw=="
                        }
                      ],
                      files: [
                        %{
                          "mode" => "0644",
                          "path" => "/home/m/w",
                          "content" => "QWxsIHlvdXIgYmFzZSBiZWxvbmcgdG8gdXMK"
                        }
                      ],
                      name: "secret-secrets"
                    }
                  ]
                }}
    end

    test "when all secrets are filtered out" do
      job_spec =
        Semaphore.Jobs.V1alpha.Job.Spec.new(
          agent:
            Semaphore.Jobs.V1alpha.Job.Spec.Agent.new(
              machine:
                Semaphore.Jobs.V1alpha.Job.Spec.Agent.Machine.new(
                  type: "e1-standard-2",
                  os_image: "ubuntu1804"
                ),
              containers: [
                Semaphore.Jobs.V1alpha.Job.Spec.Agent.Container.new(
                  name: "ruby",
                  secrets: [
                    Semaphore.Jobs.V1alpha.Job.Spec.Secret.new(name: "aws-secrets"),
                    Semaphore.Jobs.V1alpha.Job.Spec.Secret.new(name: "secret-secrets")
                  ]
                )
              ],
              image_pull_secrets: [
                Semaphore.Jobs.V1alpha.Job.Spec.Secret.new(name: "aws-secrets"),
                Semaphore.Jobs.V1alpha.Job.Spec.Secret.new(name: "secret-secrets")
              ]
            ),
          secrets: [
            Semaphore.Jobs.V1alpha.Job.Spec.Secret.new(name: "aws-secrets"),
            Semaphore.Jobs.V1alpha.Job.Spec.Secret.new(name: "secret-secrets")
          ]
        )

      hook =
        InternalApi.RepoProxy.Hook.new(
          git_ref_type: InternalApi.RepoProxy.Hook.Type.value(:PR),
          pr_slug: "foo/bar",
          repo_slug: "bar/bar"
        )

      api_project =
        InternalApi.Projecthub.Project.new(
          metadata: InternalApi.Projecthub.Project.Metadata.new(),
          spec:
            InternalApi.Projecthub.Project.Spec.new(
              repository:
                InternalApi.Projecthub.Project.Spec.Repository.new(
                  forked_pull_requests:
                    InternalApi.Projecthub.Project.Spec.Repository.ForkedPullRequests.new(
                      allowed_secrets: []
                    )
                )
            )
        )

      project = Zebra.Models.Project.from_api(api_project)

      assert Secrets.load(@org_id, @job_id, job_spec, project, hook) ==
               {:ok,
                %Secrets{
                  container_secrets: [[]],
                  image_pull_secrets: [],
                  job_secrets: []
                }}
    end

    test "when secrets are not found" do
      job_spec =
        Semaphore.Jobs.V1alpha.Job.Spec.new(
          agent:
            Semaphore.Jobs.V1alpha.Job.Spec.Agent.new(
              machine:
                Semaphore.Jobs.V1alpha.Job.Spec.Agent.Machine.new(
                  type: "e1-standard-2",
                  os_image: "ubuntu1804"
                ),
              containers: [
                Semaphore.Jobs.V1alpha.Job.Spec.Agent.Container.new(
                  name: "ruby",
                  secrets: [
                    Semaphore.Jobs.V1alpha.Job.Spec.Secret.new(name: "non-existent")
                  ]
                )
              ],
              image_pull_secrets: [
                Semaphore.Jobs.V1alpha.Job.Spec.Secret.new(name: "non-existent")
              ]
            ),
          secrets: [
            Semaphore.Jobs.V1alpha.Job.Spec.Secret.new(name: "non-existent")
          ]
        )

      assert Secrets.load(@org_id, @job_id, job_spec, @project, @hook) == {
               :stop_job_processing,
               "Secret non-existent not found"
             }
    end
  end

  describe ".can_use_secret?" do
    test "when there are no secrets used in job => returns true" do
      job_spec =
        Semaphore.Jobs.V1alpha.Job.Spec.new(
          agent:
            Semaphore.Jobs.V1alpha.Job.Spec.Agent.new(
              machine:
                Semaphore.Jobs.V1alpha.Job.Spec.Agent.Machine.new(
                  type: "e1-standard-2",
                  os_image: "ubuntu1804"
                ),
              containers: [
                Semaphore.Jobs.V1alpha.Job.Spec.Agent.Container.new(
                  name: "main",
                  image: "ruby:2.6.1"
                ),
                Semaphore.Jobs.V1alpha.Job.Spec.Agent.Container.new(
                  name: "db",
                  image: "postgres:9.6"
                )
              ],
              image_pull_secrets: []
            ),
          secrets: []
        )

      assert Secrets.validate_job_secrets(@org_id, job_spec, :debug) == {:ok, true}
    end

    test "when some secrets are not available to load" do
      job_spec =
        Semaphore.Jobs.V1alpha.Job.Spec.new(
          project_id: @project_id,
          secrets: [
            Semaphore.Jobs.V1alpha.Job.Spec.Secret.new(name: "non-existent"),
            Semaphore.Jobs.V1alpha.Job.Spec.Secret.new(name: "aws-secrets")
          ]
        )

      assert Secrets.validate_job_secrets(@org_id, job_spec, :debug) == {
               :ok,
               false
             }
    end

    test "try attach when secret can debug but can't attach => false" do
      job_spec =
        Semaphore.Jobs.V1alpha.Job.Spec.new(
          project_id: @project_id,
          secrets: [
            Semaphore.Jobs.V1alpha.Job.Spec.Secret.new(name: "restricted-attach"),
            Semaphore.Jobs.V1alpha.Job.Spec.Secret.new(name: "aws-secrets")
          ]
        )

      assert Secrets.validate_job_secrets(@org_id, job_spec, :attach) == {
               :ok,
               false
             }
    end

    test "try attach when secret can't debug but can attach => true" do
      job_spec =
        Semaphore.Jobs.V1alpha.Job.Spec.new(
          project_id: @project_id,
          secrets: [
            Semaphore.Jobs.V1alpha.Job.Spec.Secret.new(name: "restricted-debug"),
            Semaphore.Jobs.V1alpha.Job.Spec.Secret.new(name: "aws-secrets")
          ]
        )

      assert Secrets.validate_job_secrets(@org_id, job_spec, :attach) == {
               :ok,
               true
             }
    end

    test "try debug when secret can't debug but can attach => false" do
      job_spec =
        Semaphore.Jobs.V1alpha.Job.Spec.new(
          project_id: @project_id,
          secrets: [
            Semaphore.Jobs.V1alpha.Job.Spec.Secret.new(name: "restricted-debug"),
            Semaphore.Jobs.V1alpha.Job.Spec.Secret.new(name: "aws-secrets")
          ]
        )

      assert Secrets.validate_job_secrets(@org_id, job_spec, :debug) == {
               :ok,
               false
             }
    end

    test "try debug when secret can debug but can't attach => true" do
      job_spec =
        Semaphore.Jobs.V1alpha.Job.Spec.new(
          project_id: @project_id,
          secrets: [
            Semaphore.Jobs.V1alpha.Job.Spec.Secret.new(name: "restricted-attach"),
            Semaphore.Jobs.V1alpha.Job.Spec.Secret.new(name: "aws-secrets")
          ]
        )

      assert Secrets.validate_job_secrets(@org_id, job_spec, :debug) == {
               :ok,
               true
             }
    end

    test "when not org-secret => true" do
      job_spec =
        Semaphore.Jobs.V1alpha.Job.Spec.new(
          project_id: @project_id,
          secrets: [
            Semaphore.Jobs.V1alpha.Job.Spec.Secret.new(name: "not-org-secret"),
            Semaphore.Jobs.V1alpha.Job.Spec.Secret.new(name: "aws-secrets")
          ]
        )

      assert Secrets.validate_job_secrets(@org_id, job_spec, :attach) == {
               :ok,
               true
             }
    end

    test "when all secrets are ok" do
      job_spec =
        Semaphore.Jobs.V1alpha.Job.Spec.new(
          project_id: @project_id,
          secrets: [
            Semaphore.Jobs.V1alpha.Job.Spec.Secret.new(name: "secret-secrets"),
            Semaphore.Jobs.V1alpha.Job.Spec.Secret.new(name: "aws-secrets")
          ]
        )

      assert Secrets.validate_job_secrets(@org_id, job_spec, :attach) == {
               :ok,
               true
             }
    end
  end
end
