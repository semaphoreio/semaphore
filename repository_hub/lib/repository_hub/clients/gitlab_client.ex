defmodule RepositoryHub.GitlabClient do
  @moduledoc """
  Http client for communicating with GitLab.
  """

  @behaviour RepositoryHub.GitClient
  alias RepositoryHub.Toolkit
  import Toolkit

  @api_url "https://gitlab.com/api/v4"
  @status_title "SemaphoreCI Pipeline"

  @type request_options :: [token: String.t()]
  @type http_response :: {:ok, HTTPoison.Response.t() | HTTPoison.AsyncResponse.t()} | {:error, HTTPoison.Error.t()}

  @doc """
  https://docs.gitlab.com/ee/api/projects.html#get-a-single-project
  """
  @impl true
  def find_repository(params, opts \\ []) do
    token = fetch_token(opts)
    project_id = project_identifier(params)

    "#{@api_url}/projects/#{project_id}"
    |> http_get(token, %{})
    |> handle_404(fn _response ->
      error(%{
        status: GRPC.Status.not_found(),
        message: "Semaphore couldn't find the repository on GitLab."
      })
    end)
    |> process_response
    |> unwrap(fn response ->
      project_access = get_in(response, ["permissions", "project_access"]) || %{}
      group_access = get_in(response, ["permissions", "group_access"]) || %{}

      admin_access =
        project_access["access_level"] >= 50 ||
          group_access["access_level"] >= 50

      %{
        id: response["id"] |> Integer.to_string(),
        with_admin_access?: admin_access,
        is_private?: response["visibility"] == "private",
        description: response["description"] || "",
        created_at: parse_datetime(response["created_at"]),
        url: response["ssh_url_to_repo"],
        provider: "gitlab",
        name: response["path"],
        full_name: response["path_with_namespace"],
        default_branch: response["default_branch"]
      }
      |> wrap
    end)
  end

  @doc """
  https://docs.gitlab.com/ee/api/commits.html#set-the-pipeline-status-of-a-commit
  """
  @impl true
  def create_build_status(params, opts \\ []) do
    token = fetch_token(opts)
    project_id = project_identifier(params)

    body = %{
      state: params.state,
      sha: params.commit_sha,
      target_url: params.url,
      description: params.description,
      name: params.context,
      context: @status_title
    }

    "#{@api_url}/projects/#{project_id}/statuses/#{params.commit_sha}"
    |> http_post(token, body)
    |> process_response
    |> wrap
  end

  @doc """
  https://docs.gitlab.com/ee/api/members.html#list-all-members-of-a-group-or-project
  """
  @impl true
  def list_repository_collaborators(params, opts \\ []) do
    token = fetch_token(opts)
    project_id = project_identifier(params)

    query_params =
      if params.page_token != "" do
        %{}
      else
        %{
          per_page: 100
        }
      end

    "#{@api_url}/projects/#{project_id}/members"
    |> paged_resource(params.page_token)
    |> http_get(token, query_params)
    |> unwrap(fn response ->
      items =
        response.body
        |> Jason.decode()
        |> unwrap_error(fn decode_error ->
          log_error([
            "failed to decode repositories list",
            "error: #{inspect(decode_error)}"
          ])

          wrap([])
        end)
        |> unwrap(fn collaborators ->
          collaborators
        end)

      %{
        items: items,
        # next_page_token: params.next_page_token
        next_page_token: get_next_page_token(response.headers)
      }
      |> wrap
    end)
  end

  @doc """
  https://docs.gitlab.com/ee/api/projects.html#list-all-projects
  """
  @impl true
  def list_repositories(params, opts \\ []) do
    token = fetch_token(opts)

    query_params =
      if params.page_token != "" do
        %{}
      else
        visibility = if params.only_public?, do: "public", else: nil

        [
          order_by: "id",
          pagination: "keyset",
          per_page: 100,
          membership: true,
          page: params.page_token,
          visibility: visibility
        ]
        |> Keyword.reject(fn {_, val} -> is_nil(val) end)
      end

    "#{@api_url}/projects"
    |> paged_resource(params.page_token)
    |> http_get(token, query_params)
    |> unwrap(fn response ->
      items =
        response.body
        |> Jason.decode()
        |> unwrap_error(fn decode_error ->
          log_error([
            "failed to decode repositories list",
            "error: #{inspect(decode_error)}"
          ])

          wrap([])
        end)
        |> unwrap(fn repositories ->
          repositories
        end)

      next_page_token = get_next_page_token(response.headers)

      %{items: items, next_page_token: next_page_token}
      |> wrap
    end)
  end

  @doc """
  https://docs.gitlab.com/ee/api/repository_files.html#get-file-from-repository
  """
  @impl true
  def get_file(params, opts \\ []) do
    token = fetch_token(opts)
    project_id = project_identifier(params)
    file_path = URI.encode(params.path, &URI.char_unreserved?/1)

    "#{@api_url}/projects/#{project_id}/repository/files/#{file_path}"
    |> http_get(token, ref: params.commit_sha)
    |> handle_404(fn _response ->
      error(%{
        status: GRPC.Status.not_found(),
        message: "File not found."
      })
    end)
    |> unwrap(fn
      %{status_code: 200, body: body} ->
        body
        |> Jason.decode!()
        |> case do
          %{"encoding" => "base64", "content" => content} ->
            content
            |> wrap
        end
    end)
  end

  @doc """
  https://docs.gitlab.com/ee/api/deploy_keys.html#get-a-single-deploy-key
  """
  @impl true
  def find_deploy_key(params, opts \\ []) do
    token = fetch_token(opts)
    project_id = project_identifier(params)

    "#{@api_url}/projects/#{project_id}/deploy_keys/#{params.key_id}"
    |> http_get(token, %{})
    |> handle_404(fn _response ->
      error(%{
        status: GRPC.Status.not_found(),
        message: "Semaphore couldn't fetch the deploy key from GitLab."
      })
    end)
    |> process_response
    |> unwrap(fn response ->
      %{
        id: response["id"] |> Integer.to_string(),
        title: response["title"],
        key: response["key"]
      }
      |> wrap
    end)
  end

  @doc """
  https://docs.gitlab.com/ee/api/deploy_keys.html#add-deploy-key
  """
  @impl true
  def create_deploy_key(params, opts \\ []) do
    token = fetch_token(opts)
    project_id = project_identifier(params)

    body = %{
      title: params.title,
      key: params.key,
      can_push: false
    }

    "#{@api_url}/projects/#{project_id}/deploy_keys"
    |> http_post(token, body)
    |> process_response
    |> unwrap(fn response ->
      %{
        id: response["id"] |> Integer.to_string(),
        title: response["title"]
      }
      |> wrap
    end)
    |> unwrap_error(fn error ->
      "Failed to create deploy key: #{format_error(error)}" |> error()
    end)
  end

  @doc """
  https://docs.gitlab.com/ee/api/project_webhooks.html#add-a-webhook-to-a-project
  """
  @impl true
  def create_webhook(params, opts \\ []) do
    token = fetch_token(opts)
    project_id = project_identifier(params)

    events =
      params.events
      |> Enum.into(%{}, fn event ->
        {String.to_atom(event), true}
      end)

    body =
      %{
        url: params.url,
        name: params.name,
        token: params.secret
      }
      |> Map.merge(events)

    "#{@api_url}/projects/#{project_id}/hooks"
    |> http_post(token, body)
    |> process_response
    |> unwrap(fn response ->
      %{id: response["id"] |> Integer.to_string()}
      |> wrap
    end)
  end

  @doc """
  https://docs.gitlab.com/ee/api/deploy_keys.html#delete-deploy-key
  """
  @impl true
  def remove_deploy_key(params, opts \\ []) do
    token = fetch_token(opts)
    project_id = project_identifier(params)

    "#{@api_url}/projects/#{project_id}/deploy_keys/#{params.key_id}"
    |> http_delete(token)
    |> handle_404(fn _response ->
      error(%{
        status: GRPC.Status.not_found(),
        message: "Semaphore couldn't fetch the deploy key from GitLab."
      })
    end)
    |> process_response
    |> wrap
  end

  @doc """
  https://docs.gitlab.com/ee/api/project_webhooks.html#delete-project-webhook
  """
  @impl true
  def remove_webhook(params, opts \\ []) do
    token = fetch_token(opts)
    project_id = project_identifier(params)

    "#{@api_url}/projects/#{project_id}/hooks/#{params.webhook_id}"
    |> http_delete(token)
    |> handle_404(fn _response ->
      error(%{
        status: GRPC.Status.not_found(),
        message: "Semaphore couldn't fetch the webhook from GitLab."
      })
    end)
    |> process_response
    |> wrap
  end

  @doc """
  https://docs.gitlab.com/ee/api/commits.html#get-a-single-commit
  """
  @impl true
  def get_reference(params, opts \\ [])

  def get_reference(%{reference: "refs/heads/" <> branch_name} = params, opts) do
    params |> Map.put(:branch_name, branch_name) |> get_branch(opts)
  end

  def get_reference(%{reference: "refs/tags/" <> tag_name} = params, opts) do
    params |> Map.put(:tag_name, tag_name) |> get_tag(opts)
  end

  @doc """
  https://docs.gitlab.com/ee/api/branches.html#get-single-repository-branch
  """
  @impl true
  def get_branch(params, opts \\ []) do
    token = fetch_token(opts)
    project_id = project_identifier(params)
    encoded_branch_name = URI.encode(params.branch_name, &URI.char_unreserved?/1)

    "#{@api_url}/projects/#{project_id}/repository/branches/#{encoded_branch_name}"
    |> http_get(token, %{})
    |> process_response
    |> unwrap(fn response ->
      %{
        type: "branch",
        sha: response["commit"]["id"]
      }
      |> wrap
    end)
  end

  @doc """
  https://docs.gitlab.com/ee/api/tags.html#get-a-single-repository-tag
  """
  @impl true
  def get_tag(params, opts \\ []) do
    token = fetch_token(opts)
    project_id = project_identifier(params)
    encoded_tag_name = URI.encode(params.tag_name, &URI.char_unreserved?/1)

    "#{@api_url}/projects/#{project_id}/repository/tags/#{encoded_tag_name}"
    |> http_get(token, %{})
    |> process_response
    |> unwrap(fn response ->
      %{
        type: "tag",
        sha: response["target"] || response["commit"]["id"]
      }
      |> wrap
    end)
  end

  @doc """
  https://docs.gitlab.com/ee/api/commits.html#get-a-single-commit
  """
  @impl true
  def get_commit(params, opts \\ []) do
    token = fetch_token(opts)
    project_id = project_identifier(params)

    "#{@api_url}/projects/#{project_id}/repository/commits/#{params.commit_sha}"
    |> http_get(token, %{})
    |> handle_404(fn _response ->
      error(%{
        status: GRPC.Status.not_found(),
        message: "Semaphore couldn't fetch the commit from GitLab."
      })
    end)
    |> process_response
    |> unwrap(fn response ->
      %{
        sha: response["id"],
        message: response["message"],
        author_name: response["author_name"],
        author_email: response["author_email"]
      }
      |> wrap
    end)
  end

  @doc """
  https://docs.gitlab.com/ee/api/project_webhooks.html#get-a-project-webhook
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
    project_id = project_identifier(params)

    "#{@api_url}/projects/#{project_id}/hooks/#{params.webhook_id}"
    |> http_get(token, %{})
    |> handle_404(fn _response ->
      fail_with(:not_found, "Semaphore couldn't fetch the webhook from GitLab.")
    end)
    |> process_response
    |> unwrap(&format_webhook/1)
    |> wrap()
  end

  defp search_existing_webhooks(params, token) do
    project_id = project_identifier(params)

    "#{@api_url}/projects/#{project_id}/hooks"
    |> http_get(token, %{})
    |> process_response
    |> unwrap(fn response ->
      response
      |> Enum.map(&format_webhook/1)
      |> Enum.filter(fn webhook ->
        webhook.url == params.url
      end)
      |> Enum.sort_by(
        fn webhook ->
          webhook.events["push_events"] == true and
            webhook.events["merge_requests_events"] == true and
            webhook.events["tag_push_events"] == true
        end,
        :desc
      )
      |> List.first()
      |> case do
        nil ->
          fail_with(:not_found, "Semaphore couldn't fetch the webhook from GitLab.")

        webhook ->
          wrap(webhook)
      end
    end)
  end

  defp format_webhook(webhook) do
    %{
      id: webhook["id"] |> Integer.to_string(),
      url: webhook["url"],
      name: webhook["name"],
      active: webhook["alert_status"] == "executable",
      events: %{
        "push_events" => webhook["push_events"],
        "merge_requests_events" => webhook["merge_requests_events"],
        "tag_push_events" => webhook["tag_push_events"]
      }
    }
  end

  @doc """
  https://docs.gitlab.com/ee/api/users.html#list-users
  """
  def find_user(%{search: search}, token) do
    "#{@api_url}/users?search=#{URI.encode_www_form(search)}"
    |> http_get(token, %{})
    |> process_response
    |> unwrap(fn response ->
      case response do
        [user | _] ->
          %{
            id: user["id"] |> Integer.to_string(),
            username: user["username"],
            name: user["name"],
            avatar_url: user["avatar_url"]
          }
          |> wrap()

        [] ->
          {:error, "User not found"}
      end
    end)
  end

  @doc """
  https://docs.gitlab.com/ee/api/project_forks.html#fork-a-project
  """
  def fork(params, opts \\ []) do
    token = fetch_token(opts)
    project_id = encode_project_path(params.repo_owner, params.repo_name)

    "#{@api_url}/projects/#{project_id}/fork"
    |> http_post(token, %{})
    |> process_response
    |> unwrap(fn response ->
      # %{url: response["web_url"]} |> wrap()
      %{url: response["ssh_url_to_repo"]} |> wrap()
    end)
  end

  # Private functions

  @spec handle_404(http_response, (http_response -> Toolkit.tupled_result())) :: Toolkit.tupled_result()
  defp handle_404(response, callback) do
    response
    |> unwrap(fn
      %{status_code: 404} = response ->
        "GitLab API: #{response.status_code} #{response.request_url} #{response.body}"
        |> log(level: :debug)

        callback.(response)

      response ->
        wrap(response)
    end)
  end

  defp fetch_token(opts) do
    Keyword.fetch!(opts, :token)
  end

  defp project_identifier(%{repository_id: project_id}), do: project_id
  defp project_identifier(%{repo_owner: owner, repo_name: name}), do: encode_project_path(owner, name)

  defp encode_project_path(owner, name) do
    URI.encode("#{owner}/#{name}", &URI.char_unreserved?/1)
  end

  defp get_next_page_token(headers) do
    case Enum.find(headers, fn {key, _} -> String.downcase(key) == "link" end) do
      {_, link_header} ->
        case Regex.run(~r/<([^>]+)>;\s*rel="next"/, link_header) do
          [_, next_url] -> Base.encode64(next_url)
          nil -> ""
        end

      nil ->
        ""
    end
  end

  defp parse_datetime(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, datetime, _offset} -> datetime
      _ -> nil
    end
  end

  defp paged_resource(url, page_token) do
    case page_token do
      nil -> url
      "" -> url
      encoded_resource_url -> Base.decode64!(encoded_resource_url)
    end
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

  defp request_headers(token) do
    [
      {"Content-Type", "application/json"},
      {"Accept", "application/json"},
      {"Authorization", "Bearer #{token}"}
    ]
  end

  defp process_response(response) do
    response
    |> unwrap(fn response ->
      """
      Status code: #{inspect(response.status_code)}
      From: #{inspect(response.request_url)}
      Payload: #{inspect(response.request)}
      """
      |> log(level: :debug)

      {response.status_code, response.body, response.headers, response.request_url}
    end)
    |> unwrap(fn
      {_, "", _, _} ->
        wrap("")

      {status_code, encoded_body, _headers, request_url} ->
        encoded_body
        |> Jason.decode()
        |> unwrap_error(fn decode_error ->
          log_error([
            "parsing result from #{request_url}",
            "status: #{status_code}",
            "error: #{inspect(decode_error)}"
          ])

          wrap("")
        end)
        |> unwrap(fn decoded_body ->
          if status_code >= 200 and status_code <= 399 do
            wrap(decoded_body)
          else
            "Gitlab API error: #{status_code} #{request_url}, #{inspect(decoded_body)}"
            |> log(level: :error)

            error(decoded_body["message"] || decoded_body["error"])
          end
        end)
    end)
  end

  defp format_error(error) when is_binary(error), do: error

  defp format_error(error) when is_map(error) do
    Enum.map_join(error, " ", fn {key, value} ->
      "#{key}: #{format_error(value)}"
    end)
  end

  defp format_error(error) when is_list(error) do
    Enum.map_join(error, " ", &format_error/1)
  end

  defmodule Webhook do
    def url(organization_name, repository_id) do
      host = Application.fetch_env!(:repository_hub, :webhook_host)
      "https://#{organization_name}.#{host}/hooks/gitlab?id=#{repository_id}"
    end

    def events do
      ["merge_requests_events", "push_events", "tag_push_events"]
    end
  end

  defmodule Permissions do
    @moduledoc """
      https://docs.gitlab.com/ee/api/members.html#roles
    """
    @doc """
      Maps GitLab access levels to internal api collaborator permissions:
      - Maintainer (40), Owner (50) and Admin (60): :ADMIN
      - Developer (30): :WRITE
      - Reporter (20), Guest (10): :READ
    """
    def map_collaborator_role(access_level) do
      case access_level do
        lvl when lvl >= 40 -> :ADMIN
        lvl when lvl >= 30 -> :WRITE
        _ -> :READ
      end
    end

    @doc """
    Checks if gitlab access level is at least Admin
    """
    def admin?(access_level), do: access_level >= 50
  end
end
