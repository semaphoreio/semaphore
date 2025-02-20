defmodule Front.Clients.Support do
  alias Front.Support.HelpscoutRequest, as: Request
  require Logger

  @doc """
  This module is an abstraction on top of a service used for support requests.
  Currently it is HelpScout. For this purpose, we've created `semaphore-2.0`
  OAuth2 application in the HelpScout settings.
  """
  def submit_request(form_input) do
    url = "https://api.helpscout.net/v2/conversations"
    body = Request.compose(form_input)

    headers = [
      Authorization: "Bearer #{get_token()}",
      "Content-type": "application/json"
    ]

    {:ok, response} = HTTPoison.post(url, body, headers, [])

    case response.status_code do
      200 ->
        Watchman.increment("support.submit_request.success")
        {:ok, response}

      201 ->
        Watchman.increment("support.submit_request.success")
        {:ok, response}

      204 ->
        Watchman.increment("support.submit_request.success")
        {:ok, response}

      _code ->
        Watchman.increment("support.submit_request.error")

        Logger.error(
          "Sending support request failed: #{inspect(response)}, #{inspect(construct_log(form_input))}"
        )

        {:error, "failed-to-submit"}
    end
  end

  def get_token do
    url = "https://api.helpscout.net/v2/oauth2/token"
    headers = ["Content-type": "application/json"]

    credentials = %{
      grant_type: "client_credentials",
      client_id: Application.fetch_env!(:front, :support_app_id),
      client_secret: Application.fetch_env!(:front, :support_app_secret)
    }

    body = Poison.encode!(credentials)

    {:ok, response} = HTTPoison.post(url, body, headers, [])

    response.body
    |> Poison.decode!()
    |> Map.get("access_token")
  end

  def construct_log(form_input) do
    [form_input.email, form_input.subject, form_input.body, form_input.provided_link]
    |> Enum.join("; ")
  end
end
