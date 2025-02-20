defmodule Support.Factories do
  def response_meta(code \\ :OK) do
    InternalApi.Projecthub.ResponseMeta.new(
      status:
        InternalApi.Projecthub.ResponseMeta.Status.new(
          code: InternalApi.Projecthub.ResponseMeta.Code.value(code)
        )
    )
  end

  def status(code \\ :OK) do
    InternalApi.Status.new(
      code: Google.Rpc.Code.value(code),
      message: ""
    )
  end

  def project(meta \\ [], spec \\ []) do
    meta_def = [
      id: "12345678-1234-5678-0000-010101010101",
      name: "testproject",
      owner_id: "12345678-1234-5678-0000-010101010101",
      description: "This is a project"
    ]

    meta = Keyword.merge(meta_def, meta) |> InternalApi.Projecthub.Project.Metadata.new()

    spec_def = [
      repository:
        InternalApi.Projecthub.Project.Spec.Repository.new(
          url: "git@github.com:test/test.git",
          run_on: [
            InternalApi.Projecthub.Project.Spec.Repository.RunType.value(:TAGS),
            InternalApi.Projecthub.Project.Spec.Repository.RunType.value(:FORKED_PULL_REQUESTS)
          ],
          forked_pull_requests:
            InternalApi.Projecthub.Project.Spec.Repository.ForkedPullRequests.new(
              allowed_secrets: ["secret-1", "secret-2"]
            ),
          whitelist:
            InternalApi.Projecthub.Project.Spec.Repository.Whitelist.new(
              branches: [],
              tags: ["/v.*/", "foo"]
            ),
          pipeline_file: ".semaphore/semaphore.yml"
        ),
      public: false
    ]

    spec = Keyword.merge(spec_def, spec) |> InternalApi.Projecthub.Project.Spec.new()

    InternalApi.Projecthub.Project.new(metadata: meta, spec: spec)
  end

  def pipeline(params \\ []) do
    alias InternalApi.Plumber.Pipeline

    defaults = [
      ppl_id: "12345678-1234-5678-0000-010101010101",
      project_id: "12345678-1234-5678-0000-010101010101",
      branch_name: "master",
      name: "Pipeline Name",
      hook_id: "12345678-1234-5678-0000-010101010101",
      created_at: Google.Protobuf.Timestamp.new(seconds: 1_522_754_000),
      running_at: Google.Protobuf.Timestamp.new(seconds: 1_522_754_100),
      pending_at: Google.Protobuf.Timestamp.new(seconds: 0),
      queuing_at: Google.Protobuf.Timestamp.new(seconds: 0),
      stopping_at: Google.Protobuf.Timestamp.new(seconds: 0),
      done_at: Google.Protobuf.Timestamp.new(seconds: 1_522_754_220),
      state: Pipeline.State.value(:DONE),
      result: Pipeline.Result.value(:PASSED),
      wf_id: "12345678-1234-5678-0000-010101010101",
      working_directory: ".semaphore",
      yaml_file_name: "semaphore.yml"
    ]

    defaults |> Keyword.merge(params) |> Pipeline.new()
  end
end
