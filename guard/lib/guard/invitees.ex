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

  defp inject_github_uid(invitee, inviter_id) do
    case extract_provider_uid(invitee.provider.login, inviter_id, "github") do
      {:ok, uid} ->
        provider = Map.merge(invitee.provider, %{uid: uid})
        {:ok, Map.merge(invitee, %{provider: provider})}

      e ->
        e
    end
  end

  defp inject_gitlab_uid(invitee, inviter_id) do
    case extract_provider_uid(invitee.provider.login, inviter_id, "gitlab") do
      {:ok, uid} ->
        provider = Map.merge(invitee.provider, %{uid: uid})
        {:ok, Map.merge(invitee, %{provider: provider})}

      e ->
        e
    end
  end

  defp extract_provider_uid(login, inviter, provider) do
    case get_provider_uid(login, provider) do
      {:ok, uid} when not is_nil(uid) ->
        {:ok, uid}

      _ ->
        extract_uid_from_provider(login, inviter, provider)
    end
  end

  defp extract_uid_from_provider("", _inviter_id, _), do: {:error, "empty login not allowed"}

  defp extract_uid_from_provider(login, inviter_id, provider) do
    with {:ok, resource} <- resource(login, provider),
         {:ok, rha} <- maybe_get_rha(inviter_id, provider),
         {:ok, api_token} <- maybe_get_api_token(rha, provider),
         {:ok, http_response} <- http_call(resource, api_token, provider) do
      extract_uid(login, http_response, provider)
    else
      e ->
        Logger.error(
          "[Invitees] Error extracting #{provider} uid for #{inspect(login)}: #{inspect(e)}"
        )

        {:error, "error finding #{provider} ID for #{login}"}
    end
  end

  defp resource(login, host) do
    case host do
      "github" -> "https://api.github.com/users/#{login}"
      "gitlab" -> "https://gitlab.com/api/v4/users?username=#{login}"
    end
    |> return_ok_tuple()
  end

  defp maybe_get_rha(inviter_id, provider) do
    case Guard.FrontRepo.RepoHostAccount.get_for_user_by_repo_host(inviter_id, provider) do
      {:ok, rha} ->
        {:ok, rha}

      e ->
        Logger.warning(
          "[Invitees] Missing RHA for inviter #{inviter_id} and #{provider}, #{inspect(e)}"
        )

        {:ok, nil}
    end
  end

  defp maybe_get_api_token(nil, _), do: {:ok, nil}

  defp maybe_get_api_token(rha, provider) do
    case get_api_token(rha, provider) do
      {:ok, {token, _expires_at}} ->
        {:ok, token}

      e ->
        Logger.warning(
          "[Invitees] Missing token for rha #{inspect(rha)} and #{provider}, #{inspect(e)}"
        )

        {:ok, nil}
    end
  end

  defp get_api_token(rha, "github") do
    Guard.FrontRepo.RepoHostAccount.get_github_token(rha)
  end

  defp get_api_token(_, _), do: {:ok, {"", nil}}

  defp get_provider_uid(login, provider) do
    Guard.FrontRepo.RepoHostAccount.get_uid_by_login(login, provider)
  end

  defp http_call(resource, token, "github") when is_binary(token) and token != "" do
    HTTPoison.get(resource, [{"Authorization", "Token #{token}"}])
  end

  defp http_call(resource, _, _), do: HTTPoison.get(resource, [])

  defp extract_uid(_, %{status_code: 200, body: body}, _) do
    with {:ok, body} <- body |> Jason.decode(),
         {:ok, id} <- fetch_id(body),
         do: id |> Integer.to_string() |> return_ok_tuple()
  end

  defp extract_uid(login, %{status_code: status_code}, _),
    do: {:error, "error finding #{login}: #{status_code}"}

  defp fetch_id(%{"id" => id}), do: {:ok, id}

  defp fetch_id([%{"id" => id} | _rest]), do: {:ok, id}

  defp fetch_id(body), do: {:error, "error finding id in the body #{inspect(body)}"}

  defp return_ok_tuple(value), do: {:ok, value}
end
