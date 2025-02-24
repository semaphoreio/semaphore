defmodule RaisingProviderTest do
  use ExUnit.Case
  doctest RaisingProvider
  alias RaisingProvider

  describe "RaisingProvider" do
    setup do
      [provider: RaisingProvider]
    end

    test "handles raised routines from the provider", %{provider: provider} do
      import ExUnit.CaptureLog

      assert capture_log([level: :error], fn ->
               assert {:error, {:provider_exception, %RuntimeError{}}} =
                        FeatureProvider.find_machine("some-machine-type", provider: provider)
             end) =~ "FeatureProvider.list_machines#fail"
    end
  end
end
