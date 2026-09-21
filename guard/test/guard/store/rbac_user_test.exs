defmodule Guard.Store.RbacUser.Test do
  use Guard.RepoCase, async: true

  alias Guard.Store.RbacUser
  alias Support.Factories

  setup do
    Support.Guard.Store.clear!()

    :ok
  end

  describe "fetch_by_email/1" do
    test "finds user with different case and surrounding spaces" do
      {:ok, user} =
        Factories.RbacUser.insert(Ecto.UUID.generate(), "Test User", "User@Example.com")

      assert {:ok, found} = RbacUser.fetch_by_email("  user@example.com  ")
      assert found.id == user.id
    end

    test "returns error when email does not exist" do
      assert {:error, :not_found} = RbacUser.fetch_by_email("nonexistent@example.com")
    end
  end

  describe "create/4" do
    test "returns error for emails that only differ by case and spaces" do
      existing_user_id = Ecto.UUID.generate()
      new_user_id = Ecto.UUID.generate()

      assert RbacUser.create(existing_user_id, "User@Example.com", "Test User") == :ok
      assert RbacUser.create(new_user_id, "  user@example.com  ", "Another User") == :error
    end
  end
end
