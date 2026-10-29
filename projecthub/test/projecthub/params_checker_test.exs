defmodule Projecthub.ParamsCheckerTest do
  use ExUnit.Case, async: true

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

    test "returns error when sem-approve options are enabled without forked pull requests" do
      spec = spec_with_sem_approve_options([:PULL_REQUESTS], ["trusted-user"])

      {:error, messages} = ParamsChecker.run(spec, false)

      assert messages == ["Sem-approve options require forked pull requests to be enabled"]
    end

    test "returns error when sem-approve options are enabled without trusted contributors" do
      spec = spec_with_sem_approve_options([:FORKED_PULL_REQUESTS], [])

      {:error, messages} = ParamsChecker.run(spec, false)

      assert messages == ["Sem-approve options require at least one trusted contributor"]
    end

    test "returns both errors when sem-approve prerequisites are not met" do
      spec = spec_with_sem_approve_options([:PULL_REQUESTS], [])

      {:error, messages} = ParamsChecker.run(spec, false)

      assert messages == [
               "Sem-approve options require forked pull requests to be enabled",
               "Sem-approve options require at least one trusted contributor"
             ]
    end

    test "allows sem-approve options with forked pull requests and trusted contributors" do
      spec = spec_with_sem_approve_options([:FORKED_PULL_REQUESTS], ["trusted-user"])

      :ok = ParamsChecker.run(spec, false)
    end
  end

  defp spec_with_sem_approve_options(run_on, allowed_contributors) do
    %{
      visibility: :PRIVATE,
      repository: %{
        run_on: run_on,
        forked_pull_requests: %{
          allowed_contributors: allowed_contributors,
          allow_sem_approve_include_secrets: true,
          allow_sem_approve_enable_cache: true
        }
      }
    }
  end
end
