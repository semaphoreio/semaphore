defmodule Ueberauth.Strategy.Bitbucket do
  @moduledoc """
  Provides an Ueberauth strategy for authenticating with Bitbucket.

  Vendored from the ueberauth_bitbucket package. See `LICENSE.ueberauth_bitbucket` for its MIT license.

  ### Setup

  Create an application in Bitbucket for you to use.

  Register a new application at: [your bitbucket developer page](https://bitbucket.com/settings/developers) and get the `client_id` and `client_secret`.

  Include the provider in your configuration for Ueberauth

      config :ueberauth, Ueberauth,
        providers: [
          bitbucket: { Ueberauth.Strategy.Bitbucket, [] }
        ]

  Then include the configuration for bitbucket.

      config :ueberauth, Ueberauth.Strategy.Bitbucket.OAuth,
        client_id: System.get_env("BITBUCKET_CLIENT_ID"),
        client_secret: System.get_env("BITBUCKET_CLIENT_SECRET")

  If you haven't already, create a pipeline and setup routes for your callback handler

      pipeline :auth do
        Ueberauth.plug "/auth"
      end

      scope "/auth" do
        pipe_through [:browser, :auth]

        get "/:provider/callback", AuthController, :callback
      end


  Create an endpoint for the callback where you will handle the `Ueberauth.Auth` struct

      defmodule MyApp.AuthController do
        use MyApp.Web, :controller

        def callback_phase(%{ assigns: %{ ueberauth_failure: fails } } = conn, _params) do
          # do things with the failure
          end

        def callback_phase(%{ assigns: %{ ueberauth_auth: auth } } = conn, params) do
          # do things with the auth
        end
      end

  You can edit the behaviour of the Strategy by including some options when you register your provider.

  To set the `uid_field`

      config :ueberauth, Ueberauth,
        providers: [
          bitbucket: { Ueberauth.Strategy.Bitbucket, [uid_field: :email] }
        ]

  Default is `:uuid`

  To set the default 'scopes' (permissions):

      config :ueberauth, Ueberauth,
        providers: [
          bitbucket: { Ueberauth.Strategy.Bitbucket, [default_scope: "user,public_repo"] }
        ]

  Deafult is "user,public_repo"
  """
  use Ueberauth.Strategy,
    uid_field: :uuid,
    default_scope: "account",
    send_redirect_uri: true,
    oauth2_module: Ueberauth.Strategy.Bitbucket.OAuth

  alias Ueberauth.Auth.Info
  alias Ueberauth.Auth.Credentials
  alias Ueberauth.Auth.Extra

  @doc """
  Handles the initial redirect to the bitbucket authentication page.

  To customize the scope (permissions) that are requested by bitbucket include them as part of your url:

      "/auth/bitbucket?scope=user,public_repo,gist"

  You can also include a `state` param that bitbucket will return to you.
  """
  def handle_request!(conn) do
    opts =
      []
      |> with_scopes(conn)
      |> with_state_param(conn)
      |> with_redirect_uri(conn)

    module = option(conn, :oauth2_module)
    redirect!(conn, module.authorize_url!(opts))
  end

  @doc """
  Handles the callback from Bitbucket. When there is a failure from Bitbucket the failure is included in the
  `ueberauth_failure` struct. Otherwise the information returned from Bitbucket is returned in the `Ueberauth.Auth` struct.
  """
  def handle_callback!(%Plug.Conn{params: %{"code" => code}} = conn) do
    module = option(conn, :oauth2_module)
    token = module.get_token!(code: code, redirect_uri: callback_url(conn))

    if token.access_token == nil do
      set_errors!(conn, [
        error(token.other_params["error"], token.other_params["error_description"])
      ])
    else
      fetch_user(conn, token)
    end
  end

  @doc false
  def handle_callback!(conn) do
    set_errors!(conn, [error("missing_code", "No code received")])
  end

  @doc """
  Cleans up the private area of the connection used for passing the raw Bitbucket response around during the callback.
  """
  def handle_cleanup!(conn) do
    conn
    |> put_private(:bitbucket_user, nil)
    |> put_private(:bitbucket_token, nil)
  end

  @doc """
  Fetches the uid field from the Bitbucket response. This defaults to the option `uid_field` which in-turn defaults to `login`
  """
  def uid(conn) do
    conn.private.bitbucket_user[option(conn, :uid_field) |> to_string]
  end

  @doc """
  Includes the credentials from the Bitbucket response.
  """
  def credentials(conn) do
    token = conn.private.bitbucket_token

    scopes =
      (token.other_params["scopes"] || "")
      |> String.split(",")

    %Credentials{
      token: token.access_token,
      refresh_token: token.refresh_token,
      expires_at: token.expires_at,
      token_type: token.token_type,
      expires: not is_nil(token.expires_at),
      scopes: scopes
    }
  end

  @doc """
  Fetches the fields to populate the info section of the `Ueberauth.Auth` struct.
  """
  def info(conn) do
    user = conn.private.bitbucket_user

    %Info{
      name: user["display_name"],
      nickname: user["nickname"],
      email:
        user["email"] || Enum.find(user["emails"]["values"] || [], & &1["is_primary"])["email"],
      urls: %{
        followers_url: user["links"]["followers"]["href"],
        avatar_url: user["links"]["avatar"]["href"],
        html_url: user["links"]["html"]["href"],
        repos_url: user["links"]["repositories"]["href"]
      }
    }
  end

  @doc """
  Stores the raw information (including the token) obtained from the Bitbucket callback.
  """
  def extra(conn) do
    %Extra{
      raw_info: %{
        token: conn.private.bitbucket_token,
        user: conn.private.bitbucket_user
      }
    }
  end

  defp fetch_user(conn, token) do
    conn = put_private(conn, :bitbucket_token, token)
    # Will be better with Elixir 1.3 with/else
    case Ueberauth.Strategy.Bitbucket.OAuth.get(token, "/user") do
      {:ok, %OAuth2.Response{status_code: 401, body: _body}} ->
        set_errors!(conn, [error("token", "unauthorized")])

      {:ok, %OAuth2.Response{status_code: status_code, body: user}}
      when status_code in 200..399 ->
        case Ueberauth.Strategy.Bitbucket.OAuth.get(token, "/user/emails") do
          {:ok, %OAuth2.Response{status_code: status_code, body: emails}}
          when status_code in 200..399 ->
            user = Map.put(user, "emails", emails)
            put_private(conn, :bitbucket_user, user)

          # Continue on as before
          {:error, _} ->
            put_private(conn, :bitbucket_user, user)
        end

      {:error, %OAuth2.Error{reason: reason}} ->
        set_errors!(conn, [error("OAuth2", reason)])
    end
  end

  defp option(conn, key) do
    Keyword.get(options(conn), key, Keyword.get(default_options(), key))
  end

  defp with_scopes(opts, conn) do
    scopes = conn.params["scope"] || option(conn, :default_scope)

    opts |> Keyword.put(:scope, scopes)
  end

  defp with_redirect_uri(opts, conn) do
    if option(conn, :send_redirect_uri) do
      opts |> Keyword.put(:redirect_uri, callback_url(conn))
    else
      opts
    end
  end
end
