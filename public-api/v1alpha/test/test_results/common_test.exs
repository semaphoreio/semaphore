defmodule PipelinesAPI.TestResults.CommonTest do
  use ExUnit.Case
  use Plug.Test

  alias PipelinesAPI.TestResults.Common

  setup do
    Support.Stubs.reset()
    :ok
  end

  test "halts 404 when :superjerry_tests feature is disabled" do
    org = Support.Stubs.Organization.create_default()
    Support.Stubs.Feature.set_org_defaults(org.id)
    Support.Stubs.Feature.disable_feature(org.id, :superjerry_tests)

    conn =
      conn(:get, "/projects/p/test_results/flaky_tests")
      |> put_req_header("x-semaphore-org-id", org.id)
      |> Common.feature_enabled([])

    assert conn.halted
    assert conn.status == 404
  end

  test "passes through when :superjerry_tests feature is enabled" do
    org = Support.Stubs.Organization.create_default()
    Support.Stubs.Feature.set_org_defaults(org.id)
    Support.Stubs.Feature.enable_feature(org.id, :superjerry_tests)

    conn =
      conn(:get, "/projects/p/test_results/flaky_tests")
      |> put_req_header("x-semaphore-org-id", org.id)
      |> Common.feature_enabled([])

    refute conn.halted
  end

  test "halts 404 when org_id header is missing" do
    conn =
      conn(:get, "/projects/p/test_results/flaky_tests")
      |> Common.feature_enabled([])

    assert conn.halted
    assert conn.status == 404
  end
end
