defmodule Support.Stubs.Project do
  alias Support.Stubs.{
    Artifacthub,
    DB,
    Time,
    UUID
  }

  @type project_stub_t :: %{
          id: Ecto.UUID.t(),
          org_id: Ecto.UUID.t(),
          name: String.t(),
          api_model: InternalApi.Projecthub.Project.t()
        }

  def init do
    DB.add_table(:projects, [:id, :name, :org_id, :api_model])
    DB.add_table(:project_members, [:project_id, :user_id])

    __MODULE__.Grpc.Projecthub.init()
  end

  def create(org, owner, params \\ []) do
    project = build(org, owner, params)

    DB.insert(:projects, %{
      id: project.metadata.id,
      name: project.metadata.name,
      org_id: org.id,
      api_model: project
    })
  end

  def switch_project_visibility(project, visibility) do
    org = %{id: project.org_id}
    owner = %{id: project.api_model.metadata.owner_id}

    alias InternalApi.Projecthub.Project.Status.State

    params = [
      id: project.id,
      name: project.name,
      state: State.value(:READY),
      visibility: visibility
    ]

    new_project = build(org, owner, params)

    DB.update(:projects, %{
      id: project.api_model.metadata.id,
      name: project.api_model.metadata.name,
      org_id: org.id,
      api_model: new_project
    })
  end

  def switch_repo_visibility(project, visibility) do
    org = %{id: project.org_id}
    owner = %{id: project.api_model.metadata.owner_id}

    params = [
      id: project.id,
      name: project.name,
      repo_visibility: visibility
    ]

    new_project = build(org, owner, params)

    DB.update(:projects, %{
      id: project.api_model.metadata.id,
      name: project.api_model.metadata.name,
      org_id: org.id,
      api_model: new_project
    })
  end

  @spec add_artifact(project_stub_t(), url: String.t(), path: String.t()) :: any()
  def add_artifact(workflow, params \\ []) do
    params = Keyword.merge(params, scope: "projects")

    Artifacthub.create(workflow.id, params)
  end

  @spec set_project_state(project_stub_t(), InternalApi.Projecthub.Project.Status.State.t()) ::
          any()
  def set_project_state(project, state) do
    onboarding_finished = state != :ONBOARDING

    DB.find(:projects, project.id)
    |> case do
      project ->
        new_project = %{
          id: project.id,
          name: project.name,
          org_id: project.org_id,
          api_model:
            InternalApi.Projecthub.Project.new(
              metadata:
                Map.merge(project.api_model.metadata, %{onboarding_finished: onboarding_finished}),
              spec: project.api_model.spec,
              status: %{
                project.api_model.status
                | state: InternalApi.Projecthub.Project.Status.State.value(state)
              }
            )
        }

        DB.update(:projects, new_project)
    end
  end

  def add_member(project_id, user_id) do
    DB.insert(:project_members, %{
      project_id: project_id,
      user_id: user_id
    })
  end

  def build(org, owner, params \\ []) do
    alias InternalApi.Projecthub.Project
    alias InternalApi.Projecthub.Project.Metadata
    alias InternalApi.Projecthub.Project.Spec
    alias InternalApi.Projecthub.Project.Spec.Repository.RunType
    alias InternalApi.Projecthub.Project.Status
    alias InternalApi.RepositoryIntegrator.IntegrationType

    defaults = [
      id: UUID.gen(),
      repo_id: UUID.gen(),
      repo_default_branch: "main",
      name: Faker.Person.first_name(),
      description: "This is the project",
      integration_type: "github_oauth_token"
    ]

    params = defaults |> Keyword.merge(params)

    meta =
      Metadata.new(
        id: params[:id],
        name: params[:name],
        owner_id: owner.id,
        org_id: org.id,
        description: params[:description],
        created_at: Time.now()
      )

    spec =
      Spec.new(
        visibility: map_visibility(params[:visibility]),
        repository:
          Spec.Repository.new(
            id: params[:repo_id],
            default_branch: params[:repo_default_branch],
            url: "git@github.com:test/test.git",
            name: "zebra",
            owner: "renderedtext",
            pipeline_file: params[:pipeline_file] || ".semaphore/semaphore.yml",
            status:
              Spec.Repository.Status.new(
                pipeline_files: [
                  Spec.Repository.Status.PipelineFile.new(
                    path: ".semaphore/semaphore.yml",
                    level: Spec.Repository.Status.PipelineFile.Level.value(:BLOCK)
                  ),
                  Spec.Repository.Status.PipelineFile.new(
                    path: ".semaphore/promotion.yml",
                    level: Spec.Repository.Status.PipelineFile.Level.value(:PIPELINE)
                  )
                ]
              ),
            whitelist:
              Spec.Repository.Whitelist.new(
                branches: params[:whitelist_branches] || [],
                tags: params[:whitelist_tags] || []
              ),
            run_on:
              Enum.map(params[:run_on] || [], fn type ->
                type
                |> String.upcase()
                |> String.to_atom()
                |> RunType.value()
              end),
            public: map_repo_visibility(params[:repo_visibility]),
            integration_type:
              params[:integration_type]
              |> String.upcase()
              |> String.to_atom()
              |> IntegrationType.value()
          )
      )

    status =
      Status.new(
        state: params[:state] || Status.State.value(:ONBOARDING),
        state_reason: params[:state_reason] || "",
        cache: Status.Cache.new(state: Status.State.value(:READY)),
        artifact_store: Status.ArtifactStore.new(state: Status.State.value(:READY)),
        repository: Status.Repository.new(state: Status.State.value(:READY)),
        permissions: Status.Permissions.new(state: Status.State.value(:READY)),
        analysis: Status.Analysis.new(state: Status.State.value(:READY))
      )

    Project.new(metadata: meta, spec: spec, status: status)
  end

  alias InternalApi.Projecthub.Project.Spec.Visibility
  defp map_visibility("public"), do: Visibility.value(:PUBLIC)
  defp map_visibility(_), do: Visibility.value(:PRIVATE)

  defp map_repo_visibility("public"), do: true
  defp map_repo_visibility(_), do: false

  defmodule Grpc do
    alias Support.Stubs.DB

    def restart do
      __MODULE__.Projecthub.init()
    end
  end

  defmodule Grpc.Projecthub do
    alias InternalApi.Projecthub.{
      DescribeManyResponse,
      DescribeResponse,
      ResponseMeta
    }

    def init do
      GrpcMock.stub(ProjecthubMock, :create, &__MODULE__.create/2)
      GrpcMock.stub(ProjecthubMock, :describe, &__MODULE__.describe/2)
      GrpcMock.stub(ProjecthubMock, :describe_many, &__MODULE__.describe_many/2)
      GrpcMock.stub(ProjecthubMock, :list, &__MODULE__.list/2)
      GrpcMock.stub(ProjecthubMock, :check_deploy_key, &__MODULE__.check_deploy_key/2)
      GrpcMock.stub(ProjecthubMock, :check_webhook, &__MODULE__.check_webhook/2)
      GrpcMock.stub(ProjecthubMock, :update, &__MODULE__.update/2)
      GrpcMock.stub(ProjecthubMock, :github_app_switch, &__MODULE__.github_app_switch/2)
      GrpcMock.stub(ProjecthubMock, :finish_onboarding, &__MODULE__.finish_onboarding/2)
      GrpcMock.stub(ProjecthubMock, :change_project_owner, &__MODULE__.change_project_owner/2)
      GrpcMock.stub(ProjecthubMock, :destroy, &__MODULE__.destroy/2)
      GrpcMock.stub(ProjecthubMock, :users, &__MODULE__.users/2)
    end

    def create(_req, _) do
      status = ResponseMeta.Status.new(code: ResponseMeta.Code.value(:OK))
      meta = ResponseMeta.new(status: status)

      project = DB.first(:projects)

      InternalApi.Projecthub.CreateResponse.new(
        metadata: meta,
        project: project.api_model
      )
    end

    def describe(req, _) do
      case find(req) do
        {:ok, project} ->
          status = ResponseMeta.Status.new(code: ResponseMeta.Code.value(:OK))
          meta = ResponseMeta.new(status: status)

          DescribeResponse.new(metadata: meta, project: project.api_model)

        {:error, nil} ->
          status = ResponseMeta.Status.new(code: ResponseMeta.Code.value(:NOT_FOUND))
          meta = ResponseMeta.new(status: status)

          DescribeResponse.new(metadata: meta)
      end
    end

    def describe_many(req, _) do
      case find_all(req.ids) do
        {:ok, projects} ->
          status = ResponseMeta.Status.new(code: ResponseMeta.Code.value(:OK))
          meta = ResponseMeta.new(status: status)

          projects =
            projects
            |> Enum.map(& &1.api_model)

          DescribeManyResponse.new(metadata: meta, projects: projects)
      end
    end

    defp filter(projects, params) do
      projects
      |> filter_by_org_id(params)
      |> filter_by_repo_url(params)
    end

    defp filter_by_org_id(projects, %{metadata: %{org_id: org_id}})
         when is_binary(org_id) and org_id != "" do
      Enum.filter(projects, fn p -> p.org_id == org_id end)
    end

    defp filter_by_org_id(projects, _), do: projects

    defp filter_by_repo_url(projects, %{repo_url: repo_url})
         when is_binary(repo_url) and repo_url != "" do
      Enum.filter(projects, fn p -> p.api_model.spec.repository.url == repo_url end)
    end

    defp filter_by_repo_url(projects, _), do: projects

    def list(req, _) do
      alias InternalApi.Projecthub.ListResponse
      alias InternalApi.Projecthub.PaginationResponse
      alias InternalApi.Projecthub.ResponseMeta

      projects = DB.all(:projects) |> filter(req) |> DB.extract(:api_model)

      status = ResponseMeta.Status.new(code: ResponseMeta.Code.value(:OK))
      meta = ResponseMeta.new(status: status)

      pagination = PaginationResponse.new(total_pages: 1, total_entries: length(projects))

      ListResponse.new(metadata: meta, projects: projects, pagination: pagination)
    end

    def check_deploy_key(_req, _) do
      InternalApi.Projecthub.CheckDeployKeyResponse.new(
        metadata: meta(code: :OK),
        deploy_key:
          InternalApi.Projecthub.CheckDeployKeyResponse.DeployKey.new(
            title: "semaphore-renderedtext-guard",
            fingerprint: "SHA256:OpCrpdiCJsjelCRPNnb0oo9EXEGbluYP9c1bUVMBUo0",
            created_at: Google.Protobuf.Timestamp.new(seconds: 1_522_495_543)
          )
      )
    end

    def check_webhook(_req, _) do
      InternalApi.Projecthub.CheckWebhookResponse.new(
        metadata: meta(code: :OK),
        webhook:
          InternalApi.Projecthub.Webhook.new(
            url: "https://semaphoreci.com/f7dbf4bd-91f0-47ab-93ee-b27d5994dcf2"
          )
      )
    end

    def update(req, _) do
      cond do
        !String.contains?(req.project.spec.repository.url, "github.com") ->
          InternalApi.Projecthub.UpdateResponse.new(
            metadata:
              meta(code: :FAILED_PRECONDITION, message: "Repository host must be GitHub.com")
          )

        req.project.metadata.name == "RaiseError" ->
          InternalApi.Projecthub.UpdateResponse.new(
            metadata: meta(code: :FAILED_PRECONDITION, message: "Failed to update.")
          )

        true ->
          project_id = req.project.metadata.id

          case DB.find(:projects, project_id) do
            nil ->
              InternalApi.Projecthub.UpdateResponse.new(
                metadata: meta(code: :NOT_FOUND),
                project: req.project
              )

            project ->
              updated_api_model =
                update_in(
                  project.api_model,
                  [Access.key(:spec), Access.key(:repository)],
                  &%{&1 | pipeline_file: req.project.spec.repository.pipeline_file}
                )

              new_project = %{project | api_model: updated_api_model}
              DB.update(:projects, new_project)

              InternalApi.Projecthub.UpdateResponse.new(
                metadata: meta(code: :OK),
                project: req.project
              )
          end
      end
    end

    def github_app_switch(_req, _) do
      InternalApi.Projecthub.GithubAppSwitchResponse.new(metadata: meta(code: :OK))
    end

    def finish_onboarding(req, _) do
      case find(req) do
        {:ok, project} ->
          new_project = %{
            id: project.id,
            name: project.name,
            org_id: project.org_id,
            api_model:
              InternalApi.Projecthub.Project.new(
                metadata: Map.merge(project.api_model.metadata, %{onboarding_finished: true}),
                spec: project.api_model.spec,
                status: %{
                  project.api_model.status
                  | state: InternalApi.Projecthub.Project.Status.State.value(:READY)
                }
              )
          }

          DB.update(:projects, new_project)
          InternalApi.Projecthub.FinishOnboardingResponse.new(metadata: meta(code: :OK))

        {:error, nil} ->
          InternalApi.Projecthub.FinishOnboardingResponse.new(
            metadata: meta(code: :FAILED_PRECONDITION, message: "Project not found.")
          )
      end
    end

    def change_project_owner(req, _) do
      case find(req) do
        {:ok, project} ->
          new_project = %{
            id: project.id,
            name: project.name,
            org_id: project.org_id,
            api_model:
              InternalApi.Projecthub.Project.new(
                metadata: Map.merge(project.api_model.metadata, %{owner_id: req.user_id}),
                spec: project.api_model.spec,
                status: project.api_model.status
              )
          }

          DB.update(:projects, new_project)

          InternalApi.Projecthub.ChangeProjectOwnerResponse.new(metadata: meta(code: :OK))

        {:error, nil} ->
          InternalApi.Projecthub.ChangeProjectOwnerResponse.new(
            metadata: meta(code: :FAILED_PRECONDITION, message: "Project not found.")
          )
      end
    end

    def destroy(req, _) do
      case find(req) do
        {:ok, project} ->
          DB.delete(:projects, project.id)

          InternalApi.Projecthub.DestroyResponse.new(metadata: meta(code: :OK))

        {:error, nil} ->
          InternalApi.Projecthub.DestroyResponse.new(
            metadata: meta(code: :FAILED_PRECONDITION, message: "Project not found.")
          )
      end
    end

    def users(req, _) do
      user_ids =
        DB.find_all_by(:project_members, :project_id, req.id)
        |> Enum.map(fn m -> m.user_id end)

      users =
        DB.find_many(:users, user_ids)
        |> Enum.map(fn u -> Support.Stubs.User.Grpc.describe_to_user(u.api_model) end)

      InternalApi.Projecthub.UsersResponse.new(
        metadata: meta(code: :OK),
        users: users
      )
    end

    defp find(%{id: project_id}) when is_binary(project_id) and project_id != "" do
      case Enum.find(DB.all(:projects), fn p -> p.id == project_id end) do
        nil ->
          {:error, nil}

        project ->
          {:ok, project}
      end
    end

    defp find(req) do
      case Enum.find(DB.all(:projects), fn p ->
             p.org_id == req.metadata.org_id && p.name == req.name
           end) do
        nil ->
          {:error, nil}

        project ->
          {:ok, project}
      end
    end

    def find_all(ids) do
      projects = DB.filter(:projects, fn project -> Enum.member?(ids, project.id) end)

      {:ok, projects}
    end

    defp meta(options) do
      alias InternalApi.Projecthub.ResponseMeta

      defaults = [
        code: :OK,
        message: ""
      ]

      options = Keyword.merge(defaults, options)

      ResponseMeta.new(
        status:
          ResponseMeta.Status.new(
            code: ResponseMeta.Code.value(options[:code]),
            message: options[:message]
          )
      )
    end
  end
end
