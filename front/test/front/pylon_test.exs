defmodule Front.PylonTest do
  use ExUnit.Case, async: false

  alias Front.Pylon

  setup do
    org_slug = Application.get_env(:front, :pylon_org_slug)
    jwt_secret = Application.get_env(:front, :pylon_jwt_secret)
    jwt_issuer = Application.get_env(:front, :pylon_jwt_issuer)
    jwt_callback_url = Application.get_env(:front, :pylon_jwt_callback_url)
    jwt_ttl_seconds = Application.get_env(:front, :pylon_jwt_ttl_seconds)

    on_exit(fn ->
      restore_env(:pylon_org_slug, org_slug)
      restore_env(:pylon_jwt_secret, jwt_secret)
      restore_env(:pylon_jwt_issuer, jwt_issuer)
      restore_env(:pylon_jwt_callback_url, jwt_callback_url)
      restore_env(:pylon_jwt_ttl_seconds, jwt_ttl_seconds)
    end)

    :ok
  end

  describe "new_ticket_location/2" do
    test "returns callback URL with JWT token and required claims" do
      Application.put_env(:front, :pylon_org_slug, "semaphore")
      Application.put_env(:front, :pylon_jwt_secret, "secret")
      Application.put_env(:front, :pylon_jwt_issuer, "https://semaphoreci.com")

      Application.put_env(
        :front,
        :pylon_jwt_callback_url,
        "https://graph.usepylon.com/callback/jwt"
      )

      assert {:ok, url} = Pylon.new_ticket_location(%{email: "foo@example.com"}, "org-123")

      query = url |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()
      token = query["access_token"]

      assert query["orgSlug"] == "semaphore"
      assert is_binary(token)
      assert token != ""

      signer = Joken.Signer.create("HS256", "secret")

      assert {:ok, claims} = Joken.verify(token, signer)
      assert claims["email"] == "foo@example.com"
      assert claims["aud"] == "https://portal.usepylon.com"
      assert claims["iss"] == "https://semaphoreci.com/"
      assert claims["account_external_id"] == "org-123"
      assert is_integer(claims["iat"])
      assert is_integer(claims["exp"])
      assert claims["exp"] > claims["iat"]
    end

    test "returns error when required config is missing" do
      Application.delete_env(:front, :pylon_org_slug)
      Application.delete_env(:front, :pylon_jwt_secret)
      Application.delete_env(:front, :pylon_jwt_issuer)

      assert {:error, :missing_pylon_jwt_secret} =
               Pylon.new_ticket_location(%{email: "foo@example.com"}, "org-123")
    end

    test "returns error when org_id is missing" do
      Application.put_env(:front, :pylon_org_slug, "semaphore")
      Application.put_env(:front, :pylon_jwt_secret, "secret")
      Application.put_env(:front, :pylon_jwt_issuer, "https://semaphoreci.com")

      assert {:error, :invalid_org_id} =
               Pylon.new_ticket_location(%{email: "foo@example.com"}, "")
    end

    test "uses short default JWT TTL" do
      Application.put_env(:front, :pylon_org_slug, "semaphore")
      Application.put_env(:front, :pylon_jwt_secret, "secret")
      Application.put_env(:front, :pylon_jwt_issuer, "https://semaphoreci.com")
      Application.delete_env(:front, :pylon_jwt_ttl_seconds)

      assert {:ok, url} = Pylon.new_ticket_location(%{email: "foo@example.com"}, "org-123")

      token =
        url
        |> URI.parse()
        |> Map.fetch!(:query)
        |> URI.decode_query()
        |> Map.fetch!("access_token")

      signer = Joken.Signer.create("HS256", "secret")

      assert {:ok, claims} = Joken.verify(token, signer)
      assert claims["exp"] - claims["iat"] == 300
    end
  end

  defp restore_env(key, nil), do: Application.delete_env(:front, key)
  defp restore_env(key, value), do: Application.put_env(:front, key, value)
end
