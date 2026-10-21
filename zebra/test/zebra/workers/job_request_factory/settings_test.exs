defmodule Zebra.Workers.JobRequestFactory.SettingsTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  alias Zebra.Workers.JobRequestFactory.Settings

  @name "JOB_REQUEST_FACTORY_PARALLELISM"

  describe "parse!/3" do
    test "falls back to the default for a missing or blank value" do
      assert Settings.parse!(@name, nil, 10) == 10
      assert Settings.parse!(@name, "", 10) == 10
      assert Settings.parse!(@name, "  ", 10) == 10
    end

    test "parses a positive integer" do
      assert Settings.parse!(@name, "7", 10) == 7
      assert Settings.parse!(@name, " 7 ", 10) == 7
      assert Settings.parse!(@name, 7, 10) == 7
    end

    test "rejects anything that isn't a positive integer, naming the variable" do
      for value <- ["0", "-1", "abc", "5x", "1.5", 0] do
        assert_raise ArgumentError, ~r/#{@name} must be a positive integer/, fn ->
          Settings.parse!(@name, value, 10)
        end
      end
    end
  end

  describe "fit_to_pool/2" do
    test "leaves two connections for the other workers" do
      assert Settings.fit_to_pool(10, 6) == 4
      assert Settings.fit_to_pool(10, 5) == 3
    end

    test "keeps parallelism that already fits" do
      assert Settings.fit_to_pool(10, 16) == 10
      assert Settings.fit_to_pool(3, 5) == 3
      assert Settings.fit_to_pool(1, 3) == 1
    end

    test "never goes below 1" do
      assert Settings.fit_to_pool(10, 2) == 1
      assert Settings.fit_to_pool(10, 1) == 1
    end
  end

  describe "load!/0" do
    setup do
      original = Application.get_env(:zebra, Zebra.Workers.JobRequestFactory)
      on_exit(fn -> Application.put_env(:zebra, Zebra.Workers.JobRequestFactory, original) end)

      pool_size = Application.fetch_env!(:zebra, Zebra.LegacyRepo)[:pool_size]

      %{original: original, pool_size: pool_size}
    end

    test "lowers parallelism to fit the pool and logs it", %{original: original, pool_size: pool} do
      Application.put_env(
        :zebra,
        Zebra.Workers.JobRequestFactory,
        Keyword.merge(original, parallelism: "50", records_per_tick: "", process_timeout: nil)
      )

      log = capture_log(fn -> send(self(), {:settings, Settings.load!()}) end)
      assert_received {:settings, settings}

      assert settings.parallelism == Settings.fit_to_pool(50, pool)
      assert settings.records_per_tick == 100
      assert settings.process_timeout == 15_000
      assert log =~ "parallelism 50 lowered to #{settings.parallelism} for a DB pool of #{pool}"
    end

    test "stops on an invalid value", %{original: original} do
      Application.put_env(
        :zebra,
        Zebra.Workers.JobRequestFactory,
        Keyword.merge(original, process_timeout: "0")
      )

      assert_raise ArgumentError, ~r/JOB_REQUEST_FACTORY_PROCESS_TIMEOUT_MS/, &Settings.load!/0
    end
  end
end
