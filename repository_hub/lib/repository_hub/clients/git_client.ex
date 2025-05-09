defmodule RepositoryHub.GitClient do
  @type options() :: [token: String.t()]

  @type create_build_status_response :: %{}
  @type create_build_status_request :: %{
          repo_owner: String.t(),
          repo_name: String.t(),
          commit_sha: String.t(),
          status: String.t(),
          url: String.t(),
          description: String.t(),
          context: String.t()
        }

  @type list_repository_collaborators_response :: %{}
  @type list_repository_collaborators_request :: %{
          repo_owner: String.t(),
          repo_name: String.t(),
          page_token: String.t()
        }

  @type list_repositories_response :: %{}
  @type list_repositories_request :: %{
          page_token: String.t(),
          type: String.t(),
          query: String.t()
        }

  @type get_file_response :: %{}
  @type get_file_request :: %{
          repo_owner: String.t(),
          repo_name: String.t(),
          commit_sha: String.t(),
          path: String.t()
        }

  @type find_repository_response :: %{
          with_admin_access?: boolean(),
          is_private?: boolean(),
          description: String.t(),
          created_at: DateTime.t(),
          provider: String.t()
        }
  @type find_repository_request :: %{
          repo_owner: String.t(),
          repo_name: String.t()
        }

  @type find_deploy_key_response :: %{}
  @type find_deploy_key_request :: %{
          repo_owner: String.t(),
          repo_name: String.t(),
          key_id: pos_integer()
        }

  @type create_deploy_key_response :: %{}
  @type create_deploy_key_request :: %{
          repo_owner: String.t(),
          repo_name: String.t(),
          title: String.t(),
          key: String.t(),
          read_only: boolean()
        }

  @type create_webhook_response :: %{}
  @type create_webhook_request :: %{
          repo_owner: String.t(),
          repo_name: String.t(),
          url: String.t(),
          events: list(String.t()),
          secret: String.t()
        }

  @type remove_deploy_key_response :: %{}
  @type remove_deploy_key_request :: %{
          repo_owner: String.t(),
          repo_name: String.t(),
          key_id: pos_integer()
        }

  @type remove_webhook_response :: %{}
  @type remove_webhook_request :: %{
          repo_owner: String.t(),
          repo_name: String.t(),
          webhook_id: pos_integer()
        }

  @type get_reference_response :: %{}
  @type get_reference_request :: %{
          repo_owner: String.t(),
          repo_name: String.t(),
          reference: String.t()
        }

  @type get_branch_response :: %{}
  @type get_branch_request :: %{
          repo_owner: String.t(),
          repo_name: String.t(),
          branch_name: String.t()
        }

  @type get_tag_response :: %{}
  @type get_tag_request :: %{
          repo_owner: String.t(),
          repo_name: String.t(),
          tag_name: String.t()
        }

  @type get_commit_response :: %{}
  @type get_commit_request :: %{
          repo_owner: String.t(),
          repo_name: String.t(),
          commit_sha: String.t()
        }

  @callback find_repository(find_repository_request(), options()) :: Toolkit.tupled_result(find_repository_response())
  @callback create_build_status(create_build_status_request(), options()) ::
              Toolkit.tupled_result(create_build_status_response())
  @callback list_repository_collaborators(list_repository_collaborators_request(), options()) ::
              Toolkit.tupled_result(list_repository_collaborators_response())
  @callback list_repositories(list_repositories_request(), options()) ::
              Toolkit.tupled_result(list_repositories_response())
  @callback get_file(get_file_request(), options()) :: Toolkit.tupled_result(get_file_response())
  @callback find_deploy_key(find_deploy_key_request(), options()) :: Toolkit.tupled_result(find_deploy_key_response())
  @callback create_deploy_key(create_deploy_key_request(), options()) ::
              Toolkit.tupled_result(create_deploy_key_response())
  @callback create_webhook(create_webhook_request(), options()) :: Toolkit.tupled_result(create_webhook_response())
  @callback remove_deploy_key(remove_deploy_key_request(), options()) ::
              Toolkit.tupled_result(remove_deploy_key_response())
  @callback remove_webhook(remove_webhook_request(), options()) :: Toolkit.tupled_result(remove_webhook_response())

  @callback get_reference(get_reference_request(), options()) :: Toolkit.tupled_result(get_reference_response())
  @callback get_branch(get_branch_request(), options()) :: Toolkit.tupled_result(get_branch_response())
  @callback get_tag(get_tag_request(), options()) :: Toolkit.tupled_result(get_tag_response())
  @callback get_commit(get_commit_request(), options()) :: Toolkit.tupled_result(get_commit_response())

  defmodule Webhook do
    def url(organization_name, repository_id) do
      host = Application.fetch_env!(:repository_hub, :webhook_host)

      "https://#{organization_name}.#{host}/hooks/git?id=#{repository_id}"
    end

    def events do
      []
    end
  end
end
