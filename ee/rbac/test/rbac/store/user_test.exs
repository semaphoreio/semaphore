defmodule Rbac.Store.User.Test do
  use Rbac.RepoCase, async: true

  alias Rbac.Store, as: RS
  alias Rbac.Repo, as: RR

  setup do
    Support.Rbac.Store.clear!()

    :ok
  end

  describe "update" do
    test "method should return user" do
      {:ok, user} =
        RS.User.update(
          "ee2e6241-f30b-4892-a0d5-bd900b713430",
          "github",
          "123456",
          "private"
        )

      assert %RR.User{
               user_id: "ee2e6241-f30b-4892-a0d5-bd900b713430",
               provider: "github",
               github_uid: "123456"
             } = user
    end
  end

  describe "find_by_provider_uid" do
    test "returns latest user" do
      {:ok, _} =
        RS.User.update(
          "ee2e6241-f30b-4892-a0d5-bd900b713430",
          "github",
          "123457",
          "private"
        )

      {:ok, user} =
        RS.User.update(
          "ee2e6241-f30b-4892-a0d5-bd900b713432",
          "github",
          "123456",
          "private"
        )

      assert user.user_id == RS.User.find_id_by_provider_uid("123456", "github")
    end
  end
end
