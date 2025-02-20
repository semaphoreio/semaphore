defmodule Front.Models.TestExplorer.FlakyTestDisruptionTest do
  use ExUnit.Case

  alias Front.Models.TestExplorer.FlakyTestDisruption, as: FT

  describe "git_user_or_empty/1" do
    test "returns git_user if it is present and not nil" do
      ppl = %{triggerer: %{git_user: "test_user"}}
      assert FT.git_user_or_empty(ppl) == "test_user"
    end

    test "returns empty string if git_user is nil" do
      ppl = %{triggerer: %{git_user: nil}}
      assert FT.git_user_or_empty(ppl) == ""
    end

    test "returns empty string if ppl does not have necessary structure" do
      ppl = %{a_different_structure: %{other_field: "other_data"}}
      assert FT.git_user_or_empty(ppl) == ""
    end
  end
end
