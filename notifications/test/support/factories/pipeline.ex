defmodule Support.Factories.Pipeline do
  def build(project, workflow) do
    InternalApi.Plumber.Pipeline.new(
      ppl_id: workflow.initial_ppl_id,
      name: "Build & Test",
      project_id: project.metadata.id,
      branch_name: "master",
      commit_sha: "273b85fbebf7a9493af8c4102d40eb059c9fc6e7",
      created_at: Google.Protobuf.Timestamp.new(seconds: 1, nanos: 7),
      pending_at: Google.Protobuf.Timestamp.new(seconds: 1, nanos: 5),
      queuing_at: Google.Protobuf.Timestamp.new(seconds: 1, nanos: 5),
      running_at: Google.Protobuf.Timestamp.new(seconds: 1, nanos: 6),
      stopping_at: nil,
      done_at: Google.Protobuf.Timestamp.new(seconds: 1, nanos: 8),
      state: :RUNNING,
      result: :FAILED,
      hook_id: Ecto.UUID.generate(),
      branch_id: Ecto.UUID.generate(),
      switch_id: Ecto.UUID.generate(),
      working_directory: ".semaphore",
      yaml_file_name: "semaphore.yml",
      result_reason: :TEST
    )
  end
end
