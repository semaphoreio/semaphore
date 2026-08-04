defmodule Ueberauth.Strategy.Bitbucket.OAuth do
  @moduledoc """
  An implementation of OAuth2 for bitbucket.

  Vendored from the ueberauth_bitbucket package (MIT).

  To add your `client_id` and `client_secret` include these values in your configuration.

      config :ueberauth, Ueberauth.Strategy.Bitbucket.OAuth,
        client_id: System.get_env("BITBUCKET_CLIENT_ID"),
        client_secret: System.get_env("BITBUCKET_CLIENT_SECRET")
  """
  use OAuth2.Strategy

  @defaults [
    strategy: __MODULE__,
    site: "https://api.bitbucket.org/2.0",
    authorize_url: "https://bitbucket.org/site/oauth2/authorize",
    token_url: "https://bitbucket.org/site/oauth2/access_token"
  ]

  @doc """
  Construct a client for requests to Bitbucket.

  Optionally include any OAuth2 options here to be merged with the defaults.

      Ueberauth.Strategy.Bitbucket.OAuth.client(redirect_uri: "http://localhost:4000/auth/bitbucket/callback")

  This will be setup automatically for you in `Ueberauth.Strategy.Bitbucket`.
  These options are only useful for usage outside the normal callback phase of Ueberauth.
  """
  def client(opts \\ []) do
    opts =
      Keyword.merge(
        @defaults,
        Application.get_env(:ueberauth, Ueberauth.Strategy.Bitbucket.OAuth)
      )
      |> Keyword.merge(opts)

    json_library = Ueberauth.json_library()

    OAuth2.Client.new(opts)
    |> OAuth2.Client.put_serializer("application/json", json_library)
  end

  @doc """
  Provides the authorize url for the request phase of Ueberauth. No need to call this usually.
  """
  def authorize_url!(params \\ [], opts \\ []) do
    client(opts)
    |> OAuth2.Client.authorize_url!(params)
  end

  def get(token, url, headers \\ [], opts \\ []) do
    client(token: token)
    |> put_param("client_secret", client.client_secret)
    |> OAuth2.Client.get(url, headers, opts)
  end

  def get_token!(params \\ [], options \\ []) do
    headers = Keyword.get(options, :headers, [])
    options = Keyword.get(options, :options, [])
    client_options = Keyword.get(options, :client_options, [])
    merged_params = params ++ [grant_type: "authorization_code"]

    client =
      OAuth2.Client.get_token!(client(client_options), merged_params, headers, options)

    client.token
  end

  # Strategy Callbacks

  def authorize_url(client, params) do
    OAuth2.Strategy.AuthCode.authorize_url(client, params)
  end

  def get_token(client, params, headers) do
    client
    |> put_param("client_secret", client.client_secret)
    |> put_header("Accept", "application/json")
    |> OAuth2.Strategy.AuthCode.get_token(params, headers)
  end
end
