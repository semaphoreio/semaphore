defmodule Support.Factories do
  def organization_describe_response do
    InternalApi.Organization.DescribeResponse.new(
      status: Support.Factories.status_ok(),
      organization:
        InternalApi.Organization.Organization.new(
          org_username: "renderedtext",
          org_id: "123"
        )
    )
  end

  def user_describe_response do
    InternalApi.User.DescribeResponse.new(
      status: Support.Factories.status_ok(),
      user_id: "78114608-be8a-465a-b9cd-81970fb802c5",
      github_token: "github_token"
    )
  end

  def project_describe_response(level \\ :BLOCK) do
    alias InternalApi.Projecthub.Project.Spec.Repository

    InternalApi.Projecthub.DescribeResponse.new(
      metadata:
        InternalApi.Projecthub.ResponseMeta.new(
          status:
            InternalApi.Projecthub.ResponseMeta.Status.new(
              code: InternalApi.Projecthub.ResponseMeta.Code.value(:OK)
            )
        ),
      project:
        InternalApi.Projecthub.Project.new(
          metadata:
            InternalApi.Projecthub.Project.Metadata.new(
              owner_id: "123",
              org_id: "123"
            ),
          spec:
            InternalApi.Projecthub.Project.Spec.new(
              repository:
                Repository.new(
                  id: "ee2e6241-f30b-4892-a0d5-bd900b713430",
                  url: "git@github.com:renderedtext/github_notifier.git",
                  status:
                    Repository.Status.new(
                      pipeline_files: [
                        Repository.Status.PipelineFile.new(
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

    InternalApi.Projecthub.DescribeResponse.new(
      metadata:
        InternalApi.Projecthub.ResponseMeta.new(
          status:
            InternalApi.Projecthub.ResponseMeta.Status.new(
              code: InternalApi.Projecthub.ResponseMeta.Code.value(:OK)
            )
        ),
      project:
        InternalApi.Projecthub.Project.new(
          metadata:
            InternalApi.Projecthub.Project.Metadata.new(
              owner_id: "123",
              org_id: "123"
            ),
          spec:
            InternalApi.Projecthub.Project.Spec.new(
              repository:
                Repository.new(
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
      InternalApi.Plumber.DescribeResponse.new(
        response_status:
          InternalApi.Plumber.ResponseStatus.new(
            code: InternalApi.Plumber.ResponseStatus.ResponseCode.value(:OK)
          ),
        pipeline:
          InternalApi.Plumber.Pipeline.new(
            ppl_id: "1",
            project_id: "1",
            name: "Pipeline",
            branch_id: "2",
            hook_id: "3",
            branch_name: "master",
            commit_sha: "1234567",
            state: InternalApi.Plumber.Pipeline.State.value(:RUNNING),
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
          InternalApi.Plumber.Block.new(
            block_id: "1",
            name: "Block 1",
            build_req_id: "1",
            state: InternalApi.Plumber.Block.State.value(:RUNNING)
          ),
          InternalApi.Plumber.Block.new(
            block_id: "2",
            name: "Block 2",
            build_req_id: "1",
            state: InternalApi.Plumber.Block.State.value(:RUNNING)
          ),
          InternalApi.Plumber.Block.new(
            block_id: "3",
            name: "Block 3",
            build_req_id: "1",
            state: InternalApi.Plumber.Block.State.value(:RUNNING)
          )
        ]
      )
    else
      InternalApi.Plumber.DescribeResponse.new(
        response_status:
          InternalApi.Plumber.ResponseStatus.new(
            code: InternalApi.Plumber.ResponseStatus.ResponseCode.value(:BAD_PARAM)
          )
      )
    end
  end

  def status_ok do
    InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK))
  end

  def status_not_ok(message \\ "") do
    InternalApi.ResponseStatus.new(
      code: InternalApi.ResponseStatus.Code.value(:BAD_PARAM),
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

    meta = Keyword.merge(meta_def, meta) |> InternalApi.Projecthub.Project.Metadata.new()

    spec =
      %{
        repository:
          Repository.new(
            id: "ee2e6241-f30b-4892-a0d5-bd900b713430",
            url: "",
            integration_type:
              InternalApi.RepositoryIntegrator.IntegrationType.value(:GITHUB_OAUTH_TOKEN),
            status:
              Repository.Status.new(
                pipeline_files: [
                  Repository.Status.PipelineFile.new(
                    path: ".semaphore/semaphore.yml",
                    level: Repository.Status.PipelineFile.Level.value(:PIPELINE)
                  )
                ]
              )
          )
      }
      |> InternalApi.Projecthub.Project.Spec.new()

    InternalApi.Projecthub.Project.new(metadata: meta, spec: spec)
  end

  def response_meta(code \\ :OK) do
    InternalApi.Projecthub.ResponseMeta.new(
      status:
        InternalApi.Projecthub.ResponseMeta.Status.new(
          code: InternalApi.Projecthub.ResponseMeta.Code.value(code)
        )
    )
  end

  def repo_proxy_describe_response do
    InternalApi.RepoProxy.DescribeResponse.new(
      status: Support.Factories.status_ok(),
      hook:
        InternalApi.RepoProxy.Hook.new(
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
          git_ref_type: InternalApi.RepoProxy.Hook.Type.value(:BRANCH),
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
    InternalApi.RepositoryIntegrator.GetTokenResponse.new(token: "token")
  end

  def feature_list_response(availability \\ :HIDDEN) do
    quantity = if availability == :HIDDEN, do: 0, else: 1

    InternalApi.Feature.ListOrganizationFeaturesResponse.new(
      organization_features: [
        InternalApi.Feature.OrganizationFeature.new(
          feature:
            InternalApi.Feature.Feature.new(
              type: "github_merge_queues",
              name: "Github Merge Queues",
              availability:
                InternalApi.Feature.Availability.new(
                  state: InternalApi.Feature.Availability.State.value(availability),
                  quantity: quantity
                )
            ),
          availability:
            InternalApi.Feature.Availability.new(
              state: InternalApi.Feature.Availability.State.value(availability),
              quantity: quantity
            )
        )
      ]
    )
  end
end
