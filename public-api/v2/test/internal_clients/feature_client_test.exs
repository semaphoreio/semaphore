defmodule InternalClients.Feature.Test do
  use ExUnit.Case

  use Plug.Test

  alias InternalClients.Feature, as: FeatureClient

  setup do
    Support.Stubs.reset()
    Support.Stubs.build_shared_factories()
    org = Support.Stubs.DB.first(:organizations)

    {:ok, %{org_id: org.id}}
  end

  test "get features enabled for organization", ctx do
    {:ok, features} = FeatureClient.provide_features(ctx.org_id, :deployment_targets)

    assert Enum.any?(features, fn
             %{type: "deployment_targets", state: :enabled} -> true
             _ -> false
           end)
  end

  test "get fake feature not enabled for organization", ctx do
    {:ok, features} = FeatureClient.provide_features(ctx.org_id, :fake_feature)

    assert not Enum.any?(features, fn
             %{type: "fake_feature", state: :enabled} -> true
             _ -> false
           end)
  end

  test "get features not enabled for organization" do
    {:ok, features} = FeatureClient.provide_features("fakeorg", :zendesk_support)

    assert not Enum.any?(features, fn
             %{type: "zendesk_support", state: :enabled} -> true
             _ -> false
           end)
  end
end
