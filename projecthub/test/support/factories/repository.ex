defmodule Support.Factories.Repository do
  alias Projecthub.Models.Repository
  alias Projecthub.Repo

  def create(params \\ %{}) do
    {:ok, %{repository: repository}} =
      Projecthub.RepositoryHubClient.create(%{
        project_id: params.project_id,
        user_id: Map.get(params, :creator_id, Ecto.UUID.generate()),
        pipeline_file: ".semaphore/semaphore.yml",
        repository_url: Map.get(params, :url, "repo"),
        only_public: true,
        integration_type: :GITHUB_OAUTH_TOKEN,
        commit_status: %InternalApi.Projecthub.Project.Spec.Repository.Status{
          pipeline_files: [
            %InternalApi.Projecthub.Project.Spec.Repository.Status.PipelineFile{
              level: :PIPELINE,
              path: ".semaphore/semaphore.yml"
            }
          ]
        },
        whitelist: %InternalApi.Projecthub.Project.Spec.Repository.Whitelist{
          branches: ["master", "/feature-*/"],
          tags: []
        },
        request_id: ""
      })

    {:ok, repository} = Repository.from_grpc(repository)

    params =
      %{
        id: repository.id,
        hook_id: "hook_id",
        name: repository.name,
        owner: repository.owner,
        private: repository.private,
        provider: "github",
        integration_type: "github_oauth_token",
        url: "repo_url",
        created_at: DateTime.utc_now(),
        project_id: Ecto.UUID.generate(),
        enable_commit_status: true,
        commit_status: %{
          "pipeline_files" => [
            %{"path" => ".semaphore/semaphore.yml", "level" => "pipeline"}
          ]
        },
        whitelist: %{"branches" => ["master", "/feature-*/"], "tags" => []},
        connected: true,
        default_branch: "main"
      }
      |> Map.merge(params)

    changeset =
      %Repository.SQL{}
      |> Ecto.Changeset.cast(params, [
        :id,
        :hook_id,
        :name,
        :owner,
        :private,
        :provider,
        :integration_type,
        :url,
        :created_at,
        :updated_at,
        :project_id,
        :pipeline_file,
        :commit_status,
        :whitelist,
        :connected,
        :default_branch
      ])

    {:ok, _} = Repo.insert(changeset)
    {:ok, repository}
  end
end
