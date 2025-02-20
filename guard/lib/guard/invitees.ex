defmodule Guard.Invitees do
  require Logger

  def inject_provider_uid(invitees, inviter_id) when is_list(invitees) do
    Enum.reduce_while(invitees, {:ok, []}, fn cur, {:ok, acc} ->
      case inject_provider_uid(cur, inviter_id) do
        {:ok, invitee} -> {:cont, {:ok, acc ++ [invitee]}}
        e -> {:halt, e}
      end
    end)
  end

  def inject_provider_uid(%{provider: %{uid: uid}} = invitee, _inviter_id)
      when is_binary(uid) and uid != "",
      do: {:ok, invitee}

  def inject_provider_uid(invitee, inviter_id) do
    case invitee.provider.type do
      :GITHUB -> inject_github_uid(invitee, inviter_id)
      :GITLAB -> inject_gitlab_uid(invitee, inviter_id)
      _ -> {:error, "provider #{invitee.provider.type} not supported"}
    end
  end

  def inject_github_uid(invitee, inviter_id) do
    case extract_github_uid(invitee.provider.login, inviter_id) do
      {:ok, uid} ->
        provider = Map.merge(invitee.provider, %{uid: uid})
        {:ok, Map.merge(invitee, %{provider: provider})}

      e ->
        e
    end
  end

  def inject_gitlab_uid(invitee, inviter_id) do
    case extract_gitlab_uid(invitee.provider.login, inviter_id) do
      {:ok, uid} ->
        provider = Map.merge(invitee.provider, %{uid: uid})
        {:ok, Map.merge(invitee, %{provider: provider})}

      e ->
        e
    end
  end

  defp extract_github_uid(login, inviter) do
    case get_github_uid(login) do
      {:ok, uid} when not is_nil(uid) ->
        {:ok, uid}

      _ ->
        extract_uid_from_github(login, inviter)
    end
  end

  defp extract_gitlab_uid(login, inviter) do
    case get_gitlab_uid(login) do
      {:ok, uid} when not is_nil(uid) ->
        {:ok, uid}

      _ ->
        extract_uid_from_gitlab(login, inviter)
    end
  end

  defp extract_uid_from_github("", _inviter_id), do: {:error, "empty login not allowed"}

  defp extract_uid_from_github(login, inviter_id) do
    with {:ok, resource} <- resource(login, "github"),
         {:ok, api_token} <- get_api_token(inviter_id, "github"),
         {:ok, http_response} <- http_call(resource, api_token, "github") do
      extract_uid(login, http_response)
    else
      e ->
        Logger.error("Error extracting github uid for #{inspect(login)}: #{inspect(e)}")
        {:error, "error finding Github ID for #{login}"}
    end
  end

  defp extract_uid_from_gitlab("", _inviter_id), do: {:error, "empty login not allowed"}

  defp extract_uid_from_gitlab(login, inviter_id) do
    with {:ok, resource} <- resource(login, "gitlab"),
         {:ok, api_token} <- get_api_token(inviter_id, "gitlab"),
         {:ok, http_response} <- http_call(resource, api_token, "gitlab") do
      extract_uid(login, http_response)
    else
      e ->
        Logger.error("Error extracting gitlab uid for #{inspect(login)}: #{inspect(e)}")
        {:error, "error finding Gitlab ID for #{login}"}
    end
  end

  defp resource(login, host) do
    case host do
      "github" -> "https://api.github.com/users/#{login}"
      "gitlab" -> "https://gitlab.com/api/v4/users?username=#{login}"
    end
    |> return_ok_tuple()
  end

  defp get_api_token(inviter_id, "github") do
    Guard.FrontRepo.RepoHostAccount.get_github_token(inviter_id)
  end

  defp get_api_token(inviter_id, "gitlab") do
    case Guard.FrontRepo.RepoHostAccount.get_gitlab_token(inviter_id) do
      {:ok, {token, _expires_at}} -> {:ok, token}
      _ -> {:error, "error finding Gitlab token for #{inviter_id}"}
    end
  end

  defp get_api_token(_, provider) do
    {:error, "Provider #{provider} not supported for token extraction"}
  end

  defp get_github_uid(login) do
    Guard.FrontRepo.RepoHostAccount.get_uid_by_login(login, "github")
  end

  defp get_gitlab_uid(login) do
    Guard.FrontRepo.RepoHostAccount.get_uid_by_login(login, "gitlab")
  end

  defp http_call(resource, api_token, "github") do
    resource |> HTTPoison.get([{"Authorization", "Token #{api_token}"}])
  end

  defp http_call(resource, api_token, "gitlab") do
    resource |> HTTPoison.get([{"PRIVATE-TOKEN", api_token}])
  end

  defp extract_uid(_, %{status_code: 200, body: body}) do
    with {:ok, body} <- body |> Jason.decode(),
         {:ok, id} <- body |> Map.fetch("id"),
         do: id |> Integer.to_string() |> return_ok_tuple()
  end

  defp extract_uid(login, %{status_code: status_code}),
    do: {:error, "error finding #{login}: #{status_code}"}

  defp return_ok_tuple(value), do: {:ok, value}
end
