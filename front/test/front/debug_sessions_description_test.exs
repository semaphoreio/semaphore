defmodule Front.DebugSessionsDescription.Test do
  use ExUnit.Case

  alias Front.DebugSessionsDescription, as: Dscr

  describe "description" do
    test "returns empty string for empty params" do
      msg = "Debug session restrictions did not change."
      params = %{}

      assert msg == Dscr.description(params)
    end

    test "returns proper string for custom permissions with all false" do
      msg = "Changed debug session restrictions. Everything is blocked."
      params = all_params("true")

      assert msg == Dscr.description(params)
    end

    test "returns proper string for all false params" do
      msg = "Debug sessions are set to follow organization defaults."
      params = all_params()

      assert msg == Dscr.description(params)
    end

    test "returns proper string for custom settings and 1 debug param" do
      msg = "Changed debug session restrictions. It can be used to debug the tags."

      params = Map.merge(all_params("true"), %{"allow_debug_tag" => "true"})

      assert msg == Dscr.description(params)
    end

    test "returns proper string for when custom is not set but params are checked" do
      msg = "Debug sessions are set to follow organization defaults."
      params = Map.merge(all_params(), %{"allow_debug_tag" => "true"})

      assert msg == Dscr.description(params)
    end

    test "returns proper string for 1 attach params" do
      msg = "Changed debug session restrictions. It can be used to debug the tags."

      params = Map.merge(all_params("true"), %{"allow_debug_tag" => "true"})

      assert msg == Dscr.description(params)
    end

    test "returns proper string for 2 attach params" do
      msg =
        "Changed debug session restrictions. It can be used to attach to the pull requests and tags."

      params =
        Map.merge(all_params("true"), %{"allow_attach_pr" => "true", "allow_attach_tag" => "true"})

      assert msg == Dscr.description(params)
    end

    test "returns proper string for 3 debug params" do
      msg =
        "Changed debug session restrictions. It can be used to debug the default branch, pull requests and tags."

      params =
        Map.merge(all_params("true"), %{
          "allow_debug_pr" => "true",
          "allow_debug_default_branch" => "true",
          "allow_debug_tag" => "true"
        })

      assert msg == Dscr.description(params)
    end

    test "returns proper string for 1 debug and 2 attaches params" do
      msg =
        "Changed debug session restrictions. It can be used to debug the default branch. And attach to the pull requests and tags."

      params =
        Map.merge(all_params("true"), %{
          "allow_attach_pr" => "true",
          "allow_debug_default_branch" => "true",
          "allow_attach_tag" => "true"
        })

      assert msg == Dscr.description(params)
    end

    def all_params(custom \\ "false") do
      %{
        "allow_attach_default_branch" => "false",
        "allow_attach_forked_pr" => "false",
        "allow_attach_non_default_branch" => "false",
        "allow_attach_pr" => "false",
        "allow_attach_tag" => "false",
        "allow_debug_default_branch" => "false",
        "allow_debug_empty_session" => "false",
        "allow_debug_forked_pr" => "false",
        "allow_debug_non_default_branch" => "false",
        "allow_debug_pr" => "false",
        "allow_debug_tag" => "false",
        "custom_permissions" => custom
      }
    end
  end
end
