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

    test "returns generic for any other reason" do
      assert OAuthErrorCode.from_reason(:something_else) == "generic"
      assert OAuthErrorCode.from_reason({:error, :boom}) == "generic"
      assert OAuthErrorCode.from_reason(nil) == "generic"
    end
  end
end
