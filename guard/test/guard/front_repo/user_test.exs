defmodule Guard.FrontRepo.UserTest do
  use Guard.RepoCase, async: false

  alias Guard.FrontRepo.User

  describe "active_user_by_id_and_salt/2" do
    test "returns the user when the salt matches" do
      salt = "salt-#{System.unique_integer([:positive])}"
      {:ok, user} = Support.Factories.FrontUser.insert(salt: salt)

      assert {:ok, %User{id: id}} = User.active_user_by_id_and_salt(user.id, salt)
      assert id == user.id
    end

    test "returns not_found when the salt does not match" do
      {:ok, user} = Support.Factories.FrontUser.insert(salt: "stored-salt")

      assert {:error, :not_found} = User.active_user_by_id_and_salt(user.id, "wrong-salt")
    end

    test "fails closed (no crash) when the stored salt is nil" do
      # A legacy/OIDC-only account can have a nil salt. secure_compare/2 would
      # raise on the nil; the function must instead return not_found so the
      # caller treats it as unauthenticated rather than 500-ing.
      {:ok, user} = Support.Factories.FrontUser.insert(salt: nil)

      assert {:error, :not_found} = User.active_user_by_id_and_salt(user.id, "any-salt")
    end

    test "returns not_found for a blocked user even with a matching salt" do
      salt = "salt-#{System.unique_integer([:positive])}"

      {:ok, user} =
        Support.Factories.FrontUser.insert(
          salt: salt,
          blocked_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )

      assert {:error, :not_found} = User.active_user_by_id_and_salt(user.id, salt)
    end
  end
end
