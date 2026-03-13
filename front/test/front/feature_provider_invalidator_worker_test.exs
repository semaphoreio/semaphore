defmodule Front.FeatureProviderInvalidatorWorkerTest do
  use Front.TestCase

  import ExUnit.CaptureLog
  import Mock

  alias Front.FeatureProviderInvalidatorWorker, as: Worker

  defp build_message(routing_key, data \\ "") do
    %Broadway.Message{
      data: data,
      metadata: %{routing_key: routing_key},
      acknowledger: Broadway.NoopAcknowledger.init()
    }
  end

  describe "handle_message/3" do
    test "machines_changed invalidates global machine cache" do
      message = build_message("machines_changed")

      with_mock FeatureProvider, list_machines: fn _opts -> {:ok, []} end do
        log =
          capture_log(fn ->
            result = Worker.handle_message(:default, message, %{})
            assert result == message
          end)

        assert log =~ "invalidating machines"
        assert_called(FeatureProvider.list_machines(reload: true))
      end
    end

    test "organization_machines_changed invalidates org machine cache" do
      org_id = UUID.uuid4()

      payload =
        InternalApi.Feature.OrganizationMachinesChanged.new(org_id: org_id)
        |> InternalApi.Feature.OrganizationMachinesChanged.encode()

      message = build_message("organization_machines_changed", payload)

      with_mock FeatureProvider,
        list_machines: fn _opts -> {:ok, []} end do
        log =
          capture_log(fn ->
            result = Worker.handle_message(:default, message, %{})
            assert result == message
          end)

        assert log =~ "invalidating machines for org #{org_id}"
        assert_called(FeatureProvider.list_machines(reload: true, param: org_id))
      end
    end

    test "features_changed invalidates global feature cache" do
      message = build_message("features_changed")

      with_mock FeatureProvider, list_features: fn _opts -> {:ok, []} end do
        log =
          capture_log(fn ->
            result = Worker.handle_message(:default, message, %{})
            assert result == message
          end)

        assert log =~ "invalidating features"
        assert_called(FeatureProvider.list_features(reload: true))
      end
    end

    test "organization_features_changed invalidates org feature cache" do
      org_id = UUID.uuid4()

      payload =
        InternalApi.Feature.OrganizationFeaturesChanged.new(org_id: org_id)
        |> InternalApi.Feature.OrganizationFeaturesChanged.encode()

      message = build_message("organization_features_changed", payload)

      with_mock FeatureProvider,
        list_features: fn _opts -> {:ok, []} end do
        log =
          capture_log(fn ->
            result = Worker.handle_message(:default, message, %{})
            assert result == message
          end)

        assert log =~ "invalidating features for org #{org_id}"
        assert_called(FeatureProvider.list_features(reload: true, param: org_id))
      end
    end

    test "unknown routing key logs warning and returns message" do
      message = build_message("unknown_key")

      log =
        capture_log(fn ->
          result = Worker.handle_message(:default, message, %{})
          assert result == message
        end)

      assert log =~ "unknown routing key: unknown_key"
    end
  end
end
