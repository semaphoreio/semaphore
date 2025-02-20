defmodule Guard.Store.User.Test do
  use Guard.RepoCase, async: true

  alias Guard.Store, as: GS
  alias Guard.Repo, as: GR

  setup do
    Support.Guard.Store.clear!()

    :ok
  end

  describe "update" do
    test "method should return user" do
      {:ok, user} =
        GS.User.update(
          "ee2e6241-f30b-4892-a0d5-bd900b713430",
          "github",
          "123456",
          "private"
        )

      assert %GR.User{
               user_id: "ee2e6241-f30b-4892-a0d5-bd900b713430",
               provider: "github",
               github_uid: "123456"
             } = user
    end

    # test "when the scope is none => removes the user" do
    #  {:ok, user} =
    #    GS.User.update(
    #      "ee2e6241-f30b-4892-a0d5-bd900b713430",
    #      "github",
    #      "123456",
    #      "private"
    #    )

    #  assert %GR.User{
    #           user_id: "ee2e6241-f30b-4892-a0d5-bd900b713430",
    #           provider: "github",
    #           github_uid: "123456"
    #         } = user

    #  refute [] == GR.User |> GR.all()

    #  {:ok, :user_deleted} =
    #    GS.User.update(
    #      "ee2e6241-f30b-4892-a0d5-bd900b713430",
    #      "github",
    #      "123456",
    #      "none"
    #    )

    #  assert [] == GR.User |> GR.all()
    # end
  end

  describe "find_by_provider_uid" do
    test "returns latest user" do
      {:ok, _} =
        GS.User.update(
          "ee2e6241-f30b-4892-a0d5-bd900b713430",
          "github",
          "123457",
          "private"
        )

      {:ok, user} =
        GS.User.update(
          "ee2e6241-f30b-4892-a0d5-bd900b713432",
          "github",
          "123456",
          "private"
        )

      assert user.user_id == GS.User.find_id_by_provider_uid("123456", "github")
    end
  end
end
