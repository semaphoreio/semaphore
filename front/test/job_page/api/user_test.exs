defmodule JobPage.Api.UserTest do
  use FrontWeb.ConnCase
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

  describe ".fetch" do
    test "it fetches the user by id", %{user: user} do
      assert user.api_model == JobPage.Api.User.fetch(user.id)
    end
  end
end
