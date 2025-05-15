defmodule RepositoryHub.BitbucketClient do
  @moduledoc """
  Http client for comunicating with Bitbucket.
  """

  @behaviour RepositoryHub.GitClient
  alias RepositoryHub.Toolkit
  import Toolkit

  @type request_options :: [token: String.t()]
  @type http_response :: {:ok, HTTPoison.Response.t() | HTTPoison.AsyncResponse.t()} | {:error, HTTPoison.Error.t()}

  @doc """
  https://developer.atlassian.com/cloud/bitbucket/rest/api-group-commit-statuses/#api-repositories-workspace-repo-slug-commit-commit-statuses-build-post
  """
  @impl true
  def create_build_status(params, opts \\ []) do
    token = fetch_token(opts)

    "https://api.bitbucket.org/2.0/repositories/#{params.repo_owner}/#{params.repo_name}/commit/#{params.commit_sha}/statuses/build"
    |> http_post(token, %{
      "key" => params.context,
      "state" => params.status,
      "url" => params.url,
      "description" => params.description,
      "name" => params.context
    })
    |> process_response
  end

  @doc """
  https://developer.atlassian.com/cloud/bitbucket/rest/api-group-repositories/#api-repositories-workspace-repo-slug-get
  """
  @impl true
  def find_repository(params, opts \\ []) do
    token = fetch_token(opts)

    "https://api.bitbucket.org/2.0/repositories/#{params.repo_owner}/#{params.repo_name}"
    |> http_get(token, %{})
    |> process_response
    |> unwrap(fn response ->
      %{
        id: response["uuid"],
        with_admin_access?: true,
        is_private?: response["is_private"],
        description: response["description"] || "",
        created_at: Timex.parse!(response["created_on"], "{ISO:Extended}"),
        provider: "bitbucket",
        name: response["slug"],
        full_name: response["full_name"],
        default_branch: response["mainbranch"]["name"]
      }
      |> wrap
    end)
  end

  @doc """
  https://developer.atlassian.com/cloud/bitbucket/rest/api-group-deployments/#api-repositories-workspace-repo-slug-deploy-keys-key-id-get
  """
  @impl true
  def find_deploy_key(params, opts \\ []) do
    token = fetch_token(opts)

    "https://api.bitbucket.org/2.0/repositories/#{params.repo_owner}/#{params.repo_name}/deploy-keys/#{params.key_id}"
    |> http_get(token, %{})
    |> handle_404(fn _response ->
      error(%{
        status: GRPC.Status.not_found(),
        message: "Semaphore couldn't fetch the webhook from BitBucket."
      })
    end)
    |> process_response
    |> unwrap(fn deploy_key ->
      %{
        id: deploy_key["id"],
        title: deploy_key["label"] || "",
        key: deploy_key["key"],
        read_only: false
      }
      |> wrap()
    end)
  end

  @impl true
  def remove_deploy_key(params, opts \\ []) do
    token = fetch_token(opts)
    grpc_not_found = GRPC.Status.not_found()

    "https://api.bitbucket.org/2.0/repositories/#{params.repo_owner}/#{params.repo_name}/deploy-keys/#{params.key_id}"
    |> http_delete(token)
    |> handle_404(fn _response ->
      error(%{
        status: grpc_not_found,
        message: "Semaphore couldn't fetch the webhook from BitBucket."
      })
    end)
    |> process_response
    |> unwrap_error(fn
      %{status: ^grpc_not_found} ->
        wrap(:ok)

      error ->
        error(error)
    end)
    |> unwrap(fn _response ->
      wrap(:ok)
    end)
  end

  @impl true
  def create_deploy_key(params, opts \\ []) do
    token = fetch_token(opts)

    "https://api.bitbucket.org/2.0/repositories/#{params.repo_owner}/#{params.repo_name}/deploy-keys"
    |> http_post(token, %{
      label: params.title,
      key: params.key
    })
    |> process_response
    |> unwrap(fn deploy_key ->
      %{
        id: deploy_key["id"],
        title: deploy_key["label"] || "",
        key: deploy_key["key"],
        read_only: true
      }
      |> wrap()
    end)
  end

  @doc """
  https://developer.atlassian.com/cloud/bitbucket/rest/api-group-deployments/#api-repositories-workspace-repo-slug-deploy-keys-key-id-get
  """
  def find_webhook(params, opts \\ []) do
    token = fetch_token(opts)

    Map.get(params, :webhook_id)
    |> case do
      webhook_id when is_bitstring(webhook_id) and webhook_id != "" ->
        webhook_lookup(params, token)

      _ ->
        search_existing_webhooks(params, token)
    end
  end

  defp webhook_lookup(params, token) do
    webhook_id =
      Map.get(params, :webhook_id, "")
      |> encode

    "https://api.bitbucket.org/2.0/repositories/#{params.repo_owner}/#{params.repo_name}/hooks/#{webhook_id}"
    |> http_get(token, %{})
    |> handle_404(fn _response ->
      error(%{
        status: GRPC.Status.not_found(),
        message: "Semaphore couldn't fetch the webhook from BitBucket."
      })
    end)
    |> process_response
    |> unwrap(fn webhook ->
      %{
        id: webhook["uuid"],
        url: webhook["url"],
        active: webhook["active"],
        events: webhook["events"],
        has_secret?: webhook["secret_set"]
      }
      |> wrap()
    end)
  end

  defp search_existing_webhooks(params, token) do
    "https://api.bitbucket.org/2.0/repositories/#{params.repo_owner}/#{params.repo_name}/hooks"
    |> http_get(token, %{})
    |> process_response
    |> unwrap(fn %{"values" => webhooks} ->
      webhooks
      |> Enum.map(fn webhook ->
        %{
          id: webhook["uuid"],
          url: webhook["url"],
          active: webhook["active"],
          events: webhook["events"],
          has_secret?: webhook["secret_set"]
        }
      end)
      |> Enum.filter(fn webhook ->
        webhook.url == params.url
      end)
      |> Enum.sort_by(
        fn webhook ->
          Enum.sort(webhook.events) == params.events
        end,
        :desc
      )
      |> List.first()
    end)
    |> unwrap(fn
      nil ->
        error(%{
          status: GRPC.Status.not_found(),
          message: "Semaphore couldn't fetch the webhook from BitBucket."
        })

      webhook ->
        wrap(webhook)
    end)
  end

  @impl true
  def remove_webhook(params, opts \\ []) do
    token = fetch_token(opts)

    webhook_id =
      Map.get(params, :webhook_id, "")
      |> encode

    grpc_not_found = GRPC.Status.not_found()

    "https://api.bitbucket.org/2.0/repositories/#{params.repo_owner}/#{params.repo_name}/hooks/#{webhook_id}"
    |> http_delete(token)
    |> handle_404(fn _response ->
      error(%{
        status: grpc_not_found,
        message: "Semaphore couldn't fetch the webhook from BitBucket."
      })
    end)
    |> process_response
    |> unwrap_error(fn
      %{status: ^grpc_not_found} ->
        wrap(:ok)

      error ->
        error(error)
    end)
    |> unwrap(fn _response ->
      wrap(:ok)
    end)
  end

  @impl true
  def create_webhook(params, opts \\ []) do
    token = fetch_token(opts)

    "https://api.bitbucket.org/2.0/repositories/#{params.repo_owner}/#{params.repo_name}/hooks"
    |> http_post(token, %{
      description: "Semaphore CI",
      url: params.url,
      events: params.events,
      active: true,
      secret: params.secret
    })
    |> process_response
    |> unwrap(fn response ->
      %{
        id: response["uuid"],
        url: response["url"]
      }
      |> wrap()
    end)
  end

  def validate_hook(webhook, hook_url, events) do
    webhook
    |> RepositoryHub.Validator.validate(
      all: [
        chain: [from!: "active", eq: true, error: "Webhook is not active on Bitbucket."],
        chain: [
          from!: "config",
          from!: "url",
          eq: hook_url,
          error: "Webhook is not active on Bitbucket."
        ],
        chain: [from!: "events", eq: events, error: "Webhook is not triggered for proper events."]
      ]
    )
  end

  @doc """
  https://developer.atlassian.com/cloud/bitbucket/rest/api-group-repositories/#api-repositories-workspace-repo-slug-forks-post
  """
  def fork(params, opts \\ []) do
    token = fetch_token(opts)

    "https://api.bitbucket.org/2.0/repositories/#{params.repo_owner}/#{params.repo_name}/forks"
    |> http_post(token, %{})
    |> process_response
    |> unwrap(fn response ->
      %{
        url: get_in(response, ["links", "clone", Access.at(0), "href"])
      }
      |> wrap()
    end)
  end

  @doc """
  https://developer.atlassian.com/cloud/bitbucket/rest/api-group-workspaces/#api-workspaces-workspace-permissions-repositories-get
  """
  @impl true
  def list_repository_collaborators(params, opts \\ []) do
    token = fetch_token(opts)

    "https://api.bitbucket.org/2.0/workspaces/#{params.repo_owner}/permissions/repositories/#{params.repo_name}"
    |> paged_resource(params.page_token)
    |> http_get(token, %{
      pagelen: 100
    })
    |> process_response()
  end

  @doc """
  https://developer.atlassian.com/cloud/bitbucket/rest/api-group-repositories/#api-user-permissions-repositories-get
  """
  @impl true
  def list_repositories(params, opts \\ []) do
    token = fetch_token(opts)

    "https://api.bitbucket.org/2.0/user/permissions/repositories"
    |> paged_resource(params.page_token)
    |> http_get(token, %{
      pagelen: 100,
      sort: "repository.created_on",
      q: params.query
    })
    |> process_response()
  end

  @impl true
  def get_reference(params, opts \\ [])

  def get_reference(%{reference: "refs/heads/" <> branch_name} = params, opts) do
    params |> Map.put(:branch_name, branch_name) |> get_branch(opts)
  end

  def get_reference(%{reference: "refs/tags/" <> tag_name} = params, opts) do
    params |> Map.put(:tag_name, tag_name) |> get_tag(opts)
  end

  @doc """
  https://developer.atlassian.com/cloud/bitbucket/rest/api-group-refs/#api-repositories-workspace-repo-slug-refs-branches-name-get
  """
  @impl true
  def get_branch(params, opts \\ []) do
    token = fetch_token(opts)

    "https://api.bitbucket.org/2.0/repositories/#{params.repo_owner}/#{params.repo_name}/refs/branches/#{params.branch_name}"
    |> http_get(token, %{})
    |> process_response
    |> unwrap(fn response ->
      %{
        type: "branch",
        sha: response["target"]["hash"]
      }
      |> wrap()
    end)
  end

  @doc """
  https://developer.atlassian.com/cloud/bitbucket/rest/api-group-refs/#api-repositories-workspace-repo-slug-refs-tags-post
  """
  @impl true
  def get_tag(params, opts \\ []) do
    token = fetch_token(opts)

    "https://api.bitbucket.org/2.0/repositories/#{params.repo_owner}/#{params.repo_name}/refs/tags/#{params.tag_name}"
    |> http_get(token, %{})
    |> process_response
    |> unwrap(fn response ->
      %{
        type: "tag",
        sha: response["target"]["hash"]
      }
      |> wrap()
    end)
  end

  @doc """
  https://developer.atlassian.com/cloud/bitbucket/rest/api-group-commits/#api-repositories-workspace-repo-slug-commit-commit-get
  """
  @impl true
  def get_commit(params, opts \\ []) do
    token = fetch_token(opts)

    "https://api.bitbucket.org/2.0/repositories/#{params.repo_owner}/#{params.repo_name}/commit/#{params.commit_sha}"
    |> http_get(token, %{})
    |> process_response
    |> unwrap(fn response ->
      %{
        sha: response["hash"],
        message: response["message"],
        author_name: response["author"]["user"]["display_name"] || response["author"]["raw"],
        author_uuid: response["author"]["user"]["uuid"] || "",
        author_avatar_url: response["author"]["user"]["links"]["avatar"]["href"] || ""
      }
      |> wrap()
    end)
  end

  @impl true
  def get_file(params, opts \\ []) do
    token = fetch_token(opts)

    "https://api.bitbucket.org/2.0/repositories/#{params.repo_owner}/#{params.repo_name}/src/#{params.commit_sha}/#{params.path}"
    |> http_get(token, %{})
    |> handle_404(fn response ->
      error_message =
        response.body
        |> Jason.decode!()
        |> case do
          %{"type" => "error", "error" => %{"message" => error}} ->
            "File not found. #{error}"

          _ ->
            "File not found."
        end

      error(%{
        status: GRPC.Status.not_found(),
        message: error_message
      })
    end)
    |> unwrap(fn
      %{status_code: 200, body: body} ->
        body
        |> Base.encode64()
        |> wrap()
    end)
  end

  defp fetch_token(opts) do
    Keyword.fetch!(opts, :token)
  end

  defp http_post(resource, token, data) do
    body = Jason.encode!(data)

    resource
    |> HTTPoison.post(body, request_headers(token), options())
  end

  defp http_delete(resource, token) do
    resource
    |> HTTPoison.delete(request_headers(token), options())
  end

  defp http_get(resource, token, data) do
    resource
    |> HTTPoison.get(request_headers(token), options(params: data))
  end

  defp options(opts \\ []) do
    [recv_timeout: 25_000]
    |> Keyword.merge(opts)
  end

  defp process_response(response) do
    response
    |> unwrap(fn response ->
      """
      Parsing Bitbucket response:
      From: #{inspect(response.request_url)}
      Payload: #{inspect(response.request)}
      """
      |> log(level: :debug)

      {response.status_code, response.body, response.headers, response.request_url}
    end)
    |> unwrap(fn
      {status_code, encoded_body, _headers, request_url}
      when status_code >= 200 and status_code <= 399 ->
        encoded_body
        |> case do
          "" ->
            wrap("")

          body ->
            body
            |> Jason.decode()
            |> unwrap_error(fn decode_error ->
              log_error([
                "parsing result from #{request_url}",
                "status: #{status_code}",
                "error: #{inspect(decode_error)}"
              ])

              wrap("")
            end)
        end

      {status_code, body, _headers, request_url} ->
        "Bitbucket API error: #{status_code} #{request_url}"
        |> log(level: :error)

        error(body)
    end)
    |> unwrap(fn
      %{"type" => "error", "error" => %{"message" => message}} = _decoded_body ->
        error(message)

      decoded_body ->
        decoded_body
        |> wrap
    end)
  end

  def paged_resource(resource_url, page_token) do
    page_token
    |> case do
      "null" -> resource_url
      "" -> resource_url
      nil -> resource_url
      encoded_resource_url -> Base.decode64!(encoded_resource_url)
    end
  end

  defp request_headers(token) do
    [{"Authorization", "Bearer #{token}"}, {"Content-Type", "application/json"}]
  end

  defp encode(string) do
    string
    |> URI.encode()
  end

  @spec handle_404(http_response, (http_response -> Toolkit.tupled_result())) :: Toolkit.tupled_result()
  defp handle_404(response, callback) do
    response
    |> unwrap(fn
      %{status_code: 404} = response ->
        "Bitbucket API: #{response.status_code} #{response.request_url} #{response.body}"
        |> log(level: :debug)

        callback.(response)

      response ->
        wrap(response)
    end)
  end

  defmodule Webhook do
    def url(organization_name, repository_id) do
      host = Application.fetch_env!(:repository_hub, :webhook_host)

      "https://#{organization_name}.#{host}/hooks/bitbucket?id=#{repository_id}"
    end

    def events do
      ["issue:comment_created", "pullrequest:created", "repo:push"]
    end
  end
end
