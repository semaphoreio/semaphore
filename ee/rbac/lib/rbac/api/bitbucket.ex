defmodule Rbac.Api.Bitbucket do
  require Logger
  use Tesla

  @base_url "https://bitbucket.org"
  @api_v2_path "/api/2.0"

  plug(Tesla.Middleware.BaseUrl, @base_url)
  plug(Tesla.Middleware.JSON)

  def user(id) do
    case get("#{@api_v2_path}/users/#{id}") do
      {:ok, res} ->
        if res.status in 200..299 do
          {:ok,
           %{
             id: res.body["uuid"],
             login: res.body["nickname"],
             account_id: res.body["account_id"]
           }}
        else
          Logger.debug("Error fetching user: #{inspect(res.body)}")
          {:error, "#{res.body["error"]["message"]}"}
        end

      {:error, error} ->
        {:error, error}
    end
  end
end
