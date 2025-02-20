defmodule Front.ZendeskTest do
  use ExUnit.Case, async: true

  alias Front.Zendesk

  setup do
    user = %{
      email: "foo@example.com",
      name: "Foo",
      id: UUID.uuid4(),
      github_login: "foobar2000",
      bitbucket_uid: "{#{UUID.uuid4()}}",
      gitlab_login: "foobar2000"
    }

    signer = Joken.Signer.create("HS256", Application.get_env(:front, :zendesk_jwt_secret))

    %{user: user, signer: signer}
  end

  describe "generate/1" do
    test "returns valid jwt", %{user: user, signer: signer} do
      jwt_token = Zendesk.JWT.generate(user)
      expected_claims = claims_from_data(user)
      assert {:ok, claims} = Joken.verify(jwt_token, signer)
      assert expected_claims["email"] == claims["email"]
      assert expected_claims["name"] == claims["name"]
      assert expected_claims["external_id"] == claims["external_id"]
      assert expected_claims["user_fields"] == claims["user_fields"]
    end
  end

  describe "#sso_location/1" do
    test "returns url with return path", %{user: _user, signer: _signer} do
      url = Zendesk.sso_location("URL")
      assert url =~ "return_to=URL"
    end

    test "returns url with token for nil redirect location", %{user: _user, signer: _signer} do
      url = Zendesk.sso_location(nil)
      refute url =~ "return_to="
    end
  end

  defp claims_from_data(user) do
    %{
      "email" => user.email,
      "name" => user.name,
      "external_id" => user.id,
      "user_fields" => %{
        "github_username" => user.github_login,
        "bitbucket_uuid" => user.bitbucket_uid,
        "gitlab_login" => user.gitlab_login,
        "semaphore_user_id" => user.id,
        "insider_url" => "https://admin.semaphoretest.test/insider/users/#{user.id}"
      }
    }
  end
end
