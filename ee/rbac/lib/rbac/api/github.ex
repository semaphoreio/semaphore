defmodule Rbac.Api.Github do
  require Logger

  use Tesla

  plug(Tesla.Middleware.BaseUrl, "https://api.github.com")
  plug(Tesla.Middleware.JSON)

  def user(id) do
    case get("/user/" <> id) do
      {:ok, res} ->
        if res.status in 200..299 do
          {:ok, %{id: res.body["id"] |> Integer.to_string(), login: res.body["login"]}}
        else
          Logger.debug("Error fetching user: #{inspect(res.body)}")

          {:error, "#{res.body["message"]}. #{res.body["documentation_url"]}"}
        end

      {:error, error} ->
        {:error, error}
    end
  end
end
