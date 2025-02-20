defmodule RepositoryHub.WebhookEncryptor.WorkerSupervisor do
  @moduledoc """
  Supervises webhook encryption workers and starts them asynchronously (from the caller side).
  """

  @spec child_spec(keyword()) :: map()
  def child_spec(_args) do
    %{id: __MODULE__, start: {Task.Supervisor, :start_link, [[name: __MODULE__]]}}
  end
end

defmodule RepositoryHub.WebhookEncryptor.Worker do
  @moduledoc """
  Updates the webhook for a repository.

  Firstly, encryption secret is created, and then we run a transaction that:
  - locks the repository for update
  - creates a new webhook
  - updates the repository with the new webhook id and the encrypted secret

  If any of the steps fail, we log the error and abort the process or retry the task.
  Most common reasons for retrying are rate limits, which should be handled by the caller.
  If transaction fails after the webhook was created, we abort to process it manually.
  """

  alias RepositoryHub.WebhookEncryptor.WorkerSupervisor
  alias RepositoryHub.WebhookEncryptor.BitbucketClient
  alias RepositoryHub.WebhookEncryptor.GithubClient
  alias RepositoryHub.WebhookEncryptor.RateLimitError
  alias RepositoryHub.Model.Repositories

  require Logger

  @internal_wait_time 10
  @external_wait_time 60

  @doc """
  Start a new encryption worker under Task.Supervisor
  """
  @spec perform_async(event :: map) :: Task.t()
  def perform_async(event),
    do: Task.Supervisor.async_nolink(WorkerSupervisor, fn -> perform(event) end)

  @doc """
  Process the event and update the webhook for the repository.
  """
  @spec perform(event :: map, opts :: keyword()) :: {:ok, map()} | {:retry, integer} | {:abort, any}
  def perform(%{repository_id: repo_id, project_id: project_id} = event, opts \\ []) do
    with {:ok, _event} <- validate_event(event),
         {:ok, secret} <- generate_secret(repo_id),
         {:ok, result} <- run_transaction(event, secret, opts) do
      try_removing_old_hook_and_log_result(result.old_repo, event.token)
      Logger.info(log(event.project_id, "✅ Processing repository finished"))
      {:ok, event}
    else
      {:error, :not_found = reason} ->
        Logger.warning(log(project_id, "🖐🏻 Repository not found"))
        {:abort, reason}

      {:error, :encryption_done = reason} ->
        Logger.warning(log(project_id, "🖐🏻 Repository already encrypted"))
        {:abort, reason}

      {:error, {:event, reason}} ->
        Logger.error(log(project_id, "❌ Invalid event: #{inspect(reason)}"))
        {:abort, reason}

      {:error, {:secret, reason}} ->
        Logger.error(log(project_id, "❌ Generating secret failed: #{inspect(reason)}"))
        {:retry, @internal_wait_time}

      {:error, {:repo, reason}} ->
        Logger.error(log(project_id, "❌ Locking repository failed: #{inspect(reason)}"))
        {:retry, @internal_wait_time}

      {:error, {:webhook, {reason, body}}} when is_atom(reason) ->
        Logger.error(log(project_id, "❌ Creating new webhook failed [#{reason}]: #{inspect(body)}"))
        {:abort, reason}

      {:error, {:webhook, %RateLimitError{} = error}} ->
        Logger.error(log(project_id, "❌ Creating new webhook failed: #{inspect(error)}"))
        {:retry, RateLimitError.wait_time(error)}

      {:error, {:webhook, %Tesla.Env{status: status, body: body}}} ->
        error_message = "HTTP Status #{status}: #{inspect(body)}"
        Logger.error(log(project_id, "❌ Creating new webhook failed: #{error_message}"))
        {:retry, @internal_wait_time}

      {:error, reason} ->
        Logger.error(log(project_id, "❌ Unknown error: #{inspect(reason)}"))
        {:retry, @external_wait_time}
    end
  end

  defp validate_event(event) do
    event
    |> RepositoryHub.Validator.validate(
      all: [
        chain: [
          {:from!, [:git_repository, :owner]},
          :is_string,
          :is_not_empty,
          error_message: "owner is required"
        ],
        chain: [
          {:from!, [:git_repository, :name]},
          :is_string,
          :is_not_empty,
          error_message: "name is required"
        ],
        chain: [
          {:from!, :integration_type},
          :is_string,
          :is_not_empty,
          check: &valid_integration_type?/1,
          error_message: "integration_type is invalid"
        ],
        chain: [
          {:from!, :repository_id},
          :is_string,
          :is_uuid,
          error_message: "repository_id is not valid"
        ],
        chain: [
          {:from!, :project_id},
          :is_string,
          :is_uuid,
          error_message: "project_id is not valid"
        ],
        chain: [
          {:from!, :token},
          :is_string,
          :is_not_empty,
          error_message: "token is required"
        ]
      ]
    )
    |> case do
      {:ok, event} -> {:ok, event}
      {:error, reason} -> {:error, {:event, reason}}
    end
  end

  defp valid_integration_type?(type),
    do: Enum.member?(["github_oauth_token", "github_app", "bitbucket"], type)

  defp generate_secret(repository_id) do
    case Repositories.generate_hook_secret(%Repositories{id: repository_id}) do
      {:ok, {raw_secret, enc_secret}} when is_binary(enc_secret) and enc_secret != "" ->
        {:ok, %{raw: raw_secret, enc: enc_secret}}

      {:ok, {_raw_secret, _enc_secret}} ->
        {:error, {:secret, "encrypted secret is not a non-empty string"}}

      {:error, reason} ->
        {:error, {:secret, reason}}
    end
  end

  defp run_transaction(event, secret, opts) do
    Ecto.Multi.new()
    |> Ecto.Multi.put(:secret, secret)
    |> Ecto.Multi.run(:old_repo, fn _repo, _result ->
      lock_repository(event.repository_id)
    end)
    |> Ecto.Multi.run(:new_webhook, fn _repo, result ->
      create_new_webhook(event, result.secret)
    end)
    |> Ecto.Multi.update(:new_repo, fn result ->
      Repositories.changeset(result.old_repo, %{
        hook_id: result.new_webhook.id,
        hook_secret_enc: secret.enc
      })
    end)
    |> RepositoryHub.Repo.transaction(opts)
    |> case do
      {:ok, result} -> {:ok, result}
      {:error, :old_repo, :not_found, _changes} -> {:error, :not_found}
      {:error, :old_repo, :encryption_done, _changes} -> {:error, :encryption_done}
      {:error, :old_repo, reason, _changes} -> {:error, {:repo, reason}}
      {:error, :new_webhook, reason, _changes} -> {:error, {:webhook, reason}}
      {:error, :new_repo, reason, _changes} -> {:error, {:repo, reason}}
    end
  rescue
    e -> {:error, e}
  end

  def lock_repository(repo_id) do
    require Ecto.Query

    Ecto.Query.from(Repositories)
    |> Ecto.Query.where(id: ^repo_id)
    |> Ecto.Query.where([r], is_nil(r.hook_secret_enc) and not is_nil(r.hook_id))
    |> Ecto.Query.lock("FOR UPDATE")
    |> Ecto.Query.limit(1)
    |> RepositoryHub.Repo.one()
    |> case do
      %Repositories{hook_secret_enc: nil} = repo -> {:ok, repo}
      %Repositories{} = _repo -> {:error, :encryption_done}
      nil -> {:error, :not_found}
    end
  end

  defp create_new_webhook(event, secret) do
    case event.integration_type do
      "github_oauth_token" -> create_github_webhook(event, secret)
      "github_app" -> create_github_webhook(event, secret)
      "bitbucket" -> create_bitbucket_webhook(event, secret)
      type -> {:error, {:integration_type, type}}
    end
  end

  defp create_github_webhook(event, secret) do
    GithubClient.create_webhook(
      GithubClient.new(event.token),
      %{
        owner: event.git_repository.owner,
        repo: event.git_repository.name,
        url: RepositoryHub.GithubClient.Webhook.url(event.project_id),
        events: RepositoryHub.GithubClient.Webhook.events(),
        secret: secret.raw
      }
    )
  end

  defp create_bitbucket_webhook(event, secret) do
    BitbucketClient.create_webhook(
      BitbucketClient.new(event.token),
      %{
        owner: event.git_repository.owner,
        repo: event.git_repository.name,
        url: RepositoryHub.BitbucketClient.Webhook.url(event.org_username, event.repository_id),
        events: RepositoryHub.BitbucketClient.Webhook.events(),
        secret: secret.raw
      }
    )
  end

  # removing old webhook

  defp try_removing_old_hook_and_log_result(old_repo, token) do
    case remove_old_webhook(old_repo, token) do
      {:ok, %{id: old_hook_id}} ->
        Logger.info(log(old_repo.id, "Removed old webhook (#{old_hook_id})"))

      {:error, reason} ->
        Logger.error(log(old_repo.id, "Removing old webhook failed: #{inspect(reason)}"))
    end
  end

  defp remove_old_webhook(%Repositories{hook_id: nil}, _token), do: {:ok, %{id: nil}}

  defp remove_old_webhook(%Repositories{} = old_repo, token) do
    case old_repo.integration_type do
      "github_oauth_token" -> remove_github_webhook(old_repo, token)
      "github_app" -> remove_github_webhook(old_repo, token)
      "bitbucket" -> remove_bitbucket_webhook(old_repo, token)
    end
  end

  defp remove_github_webhook(old_repo, token),
    do: GithubClient.remove_webhook(GithubClient.new(token), remove_webhook_params(old_repo))

  defp remove_bitbucket_webhook(old_repo, token),
    do: BitbucketClient.remove_webhook(BitbucketClient.new(token), remove_webhook_params(old_repo))

  defp remove_webhook_params(%Repositories{} = old_repo),
    do: %{owner: old_repo.owner, repo: old_repo.name, hook_id: old_repo.hook_id}

  # other helpers

  defp log(project_id, message) do
    "[WebhookEncryptor][EncryptionWorker] {#{project_id}} #{message}"
  end
end
