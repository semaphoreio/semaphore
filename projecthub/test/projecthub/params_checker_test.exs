defmodule Projecthub.ParamsCheckerTest do
  use Projecthub.DataCase

  alias Projecthub.ParamsChecker

  describe ".run" do
    test "when checking private project for open source org => return error" do
      {:error, messages} = ParamsChecker.run(%{visibility: :PRIVATE}, true)

      assert messages == ["Only public projects are allowed"]
    end

    test "when checking private project for non open source org => return :ok" do
      :ok = ParamsChecker.run(%{visibility: :PRIVATE}, false)
    end

    test "when checking public project for open source org => return :ok" do
      :ok = ParamsChecker.run(%{visibility: :PUBLIC}, true)
    end

    test "when checking public project for non open source org => return :ok" do
      :ok = ParamsChecker.run(%{visibility: :PUBLIC}, false)
    end
  end
end
