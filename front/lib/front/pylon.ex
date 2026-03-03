defmodule Front.Pylon do
  @default_callback_url "https://graph.usepylon.com/callback/jwt"

  defmodule JWT do
    use Joken.Config

    @audience "https://portal.usepylon.com"
    @default_jwt_ttl_seconds 300

    def token_config, do: default_claims(skip: [:aud, :iss, :exp, :iat, :nbf, :jti])

    def generate(user, org_id) do
      with {:ok, email} <- user_email(user),
           {:ok, org_id} <- org_id(org_id),
           {:ok, secret} <- jwt_secret(),
           {:ok, issuer} <- issuer() do
        signer = Joken.Signer.create("HS256", secret)
        now = current_time()

        %{
          "iat" => now,
          "exp" => now + token_ttl_seconds(),
          "email" => email,
          "aud" => @audience,
          "iss" => ensure_trailing_slash(issuer)
        }
        |> put_account_external_id(org_id)
        |> generate_and_sign!(signer)
        |> then(&{:ok, &1})
      end
    rescue
      _ -> {:error, :token_generation_failed}
    end

    defp token_ttl_seconds do
      Application.get_env(:front, :pylon_jwt_ttl_seconds, @default_jwt_ttl_seconds)
    end

    defp put_account_external_id(claims, org_id),
      do: Map.put(claims, "account_external_id", org_id)

    defp user_email(%{email: email}) when is_binary(email) and email != "", do: {:ok, email}
    defp user_email(_), do: {:error, :invalid_user_email}

    defp org_id(value) when is_binary(value) and value != "", do: {:ok, value}
    defp org_id(_), do: {:error, :invalid_org_id}

    defp jwt_secret do
      case Application.get_env(:front, :pylon_jwt_secret) do
        secret when is_binary(secret) and secret != "" -> {:ok, secret}
        _ -> {:error, :missing_pylon_jwt_secret}
      end
    end

    defp issuer do
      case Application.get_env(:front, :pylon_jwt_issuer) do
        value when is_binary(value) and value != "" -> {:ok, value}
        _ -> {:error, :missing_pylon_jwt_issuer}
      end
    end

    defp ensure_trailing_slash(value) do
      if String.ends_with?(value, "/"), do: value, else: value <> "/"
    end
  end

  def new_ticket_location(user, org_id) do
    with {:ok, token} <- JWT.generate(user, org_id) do
      location =
        "#{callback_url()}?orgSlug=#{URI.encode_www_form(org_slug())}&access_token=#{URI.encode_www_form(token)}"

      {:ok, location}
    end
  end

  defp org_slug, do: Application.get_env(:front, :pylon_org_slug, "semaphore")

  defp callback_url do
    case Application.get_env(:front, :pylon_jwt_callback_url) do
      value when is_binary(value) and value != "" -> value
      _ -> @default_callback_url
    end
  end
end
