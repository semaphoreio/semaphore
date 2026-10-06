defmodule Guard.Api.OIDCTest do
  use Guard.RepoCase, async: true

  alias Guard.Api.OIDC

  defp client do
    Tesla.client([
      {Tesla.Middleware.BaseUrl, "http://keycloak/manage"},
      Tesla.Middleware.JSON
    ])
  end

  describe "create_oidc_user/3 failure logging" do
    test "a rejected creation does not log the credential payload" do
      password = "correct-horse-battery-staple"
      user = %{id: Ecto.UUID.generate(), name: "Octo Cat", email: "octo@example.com"}

      Tesla.Mock.mock(fn %{method: :post} ->
        {:ok, %Tesla.Env{status: 409, body: %{"errorMessage" => "User exists with same username"}}}
      end)

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          assert {:error, _} =
                   OIDC.create_oidc_user(client(), user, password_data: [password: password])
        end)

      assert log =~ "octo@example.com"
      refute log =~ "secretData"
      refute log =~ password
    end
  end
end
