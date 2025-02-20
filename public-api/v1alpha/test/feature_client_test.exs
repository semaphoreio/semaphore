defmodule PipelinesAPI.FeatureClient.Test do
  use ExUnit.Case

  use Plug.Test

  alias PipelinesAPI.FeatureClient

  setup do
    Support.Stubs.reset()
    Support.Stubs.build_shared_factories()
    org = Support.Stubs.DB.first(:organizations)

    {:ok, %{org_id: org.id}}
  end

  test "get features enabled for organization", ctx do
    assert FeatureClient.has_feature_enabled?(ctx.org_id, :deployment_targets)
  end

  test "get fake feature not enabled for organization", ctx do
    assert not FeatureClient.has_feature_enabled?(ctx.org_id, :fake_feature)
  end

  test "get features not enabled for organization" do
    assert not FeatureClient.has_feature_enabled?("fakeorg", :deployment_targets)
  end
end
