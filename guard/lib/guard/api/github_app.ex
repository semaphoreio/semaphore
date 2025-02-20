defmodule Guard.Api.GithubApp do
  require Logger

  def client do
    middleware = [
      {Tesla.Middleware.BaseUrl, "https://api.github.com"},
      {Tesla.Middleware.Headers, [{"Accept", "application/vnd.github+json"}]},
      {Tesla.Middleware.JSON, []}
    ]

    Tesla.client(middleware)
  end

  def client(jwt) do
    middleware =
      Tesla.Client.middleware(client()) ++
        [
          {Tesla.Middleware.Headers,
           [{"Authorization", "Bearer #{jwt}"}, {"X-GitHub-Api-Version", "2022-11-28"}]}
        ]

    Tesla.client(middleware)
  end

  def fetch(code) do
    case Tesla.post(client(), "/app-manifests/#{code}/conversions", %{}) do
      {:ok, res} ->
        if res.status in 200..299 do
          {:ok,
           %{
             slug: res.body["slug"],
             app_id: res.body["id"] |> Integer.to_string(),
             name: res.body["name"],
             client_id: res.body["client_id"],
             client_secret: res.body["client_secret"],
             pem: res.body["pem"],
             html_url: res.body["html_url"],
             webhook_secret: res.body["webhook_secret"]
           }}
        else
          Logger.debug("errored fetching github app: #{inspect(res.body)}")

          {:error,
           "Failed to fetch Github App info: #{res.body["message"]}. #{res.body["documentation_url"]}"}
        end

      {:error, error} ->
        {:error, error}

      e ->
        Logger.error("[fetch] Failed to fetch Github App info: #{inspect(e)}")
        {:error, "Failed to fetch Github App info"}
    end
  end

  def get(%{app_id: app_id, pem: pem}) do
    with {:ok, jwt, _} <- generate_jwt(app_id, pem),
         {:ok, res} <- Tesla.get(client(jwt), "/app"),
         status when status in 200..299 <- res.status do
      {:ok, res.body}
    else
      {:error, reason} ->
        Logger.error("[state_check] Failed to fetch Github App state: #{inspect(reason)}")
        {:error, "Failed to fetch Github App info, credentials might be invalid"}

      status ->
        Logger.error("[state_check] Github App info, stauts code: #{inspect(status)}")
        {:error, "Github App missconfigured"}
    end
  end

  defp generate_jwt(app_id, pem) do
    alias Joken

    current_time = Joken.current_time() - 60
    expiration_time = current_time + 7 * 60

    claims = %{
      iat: current_time,
      exp: expiration_time,
      iss: app_id,
      alg: "RS256"
    }

    Joken.encode_and_sign(claims, Joken.Signer.create("RS256", %{"pem" => pem}))
  end
end
