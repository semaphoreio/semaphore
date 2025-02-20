defmodule Support.Factories.Block do
  def build do
    InternalApi.Plumber.Block.new(
      block_id: Ecto.UUID.generate(),
      name: "Rspec",
      build_req_id: Ecto.UUID.generate(),
      state: :DONE,
      result: :PASSED,
      result_reason: :TEST,
      error_description: "",
      jobs: [
        InternalApi.Plumber.Block.Job.new(
          name: "Rspec 1",
          index: 0,
          job_id: Ecto.UUID.generate(),
          status: "FINISHED",
          result: "STOPPED"
        )
      ]
    )
  end
end
