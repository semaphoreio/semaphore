defmodule RepositoryHub.WebhookEncryptor.FeatureFilterTest do
  use ExUnit.Case, async: false

  alias InternalApi.Feature.OrganizationFeaturesChanged
  alias RepositoryHub.WebhookEncryptor.FeatureFilter
  alias InternalApi.Feature.OrganizationFeaturesChanged

  @success_org_id "9290123e-6066-41ae-8ae3-321964100dce"
  @suspended_org_id "15dc44f0-3d9e-4282-b474-11959e647f18"

  describe "invalidate_cache/1" do
    test "receiving message invalidates feature cache for organization" do
      Cachex.put(:feature_provider_cache, "org_id", %{"feature1" => true})
      assert :ok = FeatureFilter.invalidate_cache(event("org_id"))
      assert {:ok, nil} = Cachex.get(:feature_provider_cache, "org_id")
    end
  end

  describe "process_message/1" do
    test "enables processing for eligible organizations" do
      org_id = @success_org_id
      username = "#{org_id}-username"

      assert {:ok, %{org_id: ^org_id, org_username: ^username}} =
               FeatureFilter.process_message(message_from_org_id(org_id))
    end

    test "halts processing for suspended organizations" do
      assert {:error, :organization_suspended} = FeatureFilter.process_message(message_from_org_id(@suspended_org_id))
    end

    test "logs error when unable to fetch organization from API" do
      organization_grpc_endpoint = Application.get_env(:repository_hub, :organization_grpc_endpoint)
      Application.put_env(:repository_hub, :organization_grpc_endpoint, "test:50052")
      on_exit(fn -> Application.put_env(:repository_hub, :organization_grpc_endpoint, organization_grpc_endpoint) end)

      assert {:error, ":timeout"} = FeatureFilter.process_message(message_from_org_id(@success_org_id))
    end
  end

  describe "handle_events/3" do
    test "processes multiple organizations and filters successful ones" do
      messages = [
        message_from_org_id(@success_org_id),
        message_from_org_id(@suspended_org_id)
      ]

      success_username = "#{@success_org_id}-username"

      assert {:noreply, [%{org_id: @success_org_id, org_username: ^success_username}], %{}} =
               FeatureFilter.handle_events(messages, self(), %{})
    end
  end

  defp event(org_id), do: %OrganizationFeaturesChanged{org_id: org_id}
  defp enc_event(org_id), do: OrganizationFeaturesChanged.encode(event(org_id))

  defp message_from_org_id(org_id) do
    %Broadway.Message{data: enc_event(org_id), acknowledger: Broadway.NoopAcknowledger.init()}
  end
end
