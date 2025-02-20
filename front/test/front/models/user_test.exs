defmodule Front.Models.UserTest do
  use ExUnit.Case

  alias Front.Models.User

  alias Support.Stubs.DB

  setup do
    Cacheman.clear(:front)

    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    user = DB.first(:users)

    [
      user: user
    ]
  end

  describe ".find" do
    test "when the response is succesfull => it returns a user model instance", %{user: user} do
      u = User.find(user.id)

      assert u.id == user.id
    end

    test "when the response is unsuccesfull => it returns nil" do
      assert User.find("46e09d9d-c759-4e31-a8b7-3acdb34e701e") == nil
    end
  end

  describe ".find_many" do
    test "when the response is succesfull => it returns an array of users", %{user: user} do
      assert User.find_many([user.id]) == [
               %User{
                 :id => user.api_model.user_id,
                 :name => user.api_model.name,
                 :avatar_url => user.api_model.avatar_url,
                 :github_scope => :NONE,
                 :bitbucket_scope => :NONE,
                 :gitlab_scope => :NONE,
                 :email => user.api_model.email,
                 :company => user.api_model.company,
                 :single_org_user => false,
                 :org_id => ""
               }
             ]
    end
  end

  describe ".update" do
    test "when the response is successful => it returns the ok response", %{user: user} do
      u = User.find(user.id)

      refute u.name == "Perica"

      {:ok, u} = User.update(u, %{name: "Perica"})

      assert u.name == "Perica"
    end

    test "when the response is unsuccesfull => it returns the error response", %{user: user} do
      u = User.find(user.id)
      Support.Stubs.User.delete(u.id)

      assert User.update(u, %{name: "Perica"}) == {:error, %{errors: %{other: "Oops"}}}
    end
  end

  describe ".regenerate_token" do
    test "when the response is successful => it returns the ok response", %{user: user} do
      GrpcMock.stub(UserMock, :regenerate_token, fn _, _ ->
        InternalApi.User.RegenerateTokenResponse.new(
          status: Google.Rpc.Status.new(code: Google.Rpc.Code.value(:OK)),
          api_token: "token"
        )
      end)

      {:ok, new_token} = User.regenerate_token(user.id)

      assert new_token == "token"
    end

    test "when the response is unsuccesfull => it returns the error response", %{user: user} do
      GrpcMock.stub(UserMock, :regenerate_token, fn _, _ ->
        InternalApi.User.RegenerateTokenResponse.new(
          status:
            Google.Rpc.Status.new(
              code: Google.Rpc.Code.value(:INTERNAL),
              message: "Oops"
            )
        )
      end)

      assert User.regenerate_token(user.id) == {:error, "Oops"}
    end
  end
end
