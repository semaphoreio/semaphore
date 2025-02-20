defmodule RepositoryHub.WebhookEncryptor.BitbucketClient do
  @moduledoc """
  Bitbucket API client for webhook encryption.
  """

  # credo:disable-for-this-file

  @base_url "https://api.bitbucket.org/2.0/repositories"
  @headers [{"accept", "application/json"}]
  @adapter Tesla.Adapter.Hackney

  @spec new(String.t()) :: Tesla.Client.t()
  def new(token) do
    adapter = Application.get_env(:tesla, :adapter, @adapter)
    Tesla.client(middleware_from_token(token), adapter)
  end

  @spec create_webhook(Tesla.Client.t(), map()) :: {:ok, map()} | {:error, any()}
  def create_webhook(client, params) do
    client
    |> Tesla.post("/#{params.owner}/#{params.repo}/hooks", %{
      "description" => "Semaphore CI",
      "url" => params.url,
      "events" => params.events,
      "active" => true,
      "secret" => params.secret
    })
    |> resolve(fn
      %Tesla.Env{status: 201, body: body} ->
        {:ok, %{id: body["uuid"], url: body["url"]}}

      %Tesla.Env{status: 403, body: body} ->
        {:error, {:forbidden, body}}

      %Tesla.Env{status: 404, body: body} ->
        {:error, {:not_found, body}}

      %Tesla.Env{status: 422, body: body} ->
        {:error, {:unprocessable, body}}

      %Tesla.Env{status: _} = env ->
        {:error, env}
    end)
  end

  @spec remove_webhook(Tesla.Client.t(), map()) :: {:ok, map()} | {:error, any()}
  def remove_webhook(client, params) do
    client
    |> Tesla.delete("/#{params.owner}/#{params.repo}/hooks/#{params.hook_id}")
    |> resolve(fn
      %Tesla.Env{status: 204} ->
        {:ok, %{id: params.hook_id}}

      %Tesla.Env{status: 404} ->
        {:ok, %{id: params.hook_id}}

      %Tesla.Env{status: _} = env ->
        {:error, env}
    end)
  end

  defp middleware_from_token(token) do
    [
      {Tesla.Middleware.BaseUrl, @base_url},
      {Tesla.Middleware.Headers, @headers},
      {Tesla.Middleware.BearerAuth, token: token},
      Tesla.Middleware.JSON,
      RepositoryHub.WebhookEncryptor.RateLimit
    ]
  end

  defp resolve({:ok, %Tesla.Env{} = response}, callback_fn), do: callback_fn.(response)
  defp resolve({:error, reason}, _callback_fn), do: {:error, reason}
end
