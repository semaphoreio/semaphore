defmodule Rbac.Session do
  @moduledoc """
  In this module, I'm immitating how Devise would log in a user
  via the session cookie. In short, the following needs to be done:

  - Have a way to encrypt a cookie like Rails 5.1
  - Have a way to sign a cookie like Rails 5.1
  - Have a way to serialize the content of the cookie like Rails -> ExMarshal in our case
  - Put a warden.user.user.key with the following content [[<user.id>], user.salt] into the session

  For more info, read:
  - Devise source code
  - ActiveSupport::MessageEncryptor's source code
  - Devise::UserFromSession source code in the Semaphore 2 repository (rails monolith)
  """
  require Logger

  def setup(conn, _opts) do
    #
    # Why am I doing it like this, instead of definining it with a plug(Plug.Session....) ?
    # Well, the Plug.Session is not able to dynamically accept parameters, like the
    # :key parameter below.
    #
    # If you set it up the traditional way, the Application.get_env will be evaluated
    # at compile time. At compile time, the value is not set.
    #

    p =
      Plug.Session.init(
        store: PlugRailsCookieSessionStore,
        key: Application.get_env(:rbac, :session_key),
        serializer: __MODULE__.RailsMarshalSessionSerializer,

        #
        # To allow the usage of the session cookie accross subdomains (me, id, <org-name>),
        # we need to set the domain with `.semaphoreci.com`.
        #
        domain: ".#{Application.get_env(:rbac, :base_domain)}",
        secure: true,
        #
        # If `same_site` is set to `Strict` then the cookie will not be sent on
        # cross-site navigations (e.g. clicking a link from GitHub to Semaphore).
        # `Lax` allows the cookie to be sent on top-level navigations.
        #
        same_site: "Lax",
        signing_with_salt: true,
        encrypt: true,
        key_iterations: 1000,
        key_length: 64,
        key_digest: :sha,

        #
        # This part below might look weird or unsecure so here is a snippet from the docs:
        #
        # The other three values can be found somewhere in the initializers
        # directory of your Rails project. Some people don't set the signing_salt
        # and encryption_salt.
        #
        # If you don't find them, set them like so:
        #   encryption_salt: "encryption salt"
        #   signing_salt: "signing salt"
        #
        # Link: https://github.com/cconstantin/plug_rails_cookie_session_store#how-to-use-with-phoenix
        #
        signing_salt: "signed encrypted cookie",
        encryption_salt: "encrypted cookie"
      )

    Plug.Session.call(conn, p)
  end

  @spec serialize_into_session(Rbac.FrontRepo.User.t()) ::
          {String.t(), [String.t() | [String.t()]]}
  def serialize_into_session(user), do: {"warden.user.user.key", [[user.id], user.salt]}

  def deserialize_from_cookie(cookie) do
    values = decrypt_cookie(cookie)

    cond do
      Map.get(values, "id_provider") == "OIDC" ->
        oidc_session_id = Map.get(values, "oidc_session_id")

        id_provider = Map.get(values, "id_provider")

        {:ok, {id_provider, %{}, %{id: oidc_session_id}, %{ip_address: "", user_agent: ""}}}

      Map.has_key?(values, "warden.user.user.key") ->
        [[user_id], user_salt] = Map.get(values, "warden.user.user.key")

        id_provider = Map.get(values, "id_provider", "")
        ip_address = Map.get(values, "ip_address", "")
        user_agent = Map.get(values, "user_agent", "")

        {:ok,
         {id_provider, %{id: user_id, salt: user_salt}, %{},
          %{ip_address: ip_address, user_agent: user_agent}}}

      true ->
        Logger.error("Inalid session cookie values: #{inspect(values)}")

        {:error, :invalid_cookie}
    end
  end

  def decrypt_cookie(cookie) do
    fake_conn = %{
      secret_key_base: Application.get_env(:rbac, :session_secret_key_base)
    }

    opts = %{
      encryption_salt: "encrypted cookie",
      signing_salt: "signed encrypted cookie",
      serializer: __MODULE__.RailsMarshalSessionSerializer,
      key_opts: [iterations: 1000, length: 64, digest: :sha, cache: Plug.Keys]
    }

    {_, cookie} = PlugRailsCookieSessionStore.get(fake_conn, cookie, opts)

    cookie
  end

  def encrypt_cookie(cookie) do
    fake_conn = %{
      secret_key_base: Application.get_env(:rbac, :session_secret_key_base)
    }

    opts = %{
      encryption_salt: "encrypted cookie",
      signing_salt: "signed encrypted cookie",
      serializer: __MODULE__.RailsMarshalSessionSerializer,
      key_opts: [iterations: 1000, length: 64, digest: :sha, cache: Plug.Keys]
    }

    PlugRailsCookieSessionStore.put(fake_conn, nil, cookie, opts)
  end

  defmodule RailsMarshalSessionSerializer do
    @moduledoc """
    Share a session with a Rails app using Ruby's Marshal format.
    """
    def encode(value) do
      {:ok, ExMarshal.encode(value)}
    end

    def decode(value) do
      case Jason.decode(value) do
        {:ok, %{"_rails" => %{"message" => message}}} ->
          message = Base.decode64!(message)
          {:ok, ExMarshal.decode(message)}

        _ ->
          {:ok, ExMarshal.decode(value)}
      end
    rescue
      e ->
        Logger.error("Error #{inspect(e)} while decoding value #{inspect(value)}")
        {:ok, %{}}
    end
  end
end
