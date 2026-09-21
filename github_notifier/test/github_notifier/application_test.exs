defmodule GithubNotifier.ApplicationTest do
  use ExUnit.Case, async: true

  alias GithubNotifier.Services

  @provider_entry {FakeFeatureProvider, []}

  describe "child_specs/3" do
    test "starts infrastructure before the provider, API and consumers" do
      specs = GithubNotifier.Application.child_specs(true, true, {@provider_entry, true})

      assert [
               {Task.Supervisor, name: GithubNotifier.TaskSupervisor},
               %{id: Cachex},
               %{id: FeatureProvider.Cachex},
               GithubNotifier.StatusSender | rest
             ] = specs

      provider_index = Enum.find_index(rest, &(&1 == @provider_entry))
      grpc_index = Enum.find_index(rest, &match?({GRPC.Server.Supervisor, _}, &1))

      consumer_indexes =
        for consumer <- [
              Services.BlockFinishedNotifier,
              Services.PipelineStartedNotifier,
              Services.PipelineFinishedNotifier,
              Services.PipelineSummaryAvailableNotifier,
              GithubNotifier.FeatureProviderInvalidatorWorker
            ] do
          Enum.find_index(rest, &(&1 == {consumer, []}))
        end

      assert provider_index
      assert grpc_index
      refute Enum.any?(consumer_indexes, &is_nil/1)
      assert Enum.all?([grpc_index | consumer_indexes], &(provider_index < &1))
    end

    test "excludes disabled API, consumers and provider" do
      specs = GithubNotifier.Application.child_specs(false, false, {@provider_entry, false})

      assert specs == [
               {Task.Supervisor, name: GithubNotifier.TaskSupervisor},
               %{id: Cachex, start: {Cachex, :start_link, [:store, []]}},
               %{
                 id: FeatureProvider.Cachex,
                 start: {Cachex, :start_link, [:feature_provider_cache, []]}
               },
               GithubNotifier.StatusSender,
               {GithubNotifier.FeatureProviderInvalidatorWorker, []}
             ]
    end
  end

  describe "supervision strategy" do
    test "top-level supervisor uses rest_for_one" do
      state = :sys.get_state(GithubNotifier.Supervisor)
      assert :rest_for_one in Tuple.to_list(state)
    end
  end
end
