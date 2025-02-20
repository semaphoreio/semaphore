# credo:disable-for-this-file
defmodule RepositoryHub.GithubClient do
  @behaviour RepositoryHub.GitClient

  import RepositoryHub.Toolkit

  @typedoc """
  "success" | "failure" | "pending" | "error"
  """
  @type statuses :: String.t()

  @limits %{
    repository_permissions: 0,
    find_repository: 0,
    get_file: 0,
    find_deploy_key: 0,
    create_deploy_key: 0,
    find_webhook: 0,
    create_webhook: 0,
    remove_deploy_key: 0,
    remove_webhook: 0,
    fork: 0,
    get_branch: 0,
    get_tag: 0,
    get_commit: 0,
    create_build_status: 1000,
    list_repository_collaborators: 3000,
    list_repositories: 2000
  }

  @err_no_access "It looks like you don't have access to the repository"
  @err_not_found "Repository not found. If this is a private repository, it looks like you haven't authorized Semaphore with GitHub, please visit https://docs.semaphoreci.com/using-semaphore/connect-github#troubleshooting-guide to read more."
  @err_not_authorized "It looks like you haven't authorized Semaphore with GitHub, please visit https://docs.semaphoreci.com/using-semaphore/connect-github#troubleshooting-guide to read more."

  def repository_permissions(params, opts \\ []) do
    owner = params.repo_owner
    repo = params.repo_name
    username = params.username

    with_client(opts[:token], owner, :repository_permissions, fn client ->
      Tentacat.Repositories.Collaborators.permission(client, owner, repo, username)
      |> case do
        {200, payload, _} -> wrap(payload["user"]["permissions"])
        _ -> fail_with(:precondition, @err_no_access)
      end
    end)
  end

  @doc """
  https://docs.github.com/en/rest/repos/repos#get-a-repository
  """
  @impl true
  def find_repository(params, opts \\ []) do
    owner = params.repo_owner
    repo = params.repo_name

    with_client(opts[:token], owner, :find_repository, fn client ->
      Tentacat.Repositories.repo_get(client, owner, repo)
      |> case do
        {200, payload, _} ->
          %{
            id: Integer.to_string(payload["id"]),
            with_admin_access?: payload["permissions"]["admin"],
            permissions: payload["permissions"],
            is_private?: payload["private"],
            description: payload["description"] || "",
            created_at: Timex.parse!(payload["created_at"], "{ISO:Extended}"),
            owner: payload["owner"]["login"],
            name: payload["name"],
            full_name: payload["full_name"],
            provider: "github",
            default_branch: payload["default_branch"],
            ssh_url: payload["ssh_url"]
          }
          |> wrap

        {307, _, response} ->
          fail_with(:precondition, "Repository not found. #{fetch_status_message(response)}")

        {404, _, %{headers: headers}} ->
          log_warn([
            "repository not found in #{params.repo_owner}/#{params.repo_name}. Checking oauth scopes header..."
          ])

          case List.keyfind(headers, "X-OAuth-Scopes", 0) do
            nil ->
              fail_with(:precondition, "Error while looking up repository #{owner}/#{repo}")

            {_, scope} ->
              if scope |> String.split(", ") |> Enum.member?("repo") do
                fail_with(:not_found, "Repository not found.")
              else
                fail_with(:not_found, @err_not_found)
              end
          end

        {401, _, _} ->
          fail_with(:precondition, @err_not_authorized)

        {status, _, response} ->
          log_error([
            "fetching repository #{params.repo_owner}/#{params.repo_name}",
            "status: #{status}",
            "response: #{inspect_response(response)}"
          ])

          fail_with(
            :precondition,
            "Error while looking up repository #{owner}/#{repo}. #{fetch_status_message(response)}"
          )
      end
    end)
  end

  @impl true
  def create_build_status(params, opts \\ []) do
    with_client(opts[:token], params.repo_owner, :create_build_status, fn client ->
      Tentacat.Repositories.Statuses.create(
        client,
        params.repo_owner,
        params.repo_name,
        params.commit_sha,
        %{
          state: params.status,
          target_url: params.url,
          description: params.description,
          context: params.context
        }
      )
      |> case do
        {201, payload, _} ->
          payload
          |> wrap()

        {status_code, _, response} when status_code in [307, 404, 403, 422] ->
          log_error([
            "creating build status",
            "status: #{status_code}",
            "response: #{inspect_response(response)}"
          ])

          if is_max_statuses_response?(response) do
            # We're good.
            wrap(%{})
          else
            fail_with(:precondition, "Can't create a commit status on GitHub. #{fetch_status_message(response)}")
          end

        {status_code, _, response} ->
          log_error([
            "creating build status",
            "status: #{status_code}",
            "response: #{inspect_response(response)}"
          ])

          fail_with(:precondition, "Can't create a commit status on GitHub.")
      end
    end)
  end

  defp is_max_statuses_response?(response) do
    with ["Validation Failed"] <- fetch_message(response),
         ["This SHA and context has reached the maximum number of statuses."] <- fetch_errors(response) do
      true
    else
      _ -> false
    end
  end

  @impl true
  def list_repository_collaborators(params, opts \\ []) do
    owner = params.repo_owner
    repo = params.repo_name
    etag = Keyword.get(opts, :etag)

    with_client(opts[:token], owner, :list_repository_collaborators, fn client ->
      client
      |> Tentacat.Repositories.Collaborators.list(owner, repo, etag: etag)
      |> case do
        {307, _, response} ->
          fail_with(:precondition, "Repository collaborators not found. #{fetch_status_message(response)}")

        {404, _, _} ->
          fail_with(:not_found, "Repository collaborators not found.")

        {304, _, _} ->
          {[], [no_content: true]}
          |> wrap()

        {200, payload, response} ->
          etag = response.headers |> Enum.find_value(fn {key, value} -> if key == "ETag", do: value end)

          {payload, [etag: etag]}
          |> wrap()

        {status, _, resp} ->
          log_error([
            "listing collaborators",
            "status: #{status}",
            "response: #{inspect_response(resp)}"
          ])

          fail_with(:precondition, "Error while fetching collaborators from GitHub.")
      end
    end)
  end

  @impl true
  def list_repositories(request, opts \\ []) do
    with_client(opts[:token], "me", :list_repositories, fn client ->
      Tentacat.Repositories.list_mine(client, type: request.type, sort: "created", per_page: 100)
      |> case do
        {307, _, response} ->
          fail_with(:precondition, "Repositories not found. #{fetch_status_message(response)}")

        {404, _, _} ->
          fail_with(:not_found, "Repositories not found.")

        {200, payload, _} ->
          payload
          |> wrap()

        {status, _, resp} ->
          log_error([
            "listing repositories",
            "status: #{status}",
            "response: #{inspect_response(resp)}"
          ])

          fail_with(:precondition, "Error while fetching repositories from GitHub.")
      end
    end)
  end

  @impl true
  def get_file(params, opts \\ []) do
    with_client(opts[:token], params.repo_owner, :get_file, fn client ->
      Tentacat.Contents.find_in(
        client,
        params.repo_owner,
        params.repo_name,
        params.path,
        params.commit_sha
      )
      |> case do
        {307, _, response} ->
          fail_with(:precondition, "File not found. #{fetch_status_message(response)}")

        {404, _, _} ->
          fail_with(:not_found, "File not found.")

        {200, payload, _} ->
          payload["content"]
          |> Base.decode64!(ignore: :whitespace)
          |> Base.encode64()
          |> wrap()

        {status, _, resp} ->
          log_error([
            "getting a file #{params.repo_owner}/#{params.repo_name}",
            "status: #{status}",
            "response: #{inspect_response(resp)}"
          ])

          fail_with(:precondition, "Error while fetching a file from GitHub.")
      end
    end)
  end

  @impl true
  def find_deploy_key(params, opts \\ []) do
    with_client(opts[:token], params.repo_owner, :find_deploy_key, fn client ->
      Tentacat.Repositories.DeployKeys.find(
        client,
        params.repo_owner,
        params.repo_name,
        params.key_id
      )
      |> case do
        {307, _, response} ->
          fail_with(:precondition, "Deploy key not found. #{fetch_status_message(response)}")

        {401, _, _} ->
          fail_with(:precondition, "OAuth API token owner has broken connection between Semaphore and GitHub.")

        {404, _, %{headers: headers}} ->
          case List.keyfind(headers, "X-OAuth-Scopes", 0) do
            nil ->
              fail_with(:precondition, "Semaphore couldn't fetch the deploy key from GitHub.")

            {_, "repo" <> _scope} ->
              fail_with(
                :precondition,
                "Deploy Key is not present, or OAuth API token owner has no access to the repository."
              )

            {_, "public_repo" <> _scope} ->
              fail_with(
                :precondition,
                "Deploy Key is not present, OAuth API token owner has no access to the repository, or this is a private repository."
              )

            true ->
              fail_with(:precondition, "OAuth API token owner has broken connection between Semaphore and GitHub.")
          end

          fail_with(:not_found, "Semaphore couldn't fetch the webhook from GitHub.")

        {200, payload, _} ->
          %{
            title: payload["title"]
          }
          |> wrap()

        {status, _, resp} ->
          log_error([
            "finding deploy key #{params.repo_owner}/#{params.repo_name}",
            "status: #{status}",
            "response: #{inspect_response(resp)}"
          ])

          fail_with(:precondition, "Semaphore couldn't fetch the webhook from GitHub.")
      end
    end)
  end

  @impl true
  def create_deploy_key(params, opts \\ []) do
    with_client(opts[:token], params.repo_owner, :create_deploy_key, fn client ->
      Tentacat.Repositories.DeployKeys.create(
        client,
        params.repo_owner,
        params.repo_name,
        %{
          title: params.title,
          key: params.key,
          read_only: params.read_only
        }
      )
      |> case do
        {201, payload, _} ->
          log_success([
            "creating deploy key#{params.repo_owner}/#{params.repo_name}"
          ])

          %{
            id: payload["id"],
            title: payload["title"],
            key: payload["key"],
            read_only: payload["read_only"]
          }
          |> wrap()

        {307, _, response} ->
          fail_with(:precondition, "Error while setting deploy key on GitHub. #{fetch_status_message(response)}")

        {404, _, %{headers: headers} = resp} ->
          log_warn([
            "deploy key not found in #{params.repo_owner}/#{params.repo_name}. Checking oauth scopes header...",
            "response: #{inspect_response(resp)}"
          ])

          headers
          |> Enum.find(&(elem(&1, 0) == "X-OAuth-Scopes"))
          |> case do
            {_, scope} ->
              if String.contains?(scope, "repo") do
                fail_with(:precondition, "Error while setting deploy key on GitHub. Please contact support.")
              else
                fail_with(
                  :precondition,
                  "It looks like you haven't authorized Semaphore with GitHub, please visit https://docs.semaphoreci.com/using-semaphore/connect-github#troubleshooting-guide to read more."
                )
              end

            _ ->
              fail_with(:precondition, "Error while setting deploy key on GitHub. Please contact support.")
          end

        {status, _, resp} ->
          log_error([
            "creating deploy key #{params.repo_owner}/#{params.repo_name}",
            "status: #{status}",
            "response: #{inspect_response(resp)}"
          ])

          fail_with(:precondition, "Error while setting deploy key on GitHub. Please contact support.")
      end
    end)
  end

  def find_webhook(params, opts \\ []) do
    with_client(opts[:token], params.repo_owner, :find_webhook, fn client ->
      Map.get(params, :webhook_id)
      |> case do
        webhook_id when is_bitstring(webhook_id) and webhook_id != "" ->
          webhook_lookup(params, client)

        _ ->
          search_existing_webhooks(params, client)
      end
      |> unwrap(fn webhook_payload ->
        webhook_has_secret? = get_in(webhook_payload, ["config", "secret"]) != nil

        %{
          id: Integer.to_string(webhook_payload["id"]),
          url: webhook_payload["config"]["url"],
          has_secret?: webhook_has_secret?
        }
        |> wrap()
      end)
    end)
  end

  def webhook_lookup(params, client) do
    client
    |> Tentacat.Hooks.find(
      params.repo_owner,
      params.repo_name,
      params.webhook_id
    )
    |> case do
      {200, webhook, _} ->
        wrap(webhook)

      {307, _, response} ->
        fail_with(:precondition, "Semaphore couldn't fetch the webhook from GitHub. #{fetch_status_message(response)}")

      {404, _, _} ->
        log_warn([
          "finding webhook #{params.repo_owner}/#{params.repo_name} with id #{params.webhook_id}"
        ])

        fail_with(:not_found, "Semaphore couldn't fetch the webhook from GitHub.")

      {status, _, resp} ->
        log_error([
          "finding webhook #{params.repo_owner}/#{params.repo_name}",
          "status: #{status}",
          "response: #{inspect_response(resp)}"
        ])

        fail_with(:precondition, "Semaphore couldn't fetch the webhook from GitHub.")
    end
  end

  def search_existing_webhooks(params, client) do
    client
    |> Tentacat.Hooks.list(
      params.repo_owner,
      params.repo_name
    )
    |> case do
      {200, webhooks, _} ->
        webhooks

      {307, _, response} ->
        fail_with(:precondition, "Semaphore couldn't fetch the webhook from GitHub. #{fetch_status_message(response)}")

      {401, _, _} ->
        fail_with(:precondition, "OAuth API token owner has broken connection between Semaphore and GitHub.")

      {404, _, %{headers: headers}} ->
        log_warn([
          "webhook not found in #{params.repo_owner}/#{params.repo_name}. Checking oauth scopes header..."
        ])

        List.keyfind(headers, "X-OAuth-Scopes", 0)
        |> case do
          nil ->
            fail_with(:not_found, "Semaphore couldn't fetch the webhook from GitHub.")

          {_, "repo" <> _rest} ->
            fail_with(
              :precondition,
              "Webhook is not present, or OAuth API token owner has no access to the repository."
            )

          {_, "public_repo" <> _rest} ->
            fail_with(
              :precondition,
              "Webhook is not present, OAuth API token owner has no access to the repository, or this is a private repository."
            )

          _ ->
            fail_with(:precondition, "OAuth API token owner has broken connection between Semaphore and GitHub.")
        end

      {status, _, resp} ->
        log_error([
          "finding webhook #{params.repo_owner}/#{params.repo_name}",
          "status: #{status}",
          "response: #{inspect_response(resp)}"
        ])

        fail_with(:precondition, "Semaphore couldn't fetch the webhook from GitHub.")
    end
    |> unwrap(&find_matching_hook(&1, params.url, params.events))
    |> unwrap(fn
      nil ->
        fail_with(:not_found, "Semaphore couldn't fetch the webhook from GitHub.")

      webhook ->
        wrap(webhook)
    end)
  end

  defp find_matching_hook(webhooks, hook_url, events) do
    webhooks
    |> unwrap(fn webhooks ->
      webhooks
      |> Enum.filter(fn webhook ->
        get_in(webhook, ["config", "url"]) == hook_url
      end)
      |> Enum.sort_by(
        fn webhook ->
          Enum.sort(get_in(webhook, ["events"]) || []) == events
        end,
        :desc
      )
      |> List.first()
    end)
  end

  def validate_hook(webhook, hook_url, events) do
    webhook
    |> RepositoryHub.Validator.validate(
      all: [
        chain: [from!: "active", eq: true, error: "Webhook is not active on GitHub."],
        chain: [from!: "config", from!: "url", eq: hook_url, error: "Webhook is not active on GitHub."],
        chain: [from!: "events", eq: events, error: "Webhook is not triggered for proper events."]
      ]
    )
    |> unwrap_error(fn error ->
      fail_with(:precondition, error)
    end)
  end

  @impl true
  def create_webhook(params, opts \\ []) do
    with_client(opts[:token], params.repo_owner, :create_webhook, fn client ->
      client
      |> Tentacat.Hooks.create(
        params.repo_owner,
        params.repo_name,
        %{
          "name" => "web",
          "config" => %{
            "url" => params.url,
            "secret" => params.secret
          },
          "events" => params.events
        }
      )
      |> case do
        {201, payload, _} ->
          log_success([
            "creating webhook #{params.repo_owner}/#{params.repo_name}"
          ])

          %{
            id: Integer.to_string(payload["id"]),
            url: payload["config"]["url"]
          }
          |> wrap()

        {422, %{"message" => "Validation Failed"}, resp} ->
          errors = Enum.join(fetch_errors(resp), ". ")

          log_error([
            "creating webhook #{params.repo_owner}/#{params.repo_name}",
            "errors: #{inspect(errors)}"
          ])

          fail_with(:precondition, "The repository contains too many webhooks. Please remove some before trying again.")

        {status, _, resp} ->
          log_error([
            "creating webhook #{params.repo_owner}/#{params.repo_name}",
            "status: #{status}",
            "response: #{inspect_response(resp)}"
          ])

          fail_with(:precondition, "Error while setting webhook on GitHub. Please contact support.")
      end
    end)
  end

  @impl true
  def remove_deploy_key(params, opts \\ []) do
    with_client(opts[:token], params.repo_owner, :remove_deploy_key, fn client ->
      client
      |> Tentacat.Repositories.DeployKeys.remove(
        params.repo_owner,
        params.repo_name,
        params.key_id
      )
      |> case do
        {204, _, _} ->
          wrap(:ok)

        {307, _, response} ->
          fail_with(:precondition, "Removing deploy key failed. #{fetch_status_message(response)}")

        {404, _, _} ->
          log_warn([
            "removing deploy key #{params.repo_owner}/#{params.repo_name}",
            "key #{inspect(params.key_id)} is not present on GitHub"
          ])

          wrap(:ok)

        {status, _, resp} ->
          log_error([
            "removing deploy key #{params.repo_owner}/#{params.repo_name}",
            "status: #{status}",
            "response: #{inspect_response(resp)}"
          ])

          fail_with(:precondition, "Removing deploy key failed.")
      end
    end)
  end

  @impl true
  def remove_webhook(params, opts \\ []) do
    with_client(opts[:token], params.repo_owner, :remove_webhook, fn client ->
      client
      |> Tentacat.Hooks.remove(
        params.repo_owner,
        params.repo_name,
        params.webhook_id
      )
      |> case do
        {204, _, _} ->
          wrap(:ok)

        {307, _, response} ->
          fail_with(:precondition, "Removing webhook failed. #{fetch_status_message(response)}")

        {404, _, _} ->
          wrap(:ok)

        {status, _, resp} ->
          log_error([
            "removing webhook #{params.repo_owner}/#{params.repo_name}",
            "status: #{status}",
            "response: #{inspect_response(resp)}"
          ])

          fail_with(:precondition, "Removing webhook failed.")
      end
    end)
  end

  def fork(params, opts \\ []) do
    with_client(opts[:token], params.repo_owner, :fork, fn client ->
      client
      |> Tentacat.Repositories.Forks.create(
        params.repo_owner,
        params.repo_name,
        %{}
      )
      |> case do
        {202, payload, _} ->
          log_success("forking #{params.repo_owner}/#{params.repo_name}")

          %{
            url: payload["git_url"]
          }
          |> wrap()

        {307, _, response} ->
          fail_with(:precondition, "There was a problem with creating a fork. #{fetch_status_message(response)}")

        {status, _, resp} ->
          log_error([
            "forking #{params.repo_owner}/#{params.repo_name}",
            "status: #{status}",
            "response: #{inspect_response(resp)}"
          ])

          fail_with(:precondition, "There was a problem with creating a fork, please try again.")
      end
    end)
  end

  @impl true
  def get_reference(%{reference: "refs/heads/" <> branch_name} = params, opts) do
    params |> Map.put(:branch_name, branch_name) |> get_branch(opts)
  end

  @impl true
  def get_reference(%{reference: "refs/tags/" <> tag_name} = params, opts) do
    params |> Map.put(:tag_name, tag_name) |> get_tag(opts)
  end

  @doc """
  https://docs.github.com/en/rest/branches/branches?apiVersion=2022-11-28#get-a-branch
  """
  @impl true
  def get_branch(params, opts \\ []) do
    {owner, repo, branch_name} = {params.repo_owner, params.repo_name, params.branch_name}

    with_client(opts[:token], owner, :get_branch, fn client ->
      Tentacat.Repositories.Branches.find(client, owner, repo, branch_name)
      |> case do
        {200, payload, _} ->
          %{
            type: "branch",
            sha: payload["commit"]["sha"]
          }
          |> wrap

        {301, _, response} ->
          fail_with(:precondition, "Branch moved permanently. #{fetch_status_message(response)}")

        {404, _, _response} ->
          fail_with(:not_found, "Branch not found.")

        {status, _, response} ->
          log_error([
            "getting branch #{owner}/#{repo} : #{branch_name}}",
            "status: #{status}",
            "response: #{inspect_response(response)}"
          ])

          fail_with(
            :precondition,
            "Error while looking up branch #{owner}/#{repo} : #{branch_name}. #{fetch_status_message(response)}"
          )
      end
    end)
  end

  @doc """
  https://docs.github.com/en/rest/repos/repos?apiVersion=2022-11-28#list-repository-tags
  """
  @impl true
  def get_tag(params, opts \\ []) do
    {owner, repo, tag_name} = {params.repo_owner, params.repo_name, params.tag_name}

    with_client(opts[:token], owner, :get_tag, fn client ->
      Tentacat.Repositories.Tags.list(client, owner, repo)
      |> case do
        {200, payload, _} ->
          response_tag = Enum.find(payload, fn tag -> tag["name"] == tag_name end)

          if response_tag do
            %{
              type: "tag",
              sha: response_tag["commit"]["sha"]
            }
            |> wrap
          else
            fail_with(:not_found, "Tag not found.")
          end

        {404, _, _response} ->
          fail_with(:not_found, "Commit not found.")

        {422, _, response} ->
          fail_with(:not_found, "Validation failed. #{fetch_status_message(response)}")

        {status, _, response} ->
          log_error([
            "fetching tag #{params.repo_owner}/#{params.repo_name} : #{params.tag_name}",
            "status: #{status}",
            "response: #{inspect_response(response)}"
          ])

          fail_with(
            :precondition,
            "Error while looking up repository #{owner}/#{repo}. #{fetch_status_message(response)}"
          )
      end
    end)
  end

  @doc """
  https://docs.github.com/en/rest/commits/commits?apiVersion=2022-11-28#get-a-commit
  """
  @impl true
  def get_commit(params, opts \\ []) do
    {owner, repo, commit_sha} = {params.repo_owner, params.repo_name, params.commit_sha}

    with_client(opts[:token], owner, :get_commit, fn client ->
      try do
        Tentacat.Commits.find(client, commit_sha, owner, repo)
        |> case do
          {200, payload, _} when is_map(payload) ->
            %{
              sha: get_in(payload, ["sha"]),
              message: get_in(payload, ["commit", "message"]),
              author_name: get_in(payload, ["author", "login"]) || "",
              author_uuid: get_in(payload, ["author", "id"]) || "",
              author_avatar_url: get_in(payload, ["author", "avatar_url"]) || ""
            }
            |> wrap()

          {200, [{200, payload, _resp} | _], _} ->
            %{
              sha: get_in(payload, ["sha"]),
              message: get_in(payload, ["commit", "message"]),
              author_name: get_in(payload, ["author", "login"]) || "",
              author_uuid: get_in(payload, ["author", "id"]) || "",
              author_avatar_url: get_in(payload, ["author", "avatar_url"]) || ""
            }
            |> wrap()

          {status, _, response} ->
            log_error([
              "fetching tag #{params.repo_owner}/#{params.repo_name} : #{params.tag_name}",
              "status: #{status}",
              "response: #{inspect_response(response)}"
            ])

            fail_with(
              :precondition,
              "Error while looking up repository #{owner}/#{repo}. #{fetch_status_message(response)}"
            )
        end
      rescue
        error ->
          log_error([
            "Error while looking up repository #{owner}/#{repo}.",
            "error: #{inspect(error)}"
          ])

          fail_with(:precondition, "Error while looking up repository #{owner}/#{repo}.")
      end
    end)
  end

  defp fetch_status_message(response) do
    with error_messages <- fetch_errors(response),
         info_messages <- fetch_message(response) do
      error_messages ++ info_messages
    end
    |> Enum.join(" ")
  end

  defp fetch_errors(response) do
    response
    |> case do
      %{body: %{"errors" => errors}} when is_list(errors) ->
        errors
        |> Enum.map(fn
          %{"message" => message} when is_bitstring(message) ->
            message

          _ ->
            nil
        end)
        |> Enum.filter(& &1)

      _ ->
        []
    end
  end

  defp fetch_message(response) do
    response
    |> case do
      %{body: %{"message" => message}} when is_bitstring(message) ->
        [message]

      _ ->
        []
    end
  end

  defp with_client(token, owner, purpose, fun) do
    client = Tentacat.Client.new(%{access_token: token})

    case get_remaining_rate_limit(client) do
      {:ok, remaining_rate_limit} ->
        limit = @limits[purpose]

        if remaining_rate_limit > limit do
          Watchman.increment({"github_api.rate_limit.ok", [owner]})
          fun.(client)
        else
          Watchman.increment({"github_api.rate_limit.error", [owner]})

          log_error(
            "Failed to connect to GitHub. purpose=#{purpose} owner=#{owner} limit=#{limit} remaining_rate_limit=#{remaining_rate_limit}"
          )

          {:error, :rate_limit}
        end

      e ->
        e
    end
  end

  defp get_remaining_rate_limit(client) do
    case Tentacat.get("rate_limit", client) do
      {200, body, _} ->
        {:ok, get_in(body, ["rate", "remaining"])}

      {401, _, _} ->
        fail_with(:precondition, @err_not_authorized)

      {status, body, _} ->
        log_error("Failed to get the rate limit status=#{status} body=#{inspect(body)}")

        # if we can't find the limit, assume something very low
        {:ok, 100}
    end
  end

  defp inspect_response(response) do
    request_headers =
      response
      |> Map.get(:request, %{})
      |> Map.get(:headers, [])
      |> Enum.reject(fn {key, _} ->
        key == "Authorization" || key == "authorization"
      end)

    inspect(%{response | request: %{response.request | headers: request_headers}})
  end

  defmodule Webhook do
    def url(project_id) do
      host = Application.fetch_env!(:repository_hub, :webhook_host)

      "https://hooks.#{host}/github?hash_id=#{project_id}"
    end

    def events do
      ["issue_comment", "member", "pull_request", "push"]
    end
  end
end
