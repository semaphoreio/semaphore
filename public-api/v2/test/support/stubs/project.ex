defmodule Support.Stubs.Project do
  #
  # TODO: This stub is not complete. Some values are still hardcoded. DO NOT COPY.
  #
  # Hardcoding id values and API responses does not scale well. The more tests
  # we add that really on hardcoding, the harder it will become to untangle
  # the tests in the future.
  #

  alias Support.Stubs.{DB, Time, UUID, Artifacthub}

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

    params = [
      id: project.id,
      name: project.name,
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

  def add_artifact(workflow, params \\ []) do
    params = Keyword.merge(params, scope: "projects")

    Artifacthub.create(workflow.id, params)
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
    alias InternalApi.Projecthub.Project.Status
    alias InternalApi.RepositoryIntegrator.IntegrationType
    alias InternalApi.Projecthub.Project.Spec.Repository.RunType

    defaults = [
      id: UUID.gen(),
      repo_id: UUID.gen(),
      repo_default_branch: "main",
      name: Faker.Person.last_name() |> String.replace("'", "") |> String.downcase(),
      description: "This is the project",
      integration_type: "github_oauth_token"
    ]

    params = defaults |> Keyword.merge(params)

    meta = %Metadata{
      id: params[:id],
      name: params[:name],
      owner_id: owner.id,
      org_id: org.id,
      description: params[:description],
      created_at: Time.now()
    }

    spec = %Spec{
      visibility: map_visibility(params[:visibility]),
      repository: %Spec.Repository{
        id: params[:repo_id],
        default_branch: params[:repo_default_branch],
        url: "git@github.com:test/test.git",
        name: "zebra",
        owner: "renderedtext",
        pipeline_file: ".semaphore/semaphore.yml",
        status: %Spec.Repository.Status{
          pipeline_files: [
            %Spec.Repository.Status.PipelineFile{
              path: ".semaphore/semaphore.yml",
              level: Spec.Repository.Status.PipelineFile.Level.value(:BLOCK)
            },
            %Spec.Repository.Status.PipelineFile{
              path: ".semaphore/promotion.yml",
              level: Spec.Repository.Status.PipelineFile.Level.value(:PIPELINE)
            }
          ]
        },
        whitelist: %Spec.Repository.Whitelist{
          branches: params[:whitelist_branches] || [],
          tags: params[:whitelist_tags] || []
        },
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
      }
    }

    status = %Status{
      state: params[:state] || Status.State.value(:READY),
      state_reason: params[:state_reason] || "",
      cache: %Status.Cache{state: Status.State.value(:READY)},
      artifact_store: %Status.ArtifactStore{state: Status.State.value(:READY)},
      repository: %Status.Repository{state: Status.State.value(:READY)},
      analysis: %Status.Analysis{state: Status.State.value(:READY)}
    }

    %Project{metadata: meta, spec: spec, status: status}
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
    alias InternalApi.Projecthub.{DescribeResponse, DescribeManyResponse, ResponseMeta}

    def init do
      GrpcMock.stub(ProjecthubMock, :create, &__MODULE__.create/2)
      GrpcMock.stub(ProjecthubMock, :describe, &__MODULE__.describe/2)
      GrpcMock.stub(ProjecthubMock, :describe_many, &__MODULE__.describe_many/2)
      GrpcMock.stub(ProjecthubMock, :list, &__MODULE__.list/2)
      GrpcMock.stub(ProjecthubMock, :list_keyset, &__MODULE__.list_keyset/2)
      GrpcMock.stub(ProjecthubMock, :check_deploy_key, &__MODULE__.check_deploy_key/2)
      GrpcMock.stub(ProjecthubMock, :check_webhook, &__MODULE__.check_webhook/2)
      GrpcMock.stub(ProjecthubMock, :update, &__MODULE__.update/2)
      GrpcMock.stub(ProjecthubMock, :github_app_switch, &__MODULE__.github_app_switch/2)
      GrpcMock.stub(ProjecthubMock, :change_project_owner, &__MODULE__.change_project_owner/2)
      GrpcMock.stub(ProjecthubMock, :destroy, &__MODULE__.destroy/2)
      GrpcMock.stub(ProjecthubMock, :users, &__MODULE__.users/2)
    end

    def create(req, _) do
      status = %ResponseMeta.Status{code: ResponseMeta.Code.value(:OK)}
      meta = %ResponseMeta{status: status}
      id = UUID.gen()

      project =
        DB.insert(:projects, %{
          id: id,
          name: req.project.metadata.name,
          org_id: req.metadata.org_id,
          api_model: req.project
        })

      %InternalApi.Projecthub.CreateResponse{
        metadata: meta,
        project: project.api_model
      }
    end

    def describe(req, _) do
      case find(req) do
        {:ok, project} ->
          status = %ResponseMeta.Status{code: ResponseMeta.Code.value(:OK)}
          meta = %ResponseMeta{status: status}

          %DescribeResponse{metadata: meta, project: project.api_model}

        {:error, nil} ->
          status = %ResponseMeta.Status{code: ResponseMeta.Code.value(:NOT_FOUND)}
          meta = %ResponseMeta{status: status}

          %DescribeResponse{metadata: meta}
      end
    end

    def describe_many(req, _) do
      case find_all(req.ids) do
        {:ok, projects} ->
          status = %ResponseMeta.Status{code: ResponseMeta.Code.value(:OK)}
          meta = %ResponseMeta{status: status}

          projects =
            projects
            |> Enum.map(& &1.api_model)

          %DescribeManyResponse{metadata: meta, projects: projects}
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

      status = %ResponseMeta.Status{code: ResponseMeta.Code.value(:OK)}
      meta = %ResponseMeta{status: status}

      pagination = %PaginationResponse{total_pages: 1, total_entries: length(projects)}

      %ListResponse{metadata: meta, projects: projects, pagination: pagination}
    end

    def list_keyset(req, _) do
      alias InternalApi.Projecthub.ListKeysetResponse
      alias InternalApi.Projecthub.ResponseMeta

      projects = DB.all(:projects) |> filter(req) |> DB.extract(:api_model)

      status = %ResponseMeta.Status{code: ResponseMeta.Code.value(:OK)}
      meta = %ResponseMeta{status: status}

      %ListKeysetResponse{
        metadata: meta,
        projects: projects,
        next_page_token: "next",
        previous_page_token: "prev"
      }
    end

    def check_deploy_key(_req, _) do
      %InternalApi.Projecthub.CheckDeployKeyResponse{
        metadata: meta(code: :OK),
        deploy_key: %InternalApi.Projecthub.CheckDeployKeyResponse.DeployKey{
          title: "semaphore-renderedtext-guard",
          fingerprint: "SHA256:OpCrpdiCJsjelCRPNnb0oo9EXEGbluYP9c1bUVMBUo0",
          created_at: %Google.Protobuf.Timestamp{seconds: 1_522_495_543}
        }
      }
    end

    def check_webhook(_req, _) do
      %InternalApi.Projecthub.CheckWebhookResponse{
        metadata: meta(code: :OK),
        webhook: %InternalApi.Projecthub.Webhook{
          url: "https://semaphoreci.com/f7dbf4bd-91f0-47ab-93ee-b27d5994dcf2"
        }
      }
    end

    def update(req, _) do
      cond do
        !String.contains?(req.project.spec.repository.url, "github.com") ->
          %InternalApi.Projecthub.UpdateResponse{
            metadata:
              meta(code: :FAILED_PRECONDITION, message: "Repository host must be GitHub.com")
          }

        req.project.metadata.name == "RaiseError" ->
          %InternalApi.Projecthub.UpdateResponse{
            metadata: meta(code: :FAILED_PRECONDITION, message: "Failed to update.")
          }

        true ->
          %InternalApi.Projecthub.UpdateResponse{
            metadata: meta(code: :OK),
            project: req.project
          }
      end
    end

    def github_app_switch(_req, _) do
      %InternalApi.Projecthub.GithubAppSwitchResponse{metadata: meta(code: :OK)}
    end

    def change_project_owner(req, _) do
      case find(req) do
        {:ok, project} ->
          new_project = %{
            id: project.id,
            name: project.name,
            org_id: project.org_id,
            api_model: %InternalApi.Projecthub.Project{
              metadata: Map.merge(project.api_model.metadata, %{owner_id: req.user_id}),
              spec: project.api_model.spec,
              status: project.api_model.status
            }
          }

          DB.update(:projects, new_project)

          %InternalApi.Projecthub.ChangeProjectOwnerResponse{metadata: meta(code: :OK)}

        {:error, nil} ->
          %InternalApi.Projecthub.ChangeProjectOwnerResponse{
            metadata: meta(code: :FAILED_PRECONDITION, message: "Project not found.")
          }
      end
    end

    def destroy(req, _) do
      case find(req) do
        {:ok, project} ->
          DB.delete(:projects, project.id)

          %InternalApi.Projecthub.DestroyResponse{metadata: meta(code: :OK)}

        {:error, nil} ->
          %InternalApi.Projecthub.DestroyResponse{
            metadata: meta(code: :FAILED_PRECONDITION, message: "Project not found.")
          }
      end
    end

    def users(req, _) do
      user_ids =
        DB.find_all_by(:project_members, :project_id, req.id)
        |> Enum.map(fn m -> m.user_id end)

      users =
        DB.find_many(:users, user_ids)
        |> Enum.map(fn u -> Support.Stubs.User.Grpc.describe_to_user(u.api_model) end)

      %InternalApi.Projecthub.UsersResponse{
        metadata: meta(code: :OK),
        users: users
      }
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

      %ResponseMeta{
        status: %ResponseMeta.Status{
          code: ResponseMeta.Code.value(options[:code]),
          message: options[:message]
        }
      }
    end
  end
end
