defmodule Front.TelemetryTest do
  use ExUnit.Case, async: false
  import Mock

  setup do
    Support.Stubs.InstanceConfig.setup_installation_defaults_config()

    # set CE_VERSION end clear on exit
    Application.put_env(:front, :ce_version, "1.0.0")
    on_exit(fn -> Application.delete_env(:front, :ce_version) end)

    :ok
  end

  describe "perform/0" do
    test "sends metrics and metadata to telemetry endpoint" do
      # Arrange
      with_mock HTTPoison,
        post: fn _url, _body, _headers, _opts ->
          {:ok, %HTTPoison.Response{status_code: 201, body: "ok"}}
        end do
        # Act
        result = Front.Telemetry.perform()

        # Assert
        assert result == :ok
      end
    end

    test "handles telemetry endpoint failure" do
      with_mock HTTPoison,
        post: fn _url, _body, _headers, _opts ->
          {:ok, %HTTPoison.Response{status_code: 400, body: "error"}}
        end do
        # Act
        result = Front.Telemetry.perform()

        # Assert
        assert result == :error
      end
    end
  end
end
