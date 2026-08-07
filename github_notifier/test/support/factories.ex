defmodule Support.Factories do
  def organization_describe_response do
    struct(InternalApi.Organization.DescribeResponse,
      status: Support.Factories.status_ok(),
      organization:
        struct(InternalApi.Organization.Organization,
          org_username: "renderedtext",
          org_id: "123"
        )
    )
  end

  def user_describe_response do
    struct(InternalApi.User.DescribeResponse,
      status: Support.Factories.status_ok(),
      user_id: "78114608-be8a-465a-b9cd-81970fb802c5",
      github_token: "github_token"
    )
  end

  def project_describe_response(level \\ :BLOCK) do
    alias InternalApi.Projecthub.Project.Spec.Repository

    struct(InternalApi.Projecthub.DescribeResponse,
      metadata:
        struct(InternalApi.Projecthub.ResponseMeta,
          status:
            struct(InternalApi.Projecthub.ResponseMeta.Status,
              code: :OK
            )
        ),
      project:
        struct(InternalApi.Projecthub.Project,
          metadata:
            struct(InternalApi.Projecthub.Project.Metadata,
              owner_id: "123",
              org_id: "123"
            ),
          spec:
            struct(InternalApi.Projecthub.Project.Spec,
              repository:
                struct(Repository,
                  id: "ee2e6241-f30b-4892-a0d5-bd900b713430",
                  url: "git@github.com:renderedtext/github_notifier.git",
                  status:
                    struct(Repository.Status,
                      pipeline_files: [
                        struct(Repository.Status.PipelineFile,
                          path: ".semaphore/semaphore.yml",
                          level: Repository.Status.PipelineFile.Level.value(level)
                        )
                      ]
                    )
                )
            )
        )
    )
  end

  def project_empty_status_describe_response do
    alias InternalApi.Projecthub.Project.Spec.Repository

    struct(InternalApi.Projecthub.DescribeResponse,
      metadata:
        struct(InternalApi.Projecthub.ResponseMeta,
          status:
            struct(InternalApi.Projecthub.ResponseMeta.Status,
              code: :OK
            )
        ),
      project:
        struct(InternalApi.Projecthub.Project,
          metadata:
            struct(InternalApi.Projecthub.Project.Metadata,
              owner_id: "123",
              org_id: "123"
            ),
          spec:
            struct(InternalApi.Projecthub.Project.Spec,
              repository:
                struct(Repository,
                  id: "ee2e6241-f30b-4892-a0d5-bd900b713430",
                  url: "git@github.com:renderedtext/github_notifier.git"
                )
            )
        )
    )
  end

  def pipeline_describe_response(
        opts \\ [],
        working_directory \\ ".semaphore",
        yaml_file_name \\ "semaphore.yml"
      ) do
    code = Keyword.get(opts, :code, :ok)

    if code == :ok do
      struct(InternalApi.Plumber.DescribeResponse,
        response_status:
          struct(InternalApi.Plumber.ResponseStatus,
            code: :OK
          ),
        pipeline:
          struct(InternalApi.Plumber.Pipeline,
            ppl_id: "1",
            project_id: "1",
            name: "Pipeline",
            branch_id: "2",
            hook_id: "3",
            branch_name: "master",
            commit_sha: "1234567",
            state: :RUNNING,
            created_at: %Google.Protobuf.Timestamp{nanos: 0, seconds: 0},
            pending_at: %Google.Protobuf.Timestamp{nanos: 0, seconds: 0},
            queuing_at: %Google.Protobuf.Timestamp{nanos: 0, seconds: 0},
            running_at: %Google.Protobuf.Timestamp{nanos: 0, seconds: 0},
            stopping_at: %Google.Protobuf.Timestamp{nanos: 0, seconds: 0},
            done_at: %Google.Protobuf.Timestamp{nanos: 0, seconds: 0},
            wf_id: "3",
            yaml_file_name: yaml_file_name,
            working_directory: working_directory
          ),
        blocks: [
          struct(InternalApi.Plumber.Block,
            block_id: "1",
            name: "Block 1",
            build_req_id: "1",
            state: :RUNNING
          ),
          struct(InternalApi.Plumber.Block,
            block_id: "2",
            name: "Block 2",
            build_req_id: "1",
            state: :RUNNING
          ),
          struct(InternalApi.Plumber.Block,
            block_id: "3",
            name: "Block 3",
            build_req_id: "1",
            state: :RUNNING
          )
        ]
      )
    else
      struct(InternalApi.Plumber.DescribeResponse,
        response_status:
          struct(InternalApi.Plumber.ResponseStatus,
            code: :BAD_PARAM
          )
      )
    end
  end

  def status_ok do
    struct(InternalApi.ResponseStatus, code: :OK)
  end

  def status_not_ok(message \\ "") do
    struct(InternalApi.ResponseStatus,
      code: :BAD_PARAM,
      message: message
    )
  end

  def project(meta \\ []) do
    alias InternalApi.Projecthub.Project.Spec.Repository

    meta_def = [
      id: "ee2e6241-f30b-4892-a0d5-bd900b713430",
      name: "renderedtext",
      owner_id: "78114608-be8a-465a-b9cd-81970fb802c7"
    ]

    meta = struct(InternalApi.Projecthub.Project.Metadata, Keyword.merge(meta_def, meta))

    spec =
      %{
        repository:
          struct(Repository,
            id: "ee2e6241-f30b-4892-a0d5-bd900b713430",
            url: "",
            integration_type: :GITHUB_OAUTH_TOKEN,
            status:
              struct(Repository.Status,
                pipeline_files: [
                  struct(Repository.Status.PipelineFile,
                    path: ".semaphore/semaphore.yml",
                    level: :PIPELINE
                  )
                ]
              )
          )
      }
      |> then(&struct(InternalApi.Projecthub.Project.Spec, &1))

    struct(InternalApi.Projecthub.Project, metadata: meta, spec: spec)
  end

  def response_meta(code \\ :OK) do
    struct(InternalApi.Projecthub.ResponseMeta,
      status:
        struct(InternalApi.Projecthub.ResponseMeta.Status,
          code: InternalApi.Projecthub.ResponseMeta.Code.value(code)
        )
    )
  end

  def repo_proxy_describe_response do
    struct(InternalApi.RepoProxy.DescribeResponse,
      status: Support.Factories.status_ok(),
      hook:
        struct(InternalApi.RepoProxy.Hook,
          hook_id: "",
          head_commit_sha: "1234567",
          commit_message: "Merge pull request",
          repo_host_url: "https://github.com/rt/launchpad",
          repo_host_username: "bmarkons",
          repo_host_email: "mbogd@rt.com",
          repo_host_avatar_url: "github.com/avatar",
          user_id: "9149bf8e-1cf7-499d-96f4-efd77a96a06d",
          semaphore_email: "mbogd@rt.com",
          repo_slug: "",
          git_ref: "",
          git_ref_type: :BRANCH,
          pr_slug: "",
          pr_name: "",
          pr_number: "",
          pr_sha: "1234568",
          tag_name: "",
          branch_name: ""
        )
    )
  end

  def repo_integrator_get_token_response do
    struct(InternalApi.RepositoryIntegrator.GetTokenResponse, token: "token")
  end

  def feature_list_response(availability \\ :HIDDEN) do
    quantity = if availability == :HIDDEN, do: 0, else: 1

    struct(InternalApi.Feature.ListOrganizationFeaturesResponse,
      organization_features: [
        struct(InternalApi.Feature.OrganizationFeature,
          feature:
            struct(InternalApi.Feature.Feature,
              type: "github_merge_queues",
              name: "Github Merge Queues",
              availability:
                struct(InternalApi.Feature.Availability,
                  state: InternalApi.Feature.Availability.State.value(availability),
                  quantity: quantity
                )
            ),
          availability:
            struct(InternalApi.Feature.Availability,
              state: InternalApi.Feature.Availability.State.value(availability),
              quantity: quantity
            )
        )
      ]
    )
  end
end
