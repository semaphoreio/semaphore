defmodule Zebra.Workers.JobRequestFactory.SpecTest do
  use Zebra.DataCase

  alias Zebra.Workers.JobRequestFactory.Spec

  describe ".env_vars" do
    test "when env vars count is insane => stop job processing" do
      envs =
        1..1000
        |> Enum.map(fn index ->
          Semaphore.Jobs.V1alpha.Job.Spec.EnvVar.new(
            name: "A#{index}",
            value: "insane"
          )
        end)

      spec = Semaphore.Jobs.V1alpha.Job.Spec.new(env_vars: envs)

      assert {
               :stop_job_processing,
               "The number of environment variables is higher than 300"
             } = Spec.env_vars(spec)
    end

    test "when env vars count is not insane => encode env vars for agent" do
      spec =
        Semaphore.Jobs.V1alpha.Job.Spec.new(
          env_vars: [
            Semaphore.Jobs.V1alpha.Job.Spec.EnvVar.new(
              name: "A1",
              value: "not-insane"
            )
          ]
        )

      assert {:ok,
              [
                %{"name" => "A1", "value" => "bm90LWluc2FuZQ=="}
              ]} = Spec.env_vars(spec)
    end
  end

  describe ".epilogue" do
    test "epilogue_always_commands are in the spec" do
      spec =
        Semaphore.Jobs.V1alpha.Job.Spec.new(
          epilogue_always_commands: [
            "echo hello"
          ]
        )

      assert {:ok, epilogue} = Spec.epilogue(spec)
      assert epilogue.always_commands == [%{"directive" => "echo hello"}]
    end

    test "epilogue_always_commands are not in the spec" do
      spec =
        Semaphore.Jobs.V1alpha.Job.Spec.new(
          epilogue_commands: [
            "echo hello"
          ]
        )

      assert {:ok, epilogue} = Spec.epilogue(spec)
      assert epilogue.always_commands == [%{"directive" => "echo hello"}]
    end
  end
end
