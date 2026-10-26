defmodule Guard.Id.OAuthErrorCodeTest do
  use Guard.RepoCase, async: true

  alias Guard.Id.OAuthErrorCode

  describe "from_reason/1" do
    test "returns invalid_uid for :invalid_data" do
      assert OAuthErrorCode.from_reason(:invalid_data) == "invalid_uid"
    end

    test "returns missing_name when changeset has :name can't be blank" do
      changeset =
        %Guard.FrontRepo.RepoHostAccount{}
        |> Ecto.Changeset.cast(%{}, [:name, :login])
        |> Ecto.Changeset.validate_required([:name])

      assert OAuthErrorCode.from_reason(changeset) == "missing_name"
    end

    test "returns missing_login when changeset has :login can't be blank" do
      changeset =
        %Guard.FrontRepo.RepoHostAccount{}
        |> Ecto.Changeset.cast(%{}, [:name, :login])
        |> Ecto.Changeset.validate_required([:login])

      assert OAuthErrorCode.from_reason(changeset) == "missing_login"
    end

    test "returns generic when changeset error is on unknown field" do
      changeset =
        %Guard.FrontRepo.RepoHostAccount{}
        |> Ecto.Changeset.cast(%{}, [:permission_scope])
        |> Ecto.Changeset.validate_required([:permission_scope])

      assert OAuthErrorCode.from_reason(changeset) == "generic"
    end

    test "returns account_taken when the GitHub uid is connected to another user" do
      {_user, rha} = Support.Members.insert_user_with_github_account(github_uid: "20001")

      {:error, changeset} =
        Guard.FrontRepo.RepoHostAccount.create(%{
          login: "other-login",
          github_uid: rha.github_uid,
          repo_host: "github",
          user_id: Ecto.UUID.generate(),
          name: "Other User",
          permission_scope: "user:email"
        })

      assert OAuthErrorCode.from_reason(changeset) == "account_taken"
    end

    test "account_taken is a bounded code" do
      assert "account_taken" in OAuthErrorCode.codes()
    end

    test "returns generic for any other reason" do
      assert OAuthErrorCode.from_reason(:something_else) == "generic"
      assert OAuthErrorCode.from_reason({:error, :boom}) == "generic"
      assert OAuthErrorCode.from_reason(nil) == "generic"
    end
  end
end
