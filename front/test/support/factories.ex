defmodule Support.Factories do
  alias InternalApi.Branch.DescribeResponse, as: BranchDescribeResponse
  alias InternalApi.Organization.Organization
  alias InternalApi.Plumber.TriggeredBy, as: PplTriggeredBy
  alias InternalApi.Plumber.Triggerer
  alias InternalApi.PlumberWF.TriggeredBy, as: WfTriggeredBy

  def branch_describe_response do
    BranchDescribeResponse.new(
      status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
      branch_id: "61c862c3-1ad0-4ce2-95c2-eaf9f472b985",
      branch_name: "dummy-branch",
      project_id: "2"
    )
  end

  def notification(name \\ "test-notification") do
    %Semaphore.Notifications.V1alpha.Notification{
      metadata: %Semaphore.Notifications.V1alpha.Notification.Metadata{
        name: name,
        id: "bb1015dc-23a8-4d4e-a3e4-8b74608dcc1c",
        create_time: 123,
        update_time: 567
      },
      spec: %Semaphore.Notifications.V1alpha.Notification.Spec{
        rules: [
          %Semaphore.Notifications.V1alpha.Notification.Spec.Rule{
            filter: %Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Filter{
              blocks: [],
              branches: ["development"],
              pipelines: [],
              projects: ["about-some-switches"],
              results: ["failed"],
              states: []
            },
            name: "First Rule",
            notify: %Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Notify{
              email: %Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Notify.Email{
                bcc: [],
                cc: [],
                content: "",
                subject: "",
                status:
                  Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Notify.Status.value(
                    :ACTIVE
                  )
              },
              slack: %Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Notify.Slack{
                channels: ["@test"],
                endpoint: "https://hooks.slack.com/services/xxxx",
                message: "",
                status:
                  Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Notify.Status.value(
                    :ACTIVE
                  )
              },
              webhook: nil
            }
          },
          %Semaphore.Notifications.V1alpha.Notification.Spec.Rule{
            filter: %Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Filter{
              blocks: [],
              branches: ["master"],
              pipelines: [],
              projects: ["test-switch", "all-about-switches"],
              results: ["passed"],
              states: []
            },
            name: "Second Rule",
            notify: %Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Notify{
              email: %Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Notify.Email{
                bcc: [],
                cc: [],
                content: "",
                subject: "",
                status:
                  Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Notify.Status.value(
                    :ACTIVE
                  )
              },
              slack: %Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Notify.Slack{
                channels: ["@test2"],
                endpoint: "https://hooks.slack.com/services/xxxx",
                message: "",
                status:
                  Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Notify.Status.value(
                    :ACTIVE
                  )
              },
              webhook: nil
            }
          }
        ]
      },
      status: %Semaphore.Notifications.V1alpha.Notification.Status{failures: []}
    }
  end

  def queue(params \\ []) do
    defaults = [
      id: "3fd07895-e15b-43c4-8ee2-0ad18ce75507",
      name: "Production"
    ]

    defaults |> Keyword.merge(params) |> InternalApi.Plumber.Queue.new()
  end

  def pipeline(params \\ []) do
    alias InternalApi.Plumber.Pipeline

    triggerer_params = Keyword.get(params, :triggerer, [])
    params = Keyword.delete(params, :triggerer)

    defaults = [
      ppl_id: "3fd07895-e15b-43c4-8ee2-0ad18ce75507",
      project_id: "78114608-be8a-465a-b9cd-81970fb802c6",
      branch_name: "master",
      name: "Pipeline Name",
      hook_id: "21212121-be8a-465a-b9cd-81970fb802c6",
      created_at: Google.Protobuf.Timestamp.new(seconds: 1_522_754_000),
      pending_at: Google.Protobuf.Timestamp.new(seconds: 0),
      queuing_at: Google.Protobuf.Timestamp.new(seconds: 0),
      stopping_at: Google.Protobuf.Timestamp.new(seconds: 0),
      running_at: Google.Protobuf.Timestamp.new(seconds: 1_522_754_100),
      done_at: Google.Protobuf.Timestamp.new(seconds: 1_522_754_220),
      state: Pipeline.State.value(:RUNNING),
      wf_id: "2cb61a21-c759-4d50-a45a-1e1eaba8c1bf",
      working_directory: ".semaphore",
      yaml_file_name: "semaphore.yml",
      with_after_task: false,
      triggerer: pipeline_triggerer(triggerer_params)
    ]

    defaults |> Keyword.merge(params) |> InternalApi.Plumber.Pipeline.new()
  end

  def internal_api_status_ok do
    %InternalApi.Status{
      code: Google.Rpc.Code.value(:OK),
      message: ""
    }
  end

  def debug_session(
        debug_id \\ "debug_session_id",
        debugged_job_id \\ "debugged_job_id"
      ) do
    InternalApi.ServerFarm.Job.DebugSession.new(
      debug_session: job(debug_id),
      type: InternalApi.ServerFarm.Job.DebugSessionType.value(:JOB),
      debug_user_id: "user_id",
      debugged_job: job(debugged_job_id)
    )
  end

  def job(
        job_id \\ "21212121-be8a-465a-b9cd-81970fb802c6",
        project_id \\ "78114608-be8a-465a-b9cd-81970fb802c6"
      ) do
    InternalApi.ServerFarm.Job.Job.new(
      id: job_id,
      project_id: project_id,
      branch_id: "2cb61a21-c759-4d50-a45a-1e1eaba8c1bf",
      hook_id: "2cb61a21-c759-4d50-a45a-1e1eaba8c1bf",
      name: "RSpec 342/708",
      ppl_id: "78114608-be8a-465a-b9cd-81970fb802c6",
      timeline:
        InternalApi.ServerFarm.Job.Job.Timeline.new(
          created_at: Google.Protobuf.Timestamp.new(seconds: 1_522_754_259),
          enqueued_at: Google.Protobuf.Timestamp.new(seconds: 1_522_754_260),
          started_at: Google.Protobuf.Timestamp.new(seconds: 1_522_754_261),
          finished_at: Google.Protobuf.Timestamp.new(seconds: 1_522_754_262)
        ),
      state: InternalApi.ServerFarm.Job.Job.State.value(:FINISHED),
      result: InternalApi.ServerFarm.Job.Job.Result.value(:PASSED),
      failure_reason: "",
      build_server: "127.0.0.1",
      self_hosted: false
    )
  end

  def get_signed_url do
    %InternalApi.Artifacthub.GetSignedURLResponse{
      url: "https://storage.googleapis.com/ak76x23qm51kiviwamt8z1jm2snk78"
    }
  end

  def workflow(params \\ []) do
    defaults = [
      wf_id: "2cb61a21-c759-4d50-a45a-1e1eaba8c1bf",
      initial_ppl_id: "3fd07895-e15b-43c4-8ee2-0ad18ce75507",
      project_id: "2cb61a21-c759-4d50-a45a-1e1eaba8c1bf",
      hook_id: "2cb61a21-c759-4d50-a45a-1e1eaba8c1bf",
      requester_id: "2cb61a21-c759-4d50-a45a-1e1eaba8c1bf",
      branch_id: "2cb61a21-c759-4d50-a45a-1e1eaba8c1bf",
      branch_name: "master",
      commit_sha: "abcdefg140f231a42d2953d1225c462e3f3006376",
      created_at: %Google.Protobuf.Timestamp{seconds: 1_522_495_543, nanos: 2},
      triggered_by: 0
    ]

    defaults |> Keyword.merge(params) |> InternalApi.PlumberWF.WorkflowDetails.new()
  end

  def organizations do
    [
      Organization.new(
        org_id: "1",
        name: "RT1",
        org_username: "rt1",
        avatar_url: "avatar.com",
        created_at: Google.Protobuf.Timestamp.new(seconds: 1_522_495_543),
        open_source: false,
        owner_id: "1"
      ),
      Organization.new(
        org_id: "2",
        name: "RT2",
        org_username: "rt2",
        avatar_url: "avatar.com",
        created_at: Google.Protobuf.Timestamp.new(seconds: 1_522_495_543),
        open_source: false,
        owner_id: "2"
      ),
      Organization.new(
        org_id: "3",
        name: "RT3",
        org_username: "rt3",
        avatar_url: "avatar.com",
        created_at: Google.Protobuf.Timestamp.new(seconds: 1_522_495_543),
        open_source: false,
        owner_id: "3"
      ),
      Organization.new(
        org_id: "92be62c2-9cf4-4dad-b168-d6efa6aa5e21",
        name: "Semaphore",
        org_username: "semaphore",
        avatar_url: "avatar.com",
        created_at: Google.Protobuf.Timestamp.new(seconds: 1_522_495_543),
        open_source: false,
        owner_id: "4"
      )
    ]
  end

  def switch_describe_response(_options \\ []) do
    target_prod =
      InternalApi.Gofer.TargetDescription.new(
        name: "Deploy to prod",
        trigger_events: [
          InternalApi.Gofer.TriggerEvent.new(
            processing_result: InternalApi.Gofer.TriggerEvent.ProcessingResult.value(:FAILED),
            triggered_by: "9865c64d-783a-46e1-b659-2194b1d69494",
            triggered_at: Google.Protobuf.Timestamp.new(seconds: 999),
            scheduled_pipeline_id: "1fd07895-e15b-43c4-8ee2-0ad18ce75507",
            processed: true
          ),
          InternalApi.Gofer.TriggerEvent.new(
            processing_result: InternalApi.Gofer.TriggerEvent.ProcessingResult.value(:PASSED),
            triggered_by: "78114608-be8a-465a-b9cd-81970fb802c7",
            triggered_at: Google.Protobuf.Timestamp.new(seconds: 999),
            scheduled_pipeline_id: "2fd07895-e15b-43c4-8ee2-0ad18ce75507",
            processed: false
          ),
          InternalApi.Gofer.TriggerEvent.new(
            processing_result: InternalApi.Gofer.TriggerEvent.ProcessingResult.value(:PASSED),
            triggered_by: "78114608-be8a-465a-b9cd-81970fb802c7",
            triggered_at: Google.Protobuf.Timestamp.new(seconds: 999),
            scheduled_pipeline_id: "3fd07895-e15b-43c4-8ee2-0ad18ce75507",
            processed: true
          )
        ]
      )

    target_stg =
      InternalApi.Gofer.TargetDescription.new(
        name: "Deploy to stg",
        trigger_events: []
      )

    InternalApi.Gofer.DescribeResponse.new(
      response_status:
        InternalApi.Gofer.ResponseStatus.new(
          code: InternalApi.Gofer.ResponseStatus.ResponseCode.value(:OK)
        ),
      ppl_id: "cb8e7d32-85fd-4945-bd80-5578e891fac9",
      switch_id: "c6e4c82e-df20-4bed-b700-f385720af9e2",
      targets: [target_prod, target_stg]
    )
  end

  def branch(params \\ []) do
    defaults = [
      id: "78114608-be8a-465a-b9cd-81970fb802c6",
      name: "master",
      project_id: "78114608-be8a-465a-b9cd-81970fb802c6",
      pr_name: "",
      tag_name: "",
      display_name: "master"
    ]

    defaults |> Keyword.merge(params) |> InternalApi.Branch.Branch.new()
  end

  def projecthub_api_described_project(meta \\ [], public \\ true) do
    meta_def = [
      id: "ee2e6241-f30b-4892-a0d5-bd900b713430",
      name: "clean-code-javascript",
      owner_id: "78114608-be8a-465a-b9cd-81970fb802c7",
      description: "🛁 Clean Code concepts adapted for JavaScript",
      created_at: Google.Protobuf.Timestamp.new(seconds: 1_580_654_045)
    ]

    meta = Keyword.merge(meta_def, meta) |> InternalApi.Projecthub.Project.Metadata.new()

    spec =
      %{
        repository:
          InternalApi.Projecthub.Project.Spec.Repository.new(
            url: "git@github.com:ryanmcdermott/clean-code-javascript.git",
            name: "clean-code-javascript",
            owner: "ryanmcdermott",
            run_on: [
              InternalApi.Projecthub.Project.Spec.Repository.RunType.value(:TAGS),
              InternalApi.Projecthub.Project.Spec.Repository.RunType.value(:FORKED_PULL_REQUESTS),
              InternalApi.Projecthub.Project.Spec.Repository.RunType.value(:DRAFT_PULL_REQUESTS)
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
            pipeline_file: ".semaphore/semaphore.yml",
            public: false
          ),
        visibility: visibility(public),
        cache_id: "65a16553-69d9-480f-b52b-c56e6b12063e",
        artifact_store_id: "118dcd98-97cc-4b31-8690-9c897b0adf46"
      }
      |> InternalApi.Projecthub.Project.Spec.new()

    status =
      InternalApi.Projecthub.Project.Status.new(
        state: InternalApi.Projecthub.Project.Status.State.value(:READY),
        cache:
          InternalApi.Projecthub.Project.Status.Cache.new(
            state: InternalApi.Projecthub.Project.Status.State.value(:READY)
          ),
        artifact_store:
          InternalApi.Projecthub.Project.Status.ArtifactStore.new(
            state: InternalApi.Projecthub.Project.Status.State.value(:READY)
          ),
        repository:
          InternalApi.Projecthub.Project.Status.Repository.new(
            state: InternalApi.Projecthub.Project.Status.State.value(:READY)
          ),
        analysis:
          InternalApi.Projecthub.Project.Status.Analysis.new(
            state: InternalApi.Projecthub.Project.Status.State.value(:READY)
          ),
        permissions:
          InternalApi.Projecthub.Project.Status.Permissions.new(
            state: InternalApi.Projecthub.Project.Status.State.value(:READY)
          )
      )

    InternalApi.Projecthub.Project.new(metadata: meta, spec: spec, status: status)
  end

  defp visibility(true), do: InternalApi.Projecthub.Project.Spec.Visibility.value(:PUBLIC)
  defp visibility(false), do: InternalApi.Projecthub.Project.Spec.Visibility.value(:PRIVATE)

  def organization_describe_response do
    InternalApi.Organization.DescribeResponse.new(
      status: status_ok(),
      organization:
        InternalApi.Organization.Organization.new(
          org_username: "fake-organization",
          name: "Fake Org",
          org_id: "9865c64d-783a-46e1-b659-2194b1d69494",
          created_at: Google.Protobuf.Timestamp.new(seconds: 1_522_495_543),
          quotas: []
        )
    )
  end

  def organization(params \\ []) do
    defaults = [
      name: "Rendered Text",
      org_username: "renderedtext",
      created_at: Google.Protobuf.Timestamp.new(seconds: 1_522_495_543),
      avatar_url: "https://avatars3.githubusercontent.com/u/0?v=4",
      org_id: "78114608-be8a-465a-b9cd-81970fb802c7",
      owner_id: "78114608-be8a-465a-b9cd-81970fb802c7",
      open_source: false,
      deny_member_workflows: false,
      deny_non_member_workflows: false
    ]

    defaults |> Keyword.merge(params) |> InternalApi.Organization.Organization.new()
  end

  def listed_project(params \\ []) do
    defaults = [
      name: "octocat",
      id: "78114608-be8a-465a-b9cd-81970fb802c6",
      description: "The coolest project"
    ]

    metadata =
      defaults
      |> Keyword.merge(params)
      |> InternalApi.Projecthub.Project.Metadata.new()

    InternalApi.Projecthub.Project.new(metadata: metadata)
  end

  def member(params \\ []) do
    defaults = [
      user_id: "78114608-be8a-465a-b9cd-81970fb802c4",
      screen_name: "jane-doe",
      avatar_url: "https://avatars3.githubusercontent.com/u/0?v=4",
      invited_at: Google.Protobuf.Timestamp.new(seconds: 1_522_754_259),
      role: InternalApi.Organization.Member.Role.value(:MEMBER),
      membership_id: "id",
      github_username: "jane-doe",
      github_uid: "20469"
    ]

    defaults |> Keyword.merge(params) |> InternalApi.Organization.Member.new()
  end

  # AMIRE pAZI

  def user(params \\ []) do
    defaults = [
      id: "78114608-be8a-465a-b9cd-81970fb802c5",
      username: "jane-doe",
      name: "Jane",
      avatar_url: "https://avatars3.githubusercontent.com/u/0?v=4",
      github_uid: "githubuid",
      github_login: "jane-doe"
    ]

    defaults |> Keyword.merge(params) |> InternalApi.User.User.new()
  end

  def github_project_user(params \\ []) do
    defaults = [
      id: "githubuid",
      login: "jane-doe",
      avatar_url: "https://avatars3.githubusercontent.com/u/0?v=4",
      email: "m@t.c"
    ]

    defaults |> Keyword.merge(params) |> InternalApi.Guard.ListResponse.User.new()
  end

  def status_ok do
    InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK))
  end

  def status_not_ok(message \\ "") do
    InternalApi.ResponseStatus.new(
      code: InternalApi.ResponseStatus.Code.value(:BAD_PARAM),
      message: message
    )
  end

  def response_meta(code \\ :OK, message \\ "") do
    InternalApi.Projecthub.ResponseMeta.new(
      status:
        InternalApi.Projecthub.ResponseMeta.Status.new(
          code: InternalApi.Projecthub.ResponseMeta.Code.value(code),
          message: message
        )
    )
  end

  def repositories(count), do: repositories() |> Enum.take_random(count)

  def repositories do
    [
      %{
        addable: false,
        description: nil,
        name: "world",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/world.git"
      },
      %{
        addable: true,
        description: nil,
        name: "12factor",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/12factor.git"
      },
      %{
        addable: true,
        description: "Simple tool for managing extra configuration in ruby/rails apps.",
        name: "a9n",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/a9n.git"
      },
      %{
        addable: true,
        description: nil,
        name: "api_for_mobile_in_infakt",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/api_for_mobile_in_infakt.git"
      },
      %{
        addable: true,
        description: "Controller layer for Lotus",
        name: "controller",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/controller.git"
      },
      %{
        addable: true,
        description: "repo for ruby kata",
        name: "dojo",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/dojo.git"
      },
      %{
        addable: true,
        description: "My dotfiles, based on r00k/dotfiles",
        name: "dotfiles",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/dotfiles.git"
      },
      %{
        addable: true,
        description: "My vim configuration stuff, based on ralph/dotvim",
        name: "dotvim",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/dotvim.git"
      },
      %{
        addable: true,
        description: nil,
        name: "effective-carnival",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/effective-carnival.git"
      },
      %{
        addable: true,
        description: nil,
        name: "fluffy-rotary-phone",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/fluffy-rotary-phone.git"
      },
      %{
        addable: true,
        description: nil,
        name: "glowing-parakeet",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/glowing-parakeet.git"
      },
      %{
        addable: true,
        description: "Receives callbacks from build servers. Sends them to front machine.",
        name: "job-callback-broker",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/job-callback-broker.git"
      },
      %{
        addable: true,
        description: "Start, monitor, and observe background worker processes, from Ruby.",
        name: "kamisama",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/kamisama.git"
      },
      %{
        addable: true,
        description:
          "Knapsack splits tests across CI nodes and makes sure that tests will run comparable time on each node.",
        name: "knapsack",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/knapsack.git"
      },
      %{
        addable: true,
        description: nil,
        name: "musical-carnival",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/musical-carnival.git"
      },
      %{
        addable: true,
        description: "Simple plugin for role-based permissions",
        name: "permit_kermit",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/permit_kermit.git"
      },
      %{
        addable: true,
        description: "Jekyll source for my personal blog.",
        name: "radwo.github.io",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/radwo.github.io.git"
      },
      %{
        addable: true,
        description: nil,
        name: "refactored-octo-spoon",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/refactored-octo-spoon.git"
      },
      %{
        addable: true,
        description: nil,
        name: "rt",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/rt.git"
      },
      %{
        addable: true,
        description: "Settings for Sublime Text 2",
        name: "sublime-text-2-user-settings",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/sublime-text-2-user-settings.git"
      },
      %{
        addable: true,
        description: "Simply app to manage office supplies",
        name: "supplismo",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/supplismo.git"
      },
      %{
        addable: true,
        description: "Transform Ruby objects in functional style",
        name: "transproc",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/transproc.git"
      },
      %{
        addable: true,
        description: "Trójmiasto Ruby User Group",
        name: "TRUG",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/TRUG.git"
      },
      %{
        addable: true,
        description: nil,
        name: "ugh",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/ugh.git"
      },
      %{
        addable: false,
        description:
          "Abacus is part of larger project of setting up KPIs for programming and design. Number of issues is one of the KPIs we want to track.",
        name: "abacus",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/abacus.git"
      },
      %{
        addable: false,
        description: "Rails 4 generator of CRUD admin interfaces for existing models.",
        name: "admin_view",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/admin_view.git"
      },
      %{
        addable: false,
        description: "Generate an exrm release for Alpine Docker with ease",
        name: "alpine-release",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/alpine-release.git"
      },
      %{
        addable: false,
        description: nil,
        name: "ansi_html_adapter",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/ansi_html_adapter.git"
      },
      %{
        addable: false,
        description: nil,
        name: "ap-output-parser",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/ap-output-parser.git"
      },
      %{
        addable: false,
        description: "SemaphoreCI Public API v2",
        name: "api",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/api.git"
      },
      %{
        addable: false,
        description: "SemaphoreCI Internal API",
        name: "api-internal",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/api-internal.git"
      },
      %{
        addable: true,
        description: nil,
        name: "api_explorer",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/api_explorer.git"
      },
      %{
        addable: false,
        description: "Semaphore App design templates",
        name: "app-design",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/app-design.git"
      },
      %{
        addable: false,
        description: nil,
        name: "apple-playground",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/apple-playground.git"
      },
      %{
        addable: true,
        description: nil,
        name: "arrow",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/arrow.git"
      },
      %{
        addable: false,
        description: nil,
        name: "artifact-client",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/artifact-client.git"
      },
      %{
        addable: false,
        description: nil,
        name: "artifact-common",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/artifact-common.git"
      },
      %{
        addable: false,
        description: "Interface definition",
        name: "artifact-model",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/artifact-model.git"
      },
      %{
        addable: false,
        description: nil,
        name: "artifact-server",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/artifact-server.git"
      },
      %{
        addable: false,
        description: "Artifacts for semaphore",
        name: "artifacts",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/artifacts.git"
      },
      %{
        addable: false,
        description: "Auth for Gateway",
        name: "auth",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/auth.git"
      },
      %{
        addable: false,
        description:
          "A list of amazingly awesome links, resources, books and videos. Curated by the developers of Semaphore.",
        name: "awesomeness",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/awesomeness.git"
      },
      %{
        addable: false,
        description:
          "An app to help jumpstart a new Rails 4 app. Features Ruby 2.0, PostgreSQL, jQuery, RSpec, Cucumber, user and admin system built with Devise, Facebook login.",
        name: "base-app",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/base-app.git"
      },
      %{
        addable: false,
        description:
          "Basic Rails 5 Application (PostgreSQL, Cucumber, RSpec, Factory Girl, shoulda-matchers, Devise)",
        name: "basic-app",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/basic-app.git"
      },
      %{
        addable: false,
        description:
          "Easy and extensible benchmarking in Elixir providing you with lots of statistics!",
        name: "benchee",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/benchee.git"
      },
      %{
        addable: false,
        description: "Bends time, space, and virtual machines",
        name: "bender",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/bender.git"
      },
      %{
        addable: false,
        description: nil,
        name: "bender-kvm",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/bender-kvm.git"
      },
      %{
        addable: false,
        description: "Handles billing for Semaphore 2.0",
        name: "billing",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/billing.git"
      },
      %{
        addable: false,
        description: "Blowfish does server hardening and access setup.",
        name: "blowfish",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/blowfish.git"
      },
      %{
        addable: false,
        description: "KVM image deployment",
        name: "bonfire",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/bonfire.git"
      },
      %{
        addable: false,
        description: "Measuring Box usage from Semaphore CI",
        name: "box-metrics",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/box-metrics.git"
      },
      %{
        addable: false,
        description: "Ruby client for box-metrics service.",
        name: "box-metrics-client",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/box-metrics-client.git"
      },
      %{
        addable: false,
        description: "A performance dashboard for box-metrics Postgres DB",
        name: "box-metrics-pghero",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/box-metrics-pghero.git"
      },
      %{
        addable: false,
        description: "Simple, no bullshit development box",
        name: "boxbox",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/boxbox.git"
      },
      %{
        addable: false,
        description: "This is the public Branch Page on Semaphore",
        name: "branch_page",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/branch_page.git"
      },
      %{
        addable: false,
        description: nil,
        name: "build-server-health-check",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/build-server-health-check.git"
      },
      %{
        addable: false,
        description: "API for Semaphore's build servers",
        name: "build-servers-api",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/build-servers-api.git"
      },
      %{
        addable: true,
        description: "Scripts for polling caches to provision or destroy",
        name: "cache-poll",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/cache-poll.git"
      },
      %{
        addable: false,
        description: "Cache Hub stores credentials for cache-cli",
        name: "cachehub",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/cachehub.git"
      },
      %{
        addable: false,
        description: "Various cheatsheets in nice Markdown format.",
        name: "cheatsheets",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/cheatsheets.git"
      },
      %{
        addable: false,
        description: "Centralized cluster managment for Semaphore 2.0",
        name: "chmura",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/chmura.git"
      },
      %{
        addable: false,
        description: "Semaphore Classic Command Line Interface",
        name: "cli",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/cli.git"
      },
      %{
        addable: false,
        description: "HTML + CSS mockups for Semaphore Community.",
        name: "community-design",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/community-design.git"
      },
      %{
        addable: false,
        description: "Source files of tutorials.",
        name: "community-tutorials",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/community-tutorials.git"
      },
      %{
        addable: false,
        description: nil,
        name: "community-visoft-emberjs-start",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/community-visoft-emberjs-start.git"
      },
      %{
        addable: false,
        description: "Semaphore community site.",
        name: "community-web",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/community-web.git"
      },
      %{
        addable: false,
        description: "Service for complex number operations",
        name: "complex-number-service",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/complex-number-service.git"
      },
      %{
        addable: true,
        description: "Continuous monitoring for Semaphore2 UI",
        name: "cont-monitoring",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/cont-monitoring.git"
      },
      %{
        addable: false,
        description: "Create + Read API for contribscore demo.",
        name: "contribscore-api",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/contribscore-api.git"
      },
      %{
        addable: false,
        description:
          "Contribution score µservice that collects events and stores them in a database.",
        name: "contribscore-event-collector",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/contribscore-event-collector.git"
      },
      %{
        addable: false,
        description: "Contribution score µservice that listens for webhooks from GitHub.",
        name: "contribscore-github-pr-receiver",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/contribscore-github-pr-receiver.git"
      },
      %{
        addable: false,
        description:
          "Contribution score µservices that react to raw events and build up data for the contribscore database.",
        name: "contribscore-score-activity-router",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/contribscore-score-activity-router.git"
      },
      %{
        addable: false,
        description: "Contribution score µservice that listens for deploy hooks from Semaphore.",
        name: "contribscore-semaphore-deploy-receiver",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/contribscore-semaphore-deploy-receiver.git"
      },
      %{
        addable: false,
        description: "Front-end for contribution score demo project.",
        name: "contribscore-web",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/contribscore-web.git"
      },
      %{
        addable: false,
        description: "Cucumber configuration injection for autoparallelism in a gem.",
        name: "cucumber_booster_config",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/cucumber_booster_config.git"
      },
      %{
        addable: false,
        description: "Dashboards",
        name: "dash",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/dash.git"
      },
      %{
        addable: true,
        description: "Dashboard Hub stores dashboards for Semaphore 2.0",
        name: "dashboardhub",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/dashboardhub.git"
      },
      %{
        addable: false,
        description: "Sends KPI-related data from our internal systems to Databox.",
        name: "databox-pusher",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/databox-pusher.git"
      },
      %{
        addable: true,
        description: "Steps required to bring deploy page up to par with build page",
        name: "deploy-page-todo",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/deploy-page-todo.git"
      },
      %{
        addable: false,
        description: "Semaphore development machine using Vagrant",
        name: "dev-box",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/dev-box.git"
      },
      %{
        addable: false,
        description: "A testing environment for future DevOps engineers",
        name: "devops-funbox",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/devops-funbox.git"
      },
      %{
        addable: false,
        description: "Test docker caching on semaphore ",
        name: "docker-caching",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/docker-caching.git"
      },
      %{
        addable: false,
        description: "Log visualization and parsing",
        name: "docker-elk",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/docker-elk.git"
      },
      %{
        addable: false,
        description: "Dockerized Job Runner",
        name: "docker-job-runner",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/docker-job-runner.git"
      },
      %{
        addable: false,
        description: "Java project for screencast",
        name: "docker-play",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/docker-play.git"
      },
      %{
        addable: false,
        description: nil,
        name: "docker-puller",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/docker-puller.git"
      },
      %{
        addable: false,
        description: nil,
        name: "dockerhub",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/dockerhub.git"
      },
      %{
        addable: false,
        description: "Any text which we need to collaborate on.",
        name: "docs",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/docs.git"
      },
      %{
        addable: false,
        description: "Docs writing management",
        name: "docs-pm",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/docs-pm.git"
      },
      %{
        addable: true,
        description: "S2 projects for documentation",
        name: "docsV2",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/docsV2.git"
      },
      %{
        addable: true,
        description: nil,
        name: "DocsV2projects",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/DocsV2projects.git"
      },
      %{
        addable: false,
        description: nil,
        name: "dotfiles",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/dotfiles.git"
      },
      %{
        addable: true,
        description: "Test download performance for services like Amazon S3.",
        name: "downloader",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/downloader.git"
      },
      %{
        addable: false,
        description: "End-to-End tests for Semaphore",
        name: "e2e",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/e2e.git"
      },
      %{
        addable: false,
        description: nil,
        name: "elixir-base-image",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/elixir-base-image.git"
      },
      %{
        addable: false,
        description: "Common utility functions for elixir services",
        name: "elixir-util",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/elixir-util.git"
      },
      %{
        addable: false,
        description: "erlang process ecosystem and how to navigate through it",
        name: "elixir_erlang_process",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/elixir_erlang_process.git"
      },
      %{
        addable: false,
        description: nil,
        name: "engineering-playbook",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/engineering-playbook.git"
      },
      %{
        addable: false,
        description: "Example: how to change env var in running beam",
        name: "env-var-live-update",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/env-var-live-update.git"
      },
      %{
        addable: false,
        description: "box-metrics client for Elixir applications",
        name: "ex-box-metrics-client",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/ex-box-metrics-client.git"
      },
      %{
        addable: false,
        description: nil,
        name: "ex-job-logs",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/ex-job-logs.git"
      },
      %{
        addable: false,
        description: "💯 percent reliable microservice communication",
        name: "ex-tackle",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/ex-tackle.git"
      },
      %{
        addable: false,
        description: nil,
        name: "ex-thrift-serializer",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/ex-thrift-serializer.git"
      },
      %{
        addable: false,
        description: "Thrift HTTP transport for Elixir",
        name: "ex-thttpt",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/ex-thttpt.git"
      },
      %{
        addable: false,
        description: "Watchman is your friend who monitors your processes so you don't have to",
        name: "ex-watchman",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/ex-watchman.git"
      },
      %{
        addable: false,
        description: "Executes stuff",
        name: "executor",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/executor.git"
      },
      %{
        addable: false,
        description: "Interactive elixir based shell client",
        name: "ex_ssh_client",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/ex_ssh_client.git"
      },
      %{
        addable: false,
        description: nil,
        name: "feature-requests",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/feature-requests.git"
      },
      %{
        addable: false,
        description: nil,
        name: "front-statsd",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/front-statsd.git"
      },
      %{
        addable: false,
        description: "Receives Git Hooks on Semaphore 2.0 and Stores them in a Rabbit queue",
        name: "git-hook-broker",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/git-hook-broker.git"
      },
      %{
        addable: true,
        description: "github debug script https://github-debug.com/",
        name: "github-debug",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/github-debug.git"
      },
      %{
        addable: true,
        description: nil,
        name: "github_notifier",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/github_notifier.git"
      },
      %{
        addable: false,
        description: "Service that implements switch feature for pipelines concatenation",
        name: "gofer",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/gofer.git"
      },
      %{
        addable: true,
        description: "Go project used for learning Semaphore 2.0",
        name: "goproject",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/goproject.git"
      },
      %{
        addable: true,
        description:
          "https://semaphoreci.com/renderedtext/grafana_dashboards - https://semaphore.grafana.net",
        name: "grafana_dashboards",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/grafana_dashboards.git"
      },
      %{
        addable: false,
        description: "Getting started Kubernetes and GRPC demo project",
        name: "grpc-demo",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/grpc-demo.git"
      },
      %{
        addable: false,
        description: "The Elixir implementation of gRPC",
        name: "grpc-elixir",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/grpc-elixir.git"
      },
      %{
        addable: false,
        description: "Stress testing tony612/grpc-elixir implementation",
        name: "grpc-stress",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/grpc-stress.git"
      },
      %{
        addable: true,
        description: "Authorization service for Semaphore 2.0",
        name: "guard",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/guard.git"
      },
      %{
        addable: false,
        description: "Metric usage example",
        name: "hello-metric",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/hello-metric.git"
      },
      %{
        addable: false,
        description: nil,
        name: "hello-package-managers",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/hello-package-managers.git"
      },
      %{
        addable: false,
        description: nil,
        name: "hello-thrift",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/hello-thrift.git"
      },
      %{
        addable: false,
        description: nil,
        name: "helm-charts",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/helm-charts.git"
      },
      %{
        addable: false,
        description: "campfire bot",
        name: "hoist",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/hoist.git"
      },
      %{
        addable: false,
        description: "Our witty bot",
        name: "hubot",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/hubot.git"
      },
      %{
        addable: true,
        description: nil,
        name: "ice",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/ice.git"
      },
      %{
        addable: false,
        description: "Image upload & hosting for Semaphore Community.",
        name: "imagecloud",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/imagecloud.git"
      },
      %{
        addable: false,
        description:
          "It's not an issue, nor a feature request (wealth of info that's coming out of support conversations and personal obeservations).",
        name: "improvement-proposals",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/improvement-proposals.git"
      },
      %{
        addable: false,
        description: "Incident Score",
        name: "incident_score",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/incident_score.git"
      },
      %{
        addable: false,
        description: "Inframan - The amazing infrastructure do-it-all tool",
        name: "inframan",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/inframan.git"
      },
      %{
        addable: false,
        description: "Semaphore's Ingress templates ",
        name: "ingresses",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/ingresses.git"
      },
      %{
        addable: false,
        description: nil,
        name: "insider",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/insider.git"
      },
      %{
        addable: true,
        description: "Semaphore insights microservice",
        name: "insights",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/insights.git"
      },
      %{
        addable: true,
        description: nil,
        name: "insights-generated-client",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/insights-generated-client.git"
      },
      %{
        addable: false,
        description: nil,
        name: "insights-receiver",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/insights-receiver.git"
      },
      %{
        addable: false,
        description: nil,
        name: "insights-statsd",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/insights-statsd.git"
      },
      %{
        addable: true,
        description: nil,
        name: "insights_client",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/insights_client.git"
      },
      %{
        addable: false,
        description: nil,
        name: "inspinia",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/inspinia.git"
      },
      %{
        addable: true,
        description:
          "Protobuffer files describing the internal GRPC interface exposed by Semaphore services.",
        name: "internal_api",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/internal_api.git"
      },
      %{
        addable: false,
        description: "Versioned stubs for the Internal API",
        name: "internal_api_stubs",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/internal_api_stubs.git"
      },
      %{
        addable: false,
        description: "Place where we keep our issues. Big and small.",
        name: "issues",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/issues.git"
      },
      %{
        addable: false,
        description: "Job Callback handler",
        name: "job-callback",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/job-callback.git"
      },
      %{
        addable: false,
        description: "Receives callbacks from build servers. Sends them to front machine.",
        name: "job-callback-broker",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/job-callback-broker.git"
      },
      %{
        addable: false,
        description: nil,
        name: "job-dispatcher",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/job-dispatcher.git"
      },
      %{
        addable: false,
        description: "Ruby client for job dispatcher",
        name: "job-dispatcher-client",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/job-dispatcher-client.git"
      },
      %{
        addable: false,
        description: "JobLog API. Keeps logs safe and fast!",
        name: "job-logs",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/job-logs.git"
      },
      %{
        addable: false,
        description: nil,
        name: "job-pool",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/job-pool.git"
      },
      %{
        addable: false,
        description: nil,
        name: "job-pool-client",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/job-pool-client.git"
      },
      %{
        addable: false,
        description:
          "A simple proxy service which serves as a jump point when a network fragmentation occurs",
        name: "job-proxy",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/job-proxy.git"
      },
      %{
        addable: false,
        description: "Job Runner Pool",
        name: "job-runner-pool",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/job-runner-pool.git"
      },
      %{
        addable: false,
        description: nil,
        name: "job-scheduling-metric",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/job-scheduling-metric.git"
      },
      %{
        addable: false,
        description: "Client for JobLogs service",
        name: "job_logs_client",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/job_logs_client.git"
      },
      %{
        addable: true,
        description: "Public Job page that shows information about individual job",
        name: "job_page",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/job_page.git"
      },
      %{
        addable: false,
        description: "Runs jobs in a container",
        name: "job_runner",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/job_runner.git"
      },
      %{
        addable: false,
        description: "An api for job runner.",
        name: "job_runner_api",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/job_runner_api.git"
      },
      %{
        addable: false,
        description: "\"more\"/\"less\" style truncator for jQuery that handles HTML gracefully.",
        name: "jquery.truncator.js",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/jquery.truncator.js.git"
      },
      %{
        addable: false,
        description: "Job runner zwei",
        name: "jr2",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/jr2.git"
      },
      %{
        addable: false,
        description: nil,
        name: "just-to-test",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/just-to-test.git"
      },
      %{
        addable: false,
        description: nil,
        name: "k8s",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/k8s.git"
      },
      %{
        addable: false,
        description: "CI/CD with Kubernetes and Semaphore Ebook",
        name: "k8s-cicd-book",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/k8s-cicd-book.git"
      },
      %{
        addable: true,
        description: nil,
        name: "kaosz",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/kaosz.git"
      },
      %{
        addable: false,
        description: "Even distribution of test files in parallel threads.",
        name: "katyusha",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/katyusha.git"
      },
      %{
        addable: true,
        description: nil,
        name: "konteh-todo-app",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/konteh-todo-app.git"
      },
      %{
        addable: true,
        description: nil,
        name: "konteh-todo-app-complete",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/konteh-todo-app-complete.git"
      },
      %{
        addable: true,
        description: "You can launch things into production by clicking here 👉",
        name: "launchpad",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/launchpad.git"
      },
      %{
        addable: false,
        description: nil,
        name: "log-mediator",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/log-mediator.git"
      },
      %{
        addable: true,
        description: nil,
        name: "log-mediator-client",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/log-mediator-client.git"
      },
      %{
        addable: true,
        description: nil,
        name: "log-model",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/log-model.git"
      },
      %{
        addable: true,
        description: nil,
        name: "log-upload-client",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/log-upload-client.git"
      },
      %{
        addable: false,
        description: nil,
        name: "log-upload-reaktor",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/log-upload-reaktor.git"
      },
      %{
        addable: true,
        description: nil,
        name: "logger_librato_backend",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/logger_librato_backend.git"
      },
      %{
        addable: false,
        description: "Service responsible for Job Logs",
        name: "loghub",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/loghub.git"
      },
      %{
        addable: false,
        description: "Logman — Lightweight abstraction for formatted logging",
        name: "logman",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/logman.git"
      },
      %{
        addable: true,
        description: nil,
        name: "mailing-client",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/mailing-client.git"
      },
      %{
        addable: true,
        description: nil,
        name: "mailing-model",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/mailing-model.git"
      },
      %{
        addable: true,
        description: nil,
        name: "mailing-server",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/mailing-server.git"
      },
      %{
        addable: false,
        description: "Contains Makefile used to install and configure Metric servers",
        name: "metric-node-install",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/metric-node-install.git"
      },
      %{
        addable: true,
        description: nil,
        name: "metrix",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/metrix.git"
      },
      %{
        addable: false,
        description: nil,
        name: "mf",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/mf.git"
      },
      %{
        addable: false,
        description: "Scripts for setting up a new virtual machine for development",
        name: "mkvm",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/mkvm.git"
      },
      %{
        addable: false,
        description: nil,
        name: "ml2oss",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/ml2oss.git"
      },
      %{
        addable: true,
        description: "Monitors US - Germany network routes",
        name: "mtr-monitor",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/mtr-monitor.git"
      },
      %{
        addable: false,
        description: "Test YAML file with multiple blocks",
        name: "multi-block-pipeline",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/multi-block-pipeline.git"
      },
      %{
        addable: false,
        description: "Pimp your Mac to fit Rendered Text toolchain",
        name: "my-mac",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/my-mac.git"
      },
      %{
        addable: false,
        description: nil,
        name: "nb-toolbox",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/nb-toolbox.git"
      },
      %{
        addable: false,
        description:
          "A net-ssh extension library that provides an API for programmatically interacting with a login shell",
        name: "net-ssh-shell",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/net-ssh-shell.git"
      },
      %{
        addable: false,
        description: "Notification center for Semaphore 2.0 projects",
        name: "notifications",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/notifications.git"
      },
      %{
        addable: false,
        description: nil,
        name: "noz",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/noz.git"
      },
      %{
        addable: false,
        description: "Groundwork for recording user activity",
        name: "nsa",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/nsa.git"
      },
      %{
        addable: false,
        description: nil,
        name: "nsa-explorer",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/nsa-explorer.git"
      },
      %{
        addable: false,
        description: "A Ruby client for the NSA service",
        name: "nsa_client",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/nsa_client.git"
      },
      %{
        addable: true,
        description: nil,
        name: "object-store-client",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/object-store-client.git"
      },
      %{
        addable: true,
        description: nil,
        name: "object-store-common",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/object-store-common.git"
      },
      %{
        addable: true,
        description: "Deletion micro-service for object-store-server",
        name: "object-store-deleter",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/object-store-deleter.git"
      },
      %{
        addable: true,
        description: nil,
        name: "object-store-model",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/object-store-model.git"
      },
      %{
        addable: true,
        description: nil,
        name: "object-store-server",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/object-store-server.git"
      },
      %{
        addable: false,
        description: "Current company, team and personal OKRs.",
        name: "okrs",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/okrs.git"
      },
      %{
        addable: false,
        description: "Showcase of Open Source projects built by the Semaphore team",
        name: "open-source",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/open-source.git"
      },
      %{
        addable: true,
        description: nil,
        name: "oracle-client",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/oracle-client.git"
      },
      %{
        addable: true,
        description: nil,
        name: "oracle-model",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/oracle-model.git"
      },
      %{
        addable: true,
        description: nil,
        name: "oracle-model-generated-client",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/oracle-model-generated-client.git"
      },
      %{
        addable: true,
        description: "Where we ask for Semaphore performance indicators divine advice",
        name: "oracle-server",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/oracle-server.git"
      },
      %{
        addable: true,
        description: "Takes care of timeouts and retries for given blocks of code.",
        name: "outside",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/outside.git"
      },
      %{
        addable: false,
        description: "Header service for Semaphore 2.0 pages",
        name: "page_header",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/page_header.git"
      },
      %{
        addable: false,
        description: "Temporary storage for user repositories (holds snapshots)",
        name: "paparazzo",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/paparazzo.git"
      },
      %{
        addable: false,
        description: "Cron like, periodic workflow scheduler ",
        name: "periodic-scheduler",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/periodic-scheduler.git"
      },
      %{
        addable: true,
        description: "The spy",
        name: "perry",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/perry.git"
      },
      %{
        addable: false,
        description: nil,
        name: "pipelines-test-repo-1",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/pipelines-test-repo-1.git"
      },
      %{
        addable: false,
        description: nil,
        name: "pipelines-test-repo-auto-call",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/pipelines-test-repo-auto-call.git"
      },
      %{
        addable: false,
        description: "Standalone page to show Pipeline",
        name: "pipeline_page",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/pipeline_page.git"
      },
      %{
        addable: false,
        description: "Pizza Coding Challenge for Konteh 2017",
        name: "pizza-challenge",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/pizza-challenge.git"
      },
      %{
        addable: false,
        description: "Plakatt siluje nerođene bebe!!!",
        name: "plakatt",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/plakatt.git"
      },
      %{
        addable: false,
        description: "Learn to play! The Rendered Text employee playbook.",
        name: "playbook",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/playbook.git"
      },
      %{
        addable: false,
        description: "Pipeline service family",
        name: "plumber",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/plumber.git"
      },
      %{
        addable: false,
        description: "Service which serves as public HTTP API for Pipelines service",
        name: "plumber-public",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/plumber-public.git"
      },
      %{
        addable: false,
        description: "Big issues on Semaphore",
        name: "post-mortems",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/post-mortems.git"
      },
      %{
        addable: false,
        description: "Elixir dependency for creating NSA tracking links",
        name: "prism",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/prism.git"
      },
      %{
        addable: false,
        description: "Private instance of slow-specs-app for CI experiments.",
        name: "private-slow-specs-app",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/private-slow-specs-app.git"
      },
      %{
        addable: false,
        description: "Private Project For Vcr Tests",
        name: "private_project_for_vcr_tests",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/private_project_for_vcr_tests.git"
      },
      %{
        addable: false,
        description: "Product team playbook",
        name: "product-playbook",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/product-playbook.git"
      },
      %{
        addable: false,
        description: "https://semaphore.semaphoreci.com/projects/projecthub-rest-api",
        name: "projecthub-rest-api",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/projecthub-rest-api.git"
      },
      %{
        addable: false,
        description: nil,
        name: "projects",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/projects.git"
      },
      %{
        addable: false,
        description: "Project Page",
        name: "front",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/front.git"
      },
      %{
        addable: false,
        description: nil,
        name: "provisioner",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/provisioner.git"
      },
      %{
        addable: false,
        description: "Exposes a JSON API based on a set of GRPC APIs",
        name: "public-api-gateway",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/public-api-gateway.git"
      },
      %{
        addable: true,
        description: "Semaphore Docs external resources",
        name: "public-assets",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/public-assets.git"
      },
      %{
        addable: false,
        description: nil,
        name: "public_api",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/public_api.git"
      },
      %{
        addable: false,
        description: nil,
        name: "pudelko",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/pudelko.git"
      },
      %{
        addable: false,
        description: "Rails Testing Grader website",
        name: "rails-grader",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/rails-grader.git"
      },
      %{
        addable: false,
        description: "Mirror of deleted 100hz/rails-settings",
        name: "rails-settings",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/rails-settings.git"
      },
      %{
        addable: true,
        description: "HTML visualization of API specifications",
        name: "raml_visualizer",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/raml_visualizer.git"
      },
      %{
        addable: false,
        description: "Demo application that demonstrates how to use React and Redux",
        name: "react-redux-demo",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/react-redux-demo.git"
      },
      %{
        addable: false,
        description: "Graphic files for our website & more.",
        name: "renderedtext-design",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/renderedtext-design.git"
      },
      %{
        addable: false,
        description: "Rendered Text website and blog",
        name: "renderedtext.com",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/renderedtext.com.git"
      },
      %{
        addable: false,
        description: "render_async lets you include pages asynchronously with AJAX",
        name: "render_async",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/render_async.git"
      },
      %{
        addable: false,
        description: "Repository analysis gem for Semaphore.",
        name: "repo-analysis",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/repo-analysis.git"
      },
      %{
        addable: false,
        description: nil,
        name: "riffed",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/riffed.git"
      },
      %{
        addable: false,
        description: nil,
        name: "rpg",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/rpg.git"
      },
      %{
        addable: false,
        description: nil,
        name: "rpg-marko-b",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/rpg-marko-b.git"
      },
      %{
        addable: false,
        description: "Infrastructure for creating maintaining private rubygems mirror",
        name: "rubygems-mirror",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/rubygems-mirror.git"
      },
      %{
        addable: false,
        description: "macos-build",
        name: "s2-macos",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/s2-macos.git"
      },
      %{
        addable: false,
        description: "Semaphore 2.0 Build Platform",
        name: "s2-platform",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/s2-platform.git"
      },
      %{
        addable: false,
        description:
          "This repository contains links to all relevant Semaphore 2.0 administrative sites.",
        name: "s2admin",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/s2admin.git"
      },
      %{
        addable: false,
        description: nil,
        name: "s2docker_pull_local",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/s2docker_pull_local.git"
      },
      %{
        addable: false,
        description: nil,
        name: "s2_builder_metric",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/s2_builder_metric.git"
      },
      %{
        addable: false,
        description: "You can launch things into testing envs by clicking here 👉",
        name: "sandbox",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/sandbox.git"
      },
      %{
        addable: false,
        description: "Manages secrets on Semaphore 2.0",
        name: "secrethub",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/secrethub.git"
      },
      %{
        addable: true,
        description: nil,
        name: "secretsInvalid",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/secretsInvalid.git"
      },
      %{
        addable: false,
        description: nil,
        name: "security",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/security.git"
      },
      %{
        addable: false,
        description: "Semaphore front-end",
        name: "semaphore",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/semaphore.git"
      },
      %{
        addable: false,
        description: "CCTray API endpoint for Semaphore written in Go",
        name: "semaphore-api",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/semaphore-api.git"
      },
      %{
        addable: false,
        description: "Semaphore blog",
        name: "semaphore-blog",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/semaphore-blog.git"
      },
      %{
        addable: false,
        description: "Tools for creating a Semaphore build server.",
        name: "semaphore-build-server",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/semaphore-build-server.git"
      },
      %{
        addable: false,
        description: "Chef cookbooks used on Semaphore platform",
        name: "semaphore-chef",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/semaphore-chef.git"
      },
      %{
        addable: true,
        description: nil,
        name: "semaphore-client",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/semaphore-client.git"
      },
      %{
        addable: false,
        description: "HTML+CSS mockups.",
        name: "semaphore-design",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/semaphore-design.git"
      },
      %{
        addable: false,
        description: "Documentation site for Semaphore.",
        name: "semaphore-docs-new",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/semaphore-docs-new.git"
      },
      %{
        addable: false,
        description:
          "µservice for collecting KPI data from Semaphore and sending it to dashboard.",
        name: "semaphore-kpis",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/semaphore-kpis.git"
      },
      %{
        addable: false,
        description: "Making and deploying Semaphore build environments",
        name: "semaphore-lxc",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/semaphore-lxc.git"
      },
      %{
        addable: false,
        description:
          "Script collection which might help with adjusting Semaphore environment for a specific project",
        name: "semaphore-scripts",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/semaphore-scripts.git"
      },
      %{
        addable: false,
        description: "Semaphore 2.0 website.",
        name: "semaphore-website-v5",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/semaphore-website-v5.git"
      },
      %{
        addable: false,
        description: "Semaphore 2.0. // Modern CI link 👉",
        name: "semaphore2",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/semaphore2.git"
      },
      %{
        addable: false,
        description: "Redirection to semaphoreci.com",
        name: "semaphoreapp",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/semaphoreapp.git"
      },
      %{
        addable: false,
        description: "List of all the things we have created and support.",
        name: "services",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/services.git"
      },
      %{
        addable: false,
        description: "Semaphore website on WordPress.",
        name: "site",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/site.git"
      },
      %{
        addable: false,
        description: "Code snippets in Ruby.",
        name: "snippets",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/snippets.git"
      },
      %{
        addable: false,
        description: "Staging factory for semaphore front",
        name: "staging_factory",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/staging_factory.git"
      },
      %{
        addable: false,
        description: nil,
        name: "stamp",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/stamp.git"
      },
      %{
        addable: false,
        description: nil,
        name: "statsd",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/statsd.git"
      },
      %{
        addable: false,
        description: "Workflow triggering infrastructure - listeners",
        name: "stethoscope",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/stethoscope.git"
      },
      %{
        addable: false,
        description: "Small Elixir microservice for tracking data about Semaphore subscriptions",
        name: "subscription-kpi",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/subscription-kpi.git"
      },
      %{
        addable: false,
        description: "Friendly support bot for our Slack chatroom.",
        name: "support-bot",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/support-bot.git"
      },
      %{
        addable: false,
        description: "Our support playbook.",
        name: "support-playbook",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/support-playbook.git"
      },
      %{
        addable: false,
        description: nil,
        name: "support-recruiting",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/support-recruiting.git"
      },
      %{
        addable: false,
        description: "Sys2app - System environment to Application environment",
        name: "sys2app",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/sys2app.git"
      },
      %{
        addable: true,
        description: "💯 percent reliable microservice communication",
        name: "tackle",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/tackle.git"
      },
      %{
        addable: false,
        description: nil,
        name: "task16",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/task16.git"
      },
      %{
        addable: false,
        description: "Test-boosters admin page extension",
        name: "tb-diagnostic",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/tb-diagnostic.git"
      },
      %{
        addable: true,
        description: "Auto Parallelization - runs test files in multiple jobs",
        name: "test-boosters",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/test-boosters.git"
      },
      %{
        addable: false,
        description: nil,
        name: "test-boosters-tests",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/test-boosters-tests.git"
      },
      %{
        addable: true,
        description: nil,
        name: "test-switch",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/test-switch.git"
      },
      %{
        addable: true,
        description: "Test and profile testboosters",
        name: "test-tesboosters",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/test-tesboosters.git"
      },
      %{
        addable: false,
        description: "Test unit parser for Semaphore",
        name: "test-unit-parser",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/test-unit-parser.git"
      },
      %{
        addable: false,
        description: "A test-unit runner that reports test result in TAP.",
        name: "test-unit-runner-tap",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/test-unit-runner-tap.git"
      },
      %{
        addable: true,
        description: "To test yml projects on Semaphore",
        name: "test-yml",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/test-yml.git"
      },
      %{
        addable: false,
        description: nil,
        name: "testapp-capybara-webkit",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/testapp-capybara-webkit.git"
      },
      %{
        addable: false,
        description: nil,
        name: "testapp-casper",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/testapp-casper.git"
      },
      %{
        addable: false,
        description: nil,
        name: "testapp-envvars",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/testapp-envvars.git"
      },
      %{
        addable: false,
        description: nil,
        name: "testapp-gitpull",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/testapp-gitpull.git"
      },
      %{
        addable: false,
        description: nil,
        name: "testapp-mongodb",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/testapp-mongodb.git"
      },
      %{
        addable: false,
        description: nil,
        name: "testapp-mongodb-mongomapper",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/testapp-mongodb-mongomapper.git"
      },
      %{
        addable: false,
        description: nil,
        name: "testapp-mysql",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/testapp-mysql.git"
      },
      %{
        addable: false,
        description: "Small app to test node.js support on Semaphore.",
        name: "testapp-nodejs",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/testapp-nodejs.git"
      },
      %{
        addable: false,
        description: nil,
        name: "testapp-private-gems",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/testapp-private-gems.git"
      },
      %{
        addable: false,
        description: nil,
        name: "testapp-solr",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/testapp-solr.git"
      },
      %{
        addable: false,
        description: nil,
        name: "testapp-sphinx",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/testapp-sphinx.git"
      },
      %{
        addable: false,
        description: nil,
        name: "testapp-sqlite",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/testapp-sqlite.git"
      },
      %{
        addable: false,
        description: nil,
        name: "testapp-testunit",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/testapp-testunit.git"
      },
      %{
        addable: false,
        description: nil,
        name: "testapp-testunit-rspec",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/testapp-testunit-rspec.git"
      },
      %{
        addable: false,
        description: "Thrift to binary serialization and deserialization",
        name: "thrift-serializer",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/thrift-serializer.git"
      },
      %{
        addable: false,
        description: "Use thrift models in tackle based communication",
        name: "thrift-with-tackle",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/thrift-with-tackle.git"
      },
      %{
        addable: false,
        description: "Generate thrift clients like a pro.",
        name: "thrifter",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/thrifter.git"
      },
      %{
        addable: true,
        description: "Demo service for automatic client generation",
        name: "thrifter-demo",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/thrifter-demo.git"
      },
      %{
        addable: false,
        description: nil,
        name: "thrifter-demo-generated-client",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/thrifter-demo-generated-client.git"
      },
      %{
        addable: false,
        description: "Make office TVs great again.",
        name: "tv",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/tv.git"
      },
      %{
        addable: false,
        description: "Ubuntu 18.04 Image for S2.0",
        name: "ubuntu1804",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/ubuntu1804.git"
      },
      %{
        addable: true,
        description: "Keep track of agent usage in Semaphore 2.0",
        name: "usage",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/usage.git"
      },
      %{
        addable: false,
        description: "From zero to deployed µService in 5 minutes ☄️",
        name: "usvc",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/usvc.git"
      },
      %{
        addable: true,
        description: "I'm delivering your google cloud costs to Slack",
        name: "vampyri-bot",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/vampyri-bot.git"
      },
      %{
        addable: false,
        description: "Vim functions to run RSpec and Cucumber on the current cursor or file.",
        name: "vim-bdd",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/vim-bdd.git"
      },
      %{
        addable: true,
        description: "Microservice for sending waiting time to users on weekly basis",
        name: "waiting-weekly",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/waiting-weekly.git"
      },
      %{
        addable: false,
        description: "Watchman is your friend who monitors your processes so you don't have to",
        name: "watchman",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/watchman.git"
      },
      %{
        addable: true,
        description: "UI for Semaphore workflows",
        name: "workflow_page",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/workflow_page.git"
      },
      %{
        addable: false,
        description: "Captures anything that is emitted from the callback - Elixir library repo",
        name: "wormhole",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/wormhole.git"
      },
      %{
        addable: false,
        description: nil,
        name: "z",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/z.git"
      },
      %{
        addable: false,
        description: "Job Processing System for Semaphore 2.0",
        name: "zebra",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/zebra.git"
      },
      %{
        addable: false,
        description: nil,
        name: "agent",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/agent.git"
      },
      %{
        addable: false,
        description: "Semaphore 2.0 Public API",
        name: "api",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/api.git"
      },
      %{
        addable: false,
        description: "Semaphore 2.0 Command Line Interface",
        name: "cli",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/cli.git"
      },
      %{
        addable: false,
        description: "Semaphore 2.0 documentation.",
        name: "docs",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/docs.git"
      },
      %{
        addable: false,
        description: "Homebrew Tap for Semaphore 2.0 Command Line Interface",
        name: "homebrew-tap",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/homebrew-tap.git"
      },
      %{
        addable: false,
        description: "Command line tools available in Semaphore 2.0.",
        name: "toolbox",
        owner_avatar: "https://avatars3.githubusercontent.com/u/0?v=4",
        owner_name: "octocat",
        url: "git://github.com/octocat/toolbox.git"
      }
    ]
  end

  # Branch Page

  def pipeline_triggerer(params \\ []) do
    [
      wf_triggered_by: WfTriggeredBy.value(:HOOK),
      wf_triggerer_id: "21212121-be8a-465a-b9cd-81970fb802c6",
      wf_triggerer_user_id: "6d2c1337-4c97-41d5-a39e-0213c3ba8091",
      wf_triggerer_provider_login: "provider_login",
      wf_triggerer_provider_uid: "provider_uid",
      wf_triggerer_provider_avatar: "",
      ppl_triggered_by: PplTriggeredBy.value(:WORKFLOW),
      ppl_triggerer_id: "2cb61a21-c759-4d50-a45a-1e1eaba8c1bf",
      ppl_triggerer_user_id: "6d2c1337-4c97-41d5-a39e-0213c3ba8091",
      workflow_rerun_of: ""
    ]
    |> Keyword.merge(params)
    |> Triggerer.new()
  end

  def pipeline_with_trigger(trigger_type \\ nil) do
    db = %{
      INITIAL_WORKFLOW: fn ->
        pipeline(
          triggerer: [
            wf_triggered_by: WfTriggeredBy.value(:HOOK),
            ppl_triggered_by: PplTriggeredBy.value(:WORKFLOW)
          ]
        )
      end,
      WORKFLOW_RERUN: fn ->
        pipeline(
          triggerer: [
            workflow_rerun_of: Ecto.UUID.generate()
          ]
        )
      end,
      API: fn ->
        pipeline(
          triggerer: [
            wf_triggered_by: WfTriggeredBy.value(:API)
          ]
        )
      end,
      SCHEDULED_RUN: fn ->
        pipeline(
          triggerer: [
            wf_triggered_by: WfTriggeredBy.value(:SCHEDULE)
          ]
        )
      end,
      SCHEDULED_RUN_WITH_PROMOTION: fn ->
        pipeline(
          triggerer: [
            wf_triggered_by: WfTriggeredBy.value(:SCHEDULE),
            ppl_triggered_by: PplTriggeredBy.value(:PROMOTION)
          ]
        )
      end,
      SCHEDULED_MANUAL_RUN: fn ->
        pipeline(
          triggerer: [
            wf_triggered_by: WfTriggeredBy.value(:MANUAL_RUN)
          ]
        )
      end,
      PIPELINE_PARTIAL_RERUN: fn ->
        pipeline(
          triggerer: [
            ppl_triggered_by: PplTriggeredBy.value(:PARTIAL_RE_RUN)
          ]
        )
      end,
      MANUAL_PROMOTION: fn ->
        pipeline(
          triggerer: [
            ppl_triggered_by: PplTriggeredBy.value(:PROMOTION)
          ]
        )
      end,
      AUTO_PROMOTION: fn ->
        pipeline(
          triggerer: [
            ppl_triggered_by: PplTriggeredBy.value(:AUTO_PROMOTION)
          ]
        )
      end
    }

    db[trigger_type].()
  end
end
