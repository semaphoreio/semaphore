defmodule Guard.Api.OIDC do
  require Logger

  def create_oidc_user(client, user, opts \\ []) do
    password_data = Keyword.get(opts, :password_data, [])

    data =
      get_oidc_data(user)
      |> maybe_merge_credentials(get_oidc_credential(password_data))

    do_create_oidc_user(client, data)
  end

  defp do_create_oidc_user(client, data) do
    case Tesla.post(client, "/users", data) do
      {:ok, res} ->
        if res.status in 200..299 do
          oidc_user_id =
            Tesla.get_header(res, "location")
            |> String.split("/")
            |> List.last()

          {:ok, oidc_user_id}
        else
          Logger.error("[OIDC API] Error creating user #{inspect(data)}: #{inspect(res.body)}")

          {:error, "#{res.body["errorMessage"]}"}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  def delete_oidc_user(client, oidc_user_id) do
    case Tesla.delete(client, "/users/" <> oidc_user_id) do
      {:ok, res} ->
        if res.status in 200..299 do
          {:ok, oidc_user_id}
        else
          Logger.error("[OIDC API] Error deleting user #{oidc_user_id}: #{inspect(res.body)}")

          {:error, "#{res.body["errorMessage"]}"}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  def update_oidc_user(client, oidc_user_id, user, opts \\ []) do
    password_data = Keyword.get(opts, :password_data, [])
    email = Keyword.get(opts, :email, :none)

    data =
      get_oidc_data(user)
      |> maybe_merge_credentials(get_oidc_credential(password_data))
      |> maybe_change_email(email)

    case do_update_oidc_user(client, oidc_user_id, data) do
      {:ok, _} ->
        data.federatedIdentities
        |> Enum.map(fn identity ->
          do_update_federated_identity(client, oidc_user_id, identity)
        end)
        |> Enum.reduce({:ok, oidc_user_id}, fn
          {:ok, oidc_user_id}, {:ok, _} -> {:ok, oidc_user_id}
          {:ok, _}, {:error, error} -> {:error, error}
          {:error, error}, _ -> {:error, error}
        end)

      {:error, error} ->
        {:error, error}
    end
  end

  defp do_update_oidc_user(client, oidc_user_id, data) do
    case Tesla.put(client, "/users/" <> oidc_user_id, data) do
      {:ok, res} ->
        if res.status in 200..299 do
          {:ok, oidc_user_id}
        else
          Logger.error("[OIDC API] Error updating user #{oidc_user_id}: #{inspect(res.body)}")

          {:error, "#{res.body["errorMessage"]}"}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  defp do_update_federated_identity(
         client,
         oidc_user_id,
         %{identityProvider: provider} = federated_identity
       ) do
    Tesla.delete(client, "/users/" <> oidc_user_id <> "/federated-identity/" <> provider)

    case Tesla.post(
           client,
           "/users/" <> oidc_user_id <> "/federated-identity/" <> provider,
           federated_identity
         ) do
      {:ok, res} ->
        if res.status in 200..299 do
          {:ok, oidc_user_id}
        else
          Logger.error(
            "[OIDC API] Error updating federated identities for user #{oidc_user_id}: #{inspect(res.body)}"
          )

          {:error, "#{res.body["errorMessage"]}"}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  def get_oidc_data(user) do
    [first | rest] = String.split(user.name)
    last = Enum.join(rest, " ")
    federated_identities = get_oidc_federeted_identities(user)

    %{
      enabled: true,
      emailVerified: true,
      email: user.email,
      username: user.email,
      firstName: first,
      lastName: last,
      federatedIdentities: federated_identities
    }
  end

  def get_oidc_federeted_identities(user) do
    case Guard.FrontRepo.RepoHostAccount.list_for_user(user.id) do
      {:ok, list} ->
        list
        |> Enum.map(&%{identityProvider: &1.repo_host, userId: &1.github_uid, userName: &1.login})
        |> map_federated_identities()
    end
  end

  @spec get_oidc_credential(Keyword.t()) :: map() | nil
  def get_oidc_credential(opts) do
    password = Keyword.get(opts, :password, "")

    if is_binary(password) and password != "" do
      build_oidc_credential(password, opts)
    else
      nil
    end
  end

  defp build_oidc_credential(password, opts) do
    temporary = Keyword.get(opts, :temporary, true)

    parallelism = 1
    iterations = 5
    memory = 13
    hashlen = 32
    salt = Argon2.Base.gen_salt()

    hash =
      Argon2.Base.hash_password(password, salt,
        # id
        argon2_type: 2,
        parallelism: parallelism,
        t_cost: iterations,
        m_cost: memory,
        hashlen: hashlen,
        format: :raw_hash
      )
      |> Base.decode16!(case: :lower)
      |> Base.encode64()

    %{
      type: "password",
      userLabel: "My password",
      temporary: temporary,
      secretData:
        Jason.encode!(%{
          value: hash,
          salt: Base.encode64(salt),
          additionalParameters: %{}
        }),
      credentialData:
        Jason.encode!(%{
          hashIterations: iterations,
          algorithm: "argon2",
          additionalParameters: %{
            hashLength: [Integer.to_string(hashlen)],
            memory: [Integer.to_string(2 ** memory)],
            type: ["id"],
            version: ["1.3"],
            parallelism: [Integer.to_string(parallelism)]
          }
        })
    }
  end

  defp map_federated_identities([]), do: []

  defp map_federated_identities([head | tail]) do
    mapped_identity = map_federated_identity(head)
    rest_mapped_identities = map_federated_identities(tail)

    case mapped_identity do
      nil -> rest_mapped_identities
      _ -> [mapped_identity | rest_mapped_identities]
    end
  end

  defp map_federated_identity(%{identityProvider: "gitlab"} = identity), do: identity

  defp map_federated_identity(%{identityProvider: "github"} = identity), do: identity

  defp map_federated_identity(%{identityProvider: "bitbucket", userId: bitbucket_id} = identity) do
    case Guard.Api.Bitbucket.user(bitbucket_id) do
      {:ok, bitbucket} ->
        %{identity | userId: bitbucket.account_id}

      {:error, error} ->
        Logger.error("Failed to fetch Bitbucket user #{bitbucket_id}: #{error}")
        identity
    end
  end

  def get_user(client, oidc_user_id) do
    case Tesla.get(client, "/users/" <> oidc_user_id) do
      {:ok, res} ->
        if res.status in 200..299 do
          user = %{
            id: res.body["id"],
            email: res.body["email"],
            name: get_name(res.body),
            github: get_provider(res.body["federatedIdentities"], "github"),
            bitbucket: get_provider(res.body["federatedIdentities"], "bitbucket"),
            gitlab: get_provider(res.body["federatedIdentities"], "gitlab")
          }

          {:ok, user}
        else
          Logger.error("[OIDC API] Error fetching user #{oidc_user_id}: #{inspect(res.body)}")

          {:error, "#{res.body["error"]}. #{res.body["error_description"]}"}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Sets a user attribute in Keycloak. Used to sync semaphore_user_id for MCP OAuth tokens.

  ## Examples

      Guard.Api.OIDC.set_user_attribute(client, oidc_user_id, "semaphore_user_id", "uuid-here")
  """
  def set_user_attribute(client, oidc_user_id, attribute_name, attribute_value) do
    # First get the current user to preserve existing attributes
    case Tesla.get(client, "/users/" <> oidc_user_id) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        existing_attributes = body["attributes"] || %{}

        updated_attributes =
          Map.put(existing_attributes, attribute_name, [attribute_value])

        update_data = %{attributes: updated_attributes}

        case Tesla.put(client, "/users/" <> oidc_user_id, update_data) do
          {:ok, %{status: update_status}} when update_status in 200..299 ->
            {:ok, oidc_user_id}

          {:ok, %{status: _, body: error_body}} ->
            Logger.error(
              "[OIDC API] Error setting attribute #{attribute_name} for user #{oidc_user_id}: #{inspect(error_body)}"
            )

            {:error, "#{error_body["errorMessage"]}"}

          {:error, error} ->
            {:error, error}
        end

      {:ok, %{status: _, body: error_body}} ->
        Logger.error(
          "[OIDC API] Error fetching user #{oidc_user_id} for attribute update: #{inspect(error_body)}"
        )

        {:error, "#{error_body["error"]}. #{error_body["error_description"]}"}

      {:error, error} ->
        {:error, error}
    end
  end

  defp get_provider(nil, _), do: nil

  defp get_provider(fed_idns, provider) do
    Enum.find_value(fed_idns, fn idn ->
      if idn["identityProvider"] == provider,
        do: %{
          id: idn["userId"],
          username: idn["userName"] || ""
        }
    end)
  end

  defp get_name(data) do
    String.trim("#{data["firstName"]} #{data["lastName"]}")
  end

  defp maybe_change_email(data, :none), do: data

  defp maybe_change_email(data, email),
    do: data |> Map.put(:email, email)

  defp maybe_merge_credentials(data, nil), do: data

  defp maybe_merge_credentials(data, credential),
    do: data |> Map.merge(%{credentials: [credential]})

  def client do
    middleware = [
      {Tesla.Middleware.BaseUrl, base_url()},
      {Tesla.Middleware.Headers, [{"X-Forwarded-Proto", "https"}]},
      {Tesla.Middleware.BearerAuth, token: Guard.OIDC.get_api_token!()},
      Tesla.Middleware.JSON,
      Tesla.Middleware.Logger,
      {Guard.Api.Middleware.UpdateToken, token_fetcher: &Guard.OIDC.get_api_token/0},
      {Tesla.Middleware.Retry,
       delay: 500,
       max_retries: 2,
       should_retry: fn
         {:ok, %Tesla.Env{status: status}} when status in [401] -> true
         {:ok, %Tesla.Env{status: _status}} -> false
         {:error, _} -> true
       end}
    ]

    client = Tesla.client(middleware)
    {:ok, client}
  end

  defp base_url do
    Application.get_env(:guard, :oidc)[:manage_url]
  end
end
