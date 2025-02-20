defmodule Guard.Api.Github do
  require Logger

  use Tesla

  plug(Tesla.Middleware.BaseUrl, "https://api.github.com")
  plug(Tesla.Middleware.JSON)

  def user(id) do
    case get("/user/" <> id) do
      {:ok, res} ->
        cond do
          res.status in 200..299 ->
            {:ok, %{id: res.body["id"] |> Integer.to_string(), login: res.body["login"]}}

          res.status == 404 ->
            Logger.debug("Error fetching user: #{inspect(res.body)}")

            {:error, :not_found}

          true ->
            Logger.debug("Error fetching user: #{inspect(res.body)}")

            {:error, "#{res.body["message"]}. #{res.body["documentation_url"]}"}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  def validate_token(""), do: false

  def validate_token(token) do
    {:ok, {client_id, client_secret}} = Guard.GitProviderCredentials.get(:github)

    body = %{"access_token" => token}

    case post("/applications/#{client_id}/token", body,
           headers: authorization_headers(client_id, client_secret)
         ) do
      {:ok, res} ->
        is_valid = res.status in 200..299

        unless is_valid do
          Logger.error(
            "Token validation failed. status: #{res.status} body: #{inspect(res.body)}"
          )
        end

        {:ok, is_valid}

      {:error, error} ->
        Logger.error("Error validating token: #{inspect(error)}")
        {:error, :network_error}
    end
  end

  defp authorization_headers(client_id, client_secret) do
    [
      {"Accept", "application/vnd.github+json"},
      {"Authorization", "Basic " <> Base.encode64("#{client_id}:#{client_secret}")},
      {"X-GitHub-Api-Version", "2022-11-28"}
    ]
  end
end
