defmodule Mix.Tasks.Dev.Server do
  alias Support.Stubs
  require Logger

  def run(_) do
    Mix.Tasks.Phx.Server.run([])
    Support.Stubs.init()

    user = Stubs.User.create_default()

    [first_user | _user_ids] =
      [
        %{name: "Darko Fabijan", username: "darkofabijan", uuid: "20469"},
        %{name: "Aleksandar Mitrovic", username: "AleksandarCole", uuid: "61409859"},
        %{name: "Damjan Becirovic", username: "DamjanBecirovic", uuid: "18249084"},
        %{name: "Ervin Barta", username: "ervinb", uuid: "2212814"}
      ]
      |> Enum.map(fn data ->
        Stubs.User.create(
          name: data.name,
          username: data.username,
          github_login: data.username,
          avatar_url: "https://avatars.githubusercontent.com/u/#{data.uuid}?v=4"
        )
      end)

    org = Stubs.Organization.create_default(owner_id: first_user.id)
    Stubs.RBAC.add_owner(org.id, first_user.id)
    Stubs.RBAC.add_member(org.id, user.id)

    for i <- 2..4 do
      org = Stubs.Organization.create(name: "rt#{i}", org_username: "rt#{i}", owner_id: user.id)
      Stubs.RBAC.add_member(org.id, user.id)
    end

    Stubs.Feature.set_org_defaults(org.id)
    Stubs.Billing.set_org_defaults(org.id)

    # Create agents
    if System.get_env("SEED_SELF_HOSTED_AGENTS") == "true" do
      Stubs.SelfHostedAgent.create(org.id, "s1-cluster-agents")
      Stubs.SelfHostedAgent.add_agent(org.id, "s1-cluster-agents", "nasof8bb0as8b093")
      Stubs.SelfHostedAgent.add_agent(org.id, "s1-cluster-agents", "0293b0v9a0sn9sfs")
      Stubs.SelfHostedAgent.add_agent(org.id, "s1-cluster-agents", "asn0c9n2v309f393")
    end

    System.get_env("SEED_PROJECTS")
    |> case do
      nil ->
        [
          :initializing_failed,
          :zebra,
          :guard,
          :errored,
          :test_results,
          :test_results_debug,
          :after_pipeline,
          :bitbucket,
          :generic_git
        ]

      projects ->
        String.split(projects, ",")
        |> Enum.map(&String.to_atom/1)
    end
    |> Enum.each(fn project_type ->
      project = create_project(project_type, org, user)
      Stubs.RBAC.add_member(org.id, user.id, project.id)
      Stubs.Project.set_project_state(project, :READY)
    end)

    {user, org}
  end

  defp create_project(:simple_project, org, user) do
    project = Stubs.Project.create(org, user, name: "simple-project")
    branch = Stubs.Branch.create(project)
    hook = Stubs.Hook.create(branch)
    workflow = Stubs.Workflow.create(hook, user)

    pipeline =
      Stubs.Pipeline.create_initial(workflow, name: "Build & Test", organization_id: org.id)

    block = Stubs.Pipeline.add_block(pipeline, %{name: "Block 1"})
    Stubs.Task.create(block)

    project
  end

  defp create_project(:multi_block_project, org, user) do
    project = Stubs.Project.create(org, user, name: "multi-block-project")
    branch = Stubs.Branch.create(project)
    hook = Stubs.Hook.create(branch)
    workflow = Stubs.Workflow.create(hook, user)

    pipeline =
      Stubs.Pipeline.create_initial(workflow, name: "Build & Test", organization_id: org.id)

    block1 = Stubs.Pipeline.add_block(pipeline, %{name: "Block 1"})
    block2 = Stubs.Pipeline.add_block(pipeline, %{name: "Block 2", dependencies: ["Block 1"]})
    block3 = Stubs.Pipeline.add_block(pipeline, %{name: "Block 3", dependencies: ["Block 1"]})

    Stubs.Task.create(block1)
    Stubs.Task.create(block2)
    Stubs.Task.create(block3)

    project
  end

  defp create_project(:scheduled_project, org, user) do
    project = Stubs.Project.create(org, user, name: "scheduled-project")
    branch = Stubs.Branch.create(project)
    hook = Stubs.Hook.create(branch)
    workflow = Stubs.Workflow.create(hook, user)

    pipeline =
      Stubs.Pipeline.create_initial(workflow, name: "Build & Test", organization_id: org.id)

    block = Stubs.Pipeline.add_block(pipeline, %{name: "Block 1"})
    Stubs.Task.create(block)

    # Add schedulers
    periodic = Stubs.Scheduler.create(project, user, branch: branch.name)
    Stubs.Scheduler.create_trigger(periodic, workflow.api_model, user, branch: branch.name)

    params = [
      name: "Paused Scheduler",
      branch: branch.name,
      paused: true,
      pause_toggled_by: user.id
    ]

    periodic = Stubs.Scheduler.create(project, user, params)
    Stubs.Scheduler.create_trigger(periodic, workflow.api_model, user, branch: branch.name)

    project
  end

  defp create_project(:initializing_failed, org, user) do
    alias InternalApi.Projecthub.Project.Status.State

    Stubs.Project.create(org, user,
      name: "initializing_failed",
      integration_type: "github_app",
      run_on: ["branches", "tags"],
      whitelist_branches: ["master"],
      state: State.value(:ERROR),
      state_reason: "Error"
    )
  end

  defp create_project(:bitbucket, org, user) do
    project =
      Stubs.Project.create(org, user,
        name: "bitbucket",
        integration_type: "bitbucket",
        run_on: ["branches", "tags"],
        whitelist_branches: ["master"]
      )

    branch = Stubs.Branch.create(project)
    hook = Stubs.Hook.create(branch)
    workflow = Stubs.Workflow.create(hook, user)

    pipeline =
      Stubs.Pipeline.create_initial(workflow, name: "Build & Test", organization_id: org.id)

    block1 = Stubs.Pipeline.add_block(pipeline, %{name: "Block 1"})
    block2 = Stubs.Pipeline.add_block(pipeline, %{name: "Block 2", dependencies: ["Block 1"]})
    block3 = Stubs.Pipeline.add_block(pipeline, %{name: "Block 3", dependencies: ["Block 1"]})

    Stubs.Task.create(block1)
    Stubs.Task.create(block2)
    Stubs.Task.create(block3)

    periodic = Stubs.Scheduler.create(project, user, branch: branch.name)
    Stubs.Scheduler.create_trigger(periodic, workflow.api_model, user, branch: branch.name)

    params = [
      name: "Paused Scheduler",
      branch: branch.name,
      paused: true,
      pause_toggled_by: user.id
    ]

    periodic = Stubs.Scheduler.create(project, user, params)
    Stubs.Scheduler.create_trigger(periodic, workflow.api_model, user, branch: branch.name)

    params = [name: "Blocked Scheduler", branch: branch.name, suspended: true]
    Stubs.Scheduler.create(project, user, params)

    params = [name: "Failing Scheduler", branch: branch.name]
    periodic = Stubs.Scheduler.create(project, user, params)
    params = [branch: branch.name, scheduling_status: "failed"]
    Stubs.Scheduler.create_trigger(periodic, workflow.api_model, user, params)

    Stubs.Deployments.create(project, user, "Production")

    project
  end

  defp create_project(:generic_git, org, user) do
    project =
      Stubs.Project.create(org, user,
        name: "generic-git",
        integration_type: "git",
        run_on: ["branches", "tags"],
        whitelist_branches: ["master"]
      )

    branch = Stubs.Branch.create(project)
    hook = Stubs.Hook.create(branch)
    workflow = Stubs.Workflow.create(hook, user)

    pipeline =
      Stubs.Pipeline.create_initial(workflow, name: "Build & Test", organization_id: org.id)

    block1 = Stubs.Pipeline.add_block(pipeline, %{name: "Block 1"})
    block2 = Stubs.Pipeline.add_block(pipeline, %{name: "Block 2", dependencies: ["Block 1"]})
    block3 = Stubs.Pipeline.add_block(pipeline, %{name: "Block 3", dependencies: ["Block 1"]})

    Stubs.Task.create(block1)
    Stubs.Task.create(block2)
    Stubs.Task.create(block3)

    periodic = Stubs.Scheduler.create(project, user, branch: branch.name)
    Stubs.Scheduler.create_trigger(periodic, workflow.api_model, user, branch: branch.name)

    params = [
      name: "Paused Scheduler",
      branch: branch.name,
      paused: true,
      pause_toggled_by: user.id
    ]

    periodic = Stubs.Scheduler.create(project, user, params)
    Stubs.Scheduler.create_trigger(periodic, workflow.api_model, user, branch: branch.name)

    params = [name: "Blocked Scheduler", branch: branch.name, suspended: true]
    Stubs.Scheduler.create(project, user, params)

    params = [name: "Failing Scheduler", branch: branch.name]
    periodic = Stubs.Scheduler.create(project, user, params)
    params = [branch: branch.name, scheduling_status: "failed"]
    Stubs.Scheduler.create_trigger(periodic, workflow.api_model, user, params)

    Stubs.Deployments.create(project, user, "Production")

    project
  end

  defp create_project(:guard, org, user) do
    project =
      Stubs.Project.create(org, user,
        name: "guard",
        integration_type: "github_app",
        run_on: ["branches", "tags"],
        whitelist_branches: ["master"]
      )

    branch = Stubs.Branch.create(project)
    hook = Stubs.Hook.create(branch)
    workflow = Stubs.Workflow.create(hook, user)

    pipeline =
      Stubs.Pipeline.create_initial(workflow, name: "Build & Test", organization_id: org.id)

    block1 = Stubs.Pipeline.add_block(pipeline, %{name: "Block 1"})
    block2 = Stubs.Pipeline.add_block(pipeline, %{name: "Block 2", dependencies: ["Block 1"]})
    block3 = Stubs.Pipeline.add_block(pipeline, %{name: "Block 3", dependencies: ["Block 1"]})

    Stubs.Task.create(block1)
    Stubs.Task.create(block2)
    Stubs.Task.create(block3)

    periodic = Stubs.Scheduler.create(project, user, branch: branch.name)
    Stubs.Scheduler.create_trigger(periodic, workflow.api_model, user, branch: branch.name)

    params = [
      name: "Paused Scheduler",
      branch: branch.name,
      paused: true,
      pause_toggled_by: user.id
    ]

    periodic = Stubs.Scheduler.create(project, user, params)
    Stubs.Scheduler.create_trigger(periodic, workflow.api_model, user, branch: branch.name)

    params = [name: "Blocked Scheduler", branch: branch.name, suspended: true]
    Stubs.Scheduler.create(project, user, params)

    params = [
      name: "Paused Scheduler",
      branch: branch.name,
      paused: true,
      pause_toggled_by: user.id
    ]

    periodic = Stubs.Scheduler.create(project, user, params)
    Stubs.Scheduler.create_trigger(periodic, workflow.api_model, user, branch: branch.name)

    params = [name: "Blocked Scheduler", branch: branch.name, suspended: true]
    Stubs.Scheduler.create(project, user, params)

    params = [name: "Failing Scheduler", branch: branch.name]
    periodic = Stubs.Scheduler.create(project, user, params)
    params = [branch: branch.name, scheduling_status: "failed"]
    Stubs.Scheduler.create_trigger(periodic, workflow.api_model, user, params)

    project
  end

  defp create_project(:zebra, org, user) do
    project = Stubs.Project.create(org, user, name: "zebra")
    branch = Stubs.Branch.create(project)
    Stubs.Branch.create(project, name: "development")
    Stubs.Branch.create(project, name: "staging")

    hook = Stubs.Hook.create(branch)
    workflow = Stubs.Workflow.create(hook, user)

    pipeline =
      Stubs.Pipeline.create_initial(workflow, name: "Build & Test", organization_id: org.id)

    block1 = Stubs.Pipeline.add_block(pipeline, %{name: "Block 1"})
    block2 = Stubs.Pipeline.add_block(pipeline, %{name: "Block 2", dependencies: ["Block 1"]})
    block3 = Stubs.Pipeline.add_block(pipeline, %{name: "Block 3", dependencies: ["Block 1"]})

    switch = Stubs.Pipeline.add_switch(pipeline)

    Stubs.Switch.add_target(switch,
      name: "Production",
      parameter_env_vars: [
        %{
          name: "SERVER_IP",
          description: "Where to deploy?",
          default_value: "1.2.3.4",
          required: true
        },
        %{
          name: "FOO",
          description: "required without default",
          required: true
        },
        %{
          name: "FOO2",
          description: "required without default but with options",
          options: [
            "yes",
            "no"
          ],
          required: true
        },
        %{
          name: "FOO3",
          description: "required with empty default but with options",
          default_value: "",
          options: [
            "yes",
            "no"
          ],
          required: true
        },
        %{
          name: "BIG",
          description: "required with a long list of options",
          default_value: "yes",
          options: [
            "yes",
            "no",
            "maybe",
            "perhaps",
            "probably",
            "unlikely",
            "impossible",
            "definitely",
            "sometimes",
            "always",
            "never"
          ],
          required: true
        },
        %{
          name: "FAST",
          description: "Use fast deployment strategy.",
          default_value: "yes",
          options: [
            "yes",
            "no"
          ],
          required: false
        },
        %{
          name: "SLOW",
          description: "Use slow deployment strategy.",
          options: [
            "yes",
            "no"
          ],
          required: false
        }
      ]
    )

    target = Stubs.Switch.add_target(switch, name: "Staging")

    Stubs.Switch.add_trigger_event(target)

    Stubs.Task.create(block1)
    Stubs.Task.create(block2)
    Stubs.Task.create(block3)

    project
  end

  defp create_project(:test_results, org, user) do
    project = Stubs.Project.create(org, user, name: "test_results")
    project = Stubs.Project.switch_project_visibility(project, "public")
    branch = Stubs.Branch.create(project)
    hook = Stubs.Hook.create(branch)
    workflow = Stubs.Workflow.create(hook, user)
    workflow |> Stubs.Workflow.with_summary()

    workflow
    |> Stubs.Workflow.add_artifact(path: "some_file_one")

    generate_report_jobs = [%{name: "Generate reports"}]

    {prod, _} = Stubs.Deployments.create(project, user, "Production")
    {stg, _} = Stubs.Deployments.create(project, user, "Staging")
    {dev, _} = Stubs.Deployments.create(project, user, "Development")

    build_pipeline =
      Stubs.Pipeline.create_initial(workflow,
        name: "Build",
        commit_message: hook.api_model.commit_message,
        organization_id: org.id
      )
      |> then(&Stubs.Pipeline.change_state(&1.id, :passed))
      |> then(&Stubs.Pipeline.add_after_task(&1.id, %{jobs: generate_report_jobs}))

    test_pipeline =
      Stubs.Pipeline.create(workflow,
        name: "Test",
        promotion_of: build_pipeline.id,
        commit_message: hook.api_model.commit_message
      )
      |> then(&Stubs.Pipeline.change_state(&1.id, :failed))
      |> tap(&Stubs.Pipeline.with_summary/1)
      |> then(&Stubs.Pipeline.add_after_task(&1.id, %{jobs: generate_report_jobs}))

    deploy_pipeline =
      Stubs.Pipeline.create(workflow,
        name: "Deploy",
        promotion_of: test_pipeline.id,
        commit_message: hook.api_model.commit_message
      )
      |> then(&Stubs.Pipeline.change_state(&1.id, :passed))
      |> then(&Stubs.Pipeline.add_after_task(&1.id, %{jobs: generate_report_jobs}))

    heartbeat_pipeline =
      Stubs.Pipeline.create(workflow,
        name: "Livecheck",
        promotion_of: deploy_pipeline.id,
        commit_message: hook.api_model.commit_message
      )
      |> then(&Stubs.Pipeline.change_state(&1.id, :pending))
      |> then(&Stubs.Pipeline.add_after_task(&1.id, %{jobs: generate_report_jobs}))

    workflow
    |> Stubs.Workflow.add_artifact(
      path: "test-results/#{build_pipeline.id}.json",
      url: "#{Application.get_env(:front, :artifact_host)}/test-results/pipeline/build.json"
    )

    workflow
    |> Stubs.Workflow.add_artifact(
      path: "test-results/#{test_pipeline.id}.json",
      url: "#{Application.get_env(:front, :artifact_host)}/test-results/pipeline/test.json"
    )

    workflow
    |> Stubs.Workflow.add_artifact(
      path: "test-results/#{deploy_pipeline.id}.json",
      url:
        "#{Application.get_env(:front, :artifact_host)}/test-results/failed/invalid_junit_json/junit.json"
    )

    %{api_model: %{jobs: jobs}} =
      Stubs.Pipeline.add_block(build_pipeline, %{
        name: "Build project",
        job_names: ["Build #1", "Build #2", "Build without test cases"]
      })
      |> Stubs.Task.create()
      |> Stubs.Task.change_state(:finished)

    jobs
    |> Enum.with_index(1)
    |> Enum.each(fn {job, index} ->
      job
      |> Stubs.Task.add_job_artifact(
        path: "test-results/junit.json",
        url:
          "#{Application.get_env(:front, :artifact_host)}/test-results/job/build/build_#{index}.json"
      )
    end)

    %{api_model: %{jobs: jobs}} =
      Stubs.Pipeline.add_block(test_pipeline, %{
        name: "Test project",
        job_names: ["Test #1", "Test #2", "Test #3", "Test #4 - compressed results"]
      })
      |> Stubs.Task.create()
      |> Stubs.Task.change_state(:finished)

    jobs
    |> Enum.with_index(1)
    |> Enum.each(fn {job, index} ->
      job
      |> Stubs.Task.add_job_artifact(
        path: "test-results/junit.json",
        url:
          "#{Application.get_env(:front, :artifact_host)}/test-results/job/test/test_#{index}.json"
      )

      Stubs.Velocity.create_job_summary(pipeline_id: test_pipeline.id, job_id: job.id)
    end)

    %{api_model: %{jobs: jobs}} =
      Stubs.Pipeline.add_block(deploy_pipeline, %{
        name: "Deploy project",
        job_names: ["Deploy #1"]
      })
      |> Stubs.Task.create()
      |> Stubs.Task.change_state(:finished)

    jobs
    |> Enum.with_index(1)
    |> Enum.each(fn {job, index} ->
      job
      |> Stubs.Task.add_job_artifact(
        path: "test-results/junit.json",
        url:
          "#{Application.get_env(:front, :artifact_host)}/test-results/job/deploy/deploy_#{index}.json"
      )
    end)

    Stubs.Pipeline.add_block(heartbeat_pipeline, %{
      name: "Heartbeat",
      job_names: ["Heartbeat check #1"]
    })
    |> Stubs.Task.create()
    |> Stubs.Task.change_state(:finished)

    build_ppl_switch = Stubs.Pipeline.add_switch(build_pipeline)

    build_ppl_switch
    |> Stubs.Switch.add_target(name: "Tests")
    |> Stubs.Switch.add_trigger_event(
      triggered_by: build_pipeline.id,
      scheduled_pipeline_id: test_pipeline.id,
      auto_triggered: true,
      processed: true,
      processing_result: InternalApi.Gofer.TriggerEvent.ProcessingResult.value(:PASSED)
    )

    Stubs.Deployments.put_last_deployment(dev, user, build_ppl_switch, %{
      pipeline_id: test_pipeline.id,
      state: :STARTED
    })

    test_ppl_switch = Stubs.Pipeline.add_switch(test_pipeline)

    test_ppl_switch
    |> Stubs.Switch.add_target(
      name: "Deploy to staging",
      dt_description: %{
        target_id: stg.id,
        target_name: stg.name,
        access: %{
          allowed: true,
          reason: :NO_REASON,
          message: "You can deploy to %{deployment_target}"
        }
      }
    )

    test_ppl_switch
    |> Stubs.Switch.add_target(
      name: "Deploy to prod",
      dt_description: %{
        target_id: prod.id,
        target_name: prod.name,
        access: %{
          allowed: false,
          reason: :BANNED_SUBJECT,
          message: "You cannot deploy to %{deployment_target}"
        }
      }
    )
    |> Stubs.Switch.add_trigger_event(
      triggered_by: test_pipeline.id,
      scheduled_pipeline_id: deploy_pipeline.id,
      auto_triggered: true,
      processed: true,
      processing_result: InternalApi.Gofer.TriggerEvent.ProcessingResult.value(:PASSED)
    )

    Stubs.Deployments.put_last_deployment(prod, user, test_ppl_switch, %{
      pipeline_id: deploy_pipeline.id,
      state: :STARTED
    })

    prod
    |> Stubs.Deployments.add_deployment(user, test_ppl_switch, %{
      pipeline_id: deploy_pipeline.id,
      state: :STARTED
    })
    |> Stubs.Deployments.add_deployment(user, test_ppl_switch, %{
      pipeline_id: deploy_pipeline.id,
      state: :STARTED
    })
    |> Stubs.Deployments.add_deployment(user, test_ppl_switch, %{
      pipeline_id: deploy_pipeline.id,
      state: :STARTED
    })

    deploy_ppl_switch = Stubs.Pipeline.add_switch(deploy_pipeline)

    deploy_ppl_switch
    |> Stubs.Switch.add_target(name: "Heartbeat")
    |> Stubs.Switch.add_trigger_event(
      triggered_by: deploy_pipeline.id,
      scheduled_pipeline_id: heartbeat_pipeline.id,
      auto_triggered: true,
      processed: true,
      processing_result: InternalApi.Gofer.TriggerEvent.ProcessingResult.value(:PASSED)
    )

    Stubs.Deployments.put_last_deployment(stg, user, deploy_ppl_switch, %{
      pipeline_id: heartbeat_pipeline.id,
      state: :STARTED
    })

    stg
    |> Stubs.Deployments.add_deployment(user, deploy_ppl_switch, %{
      pipeline_id: heartbeat_pipeline.id,
      state: :STARTED
    })
    |> Stubs.Deployments.add_deployment(user, deploy_ppl_switch, %{
      pipeline_id: heartbeat_pipeline.id,
      state: :STARTED
    })

    project
  end

  defp create_project(:test_results_debug, org, user) do
    project = Stubs.Project.create(org, user, name: "test-results-debug-wf")
    branch = Stubs.Branch.create(project)
    hook = Stubs.Hook.create(branch)
    workflow = Stubs.Workflow.create(hook, user)

    summary = [
      total: 13_906,
      passed: 564,
      skipped: 13_342,
      error: 0,
      failed: 0,
      disabled: 0,
      # nanoseconds
      duration: 33_583_673_000_000
    ]

    debug_pipeline =
      Stubs.Pipeline.create_initial(workflow, name: "Debug", organization_id: org.id)
      |> then(&Stubs.Pipeline.change_state(&1.id, :passed))
      |> tap(&Stubs.Pipeline.with_summary(&1, summary: summary))

    workflow
    |> Stubs.Workflow.add_artifact(
      path: "test-results/#{debug_pipeline.id}.json",
      url: "#{Application.get_env(:front, :artifact_host)}/test-results/debug/junit.json"
    )

    %{api_model: %{jobs: jobs}} =
      Stubs.Pipeline.add_block(debug_pipeline, %{
        name: "Debug test reports",
        job_names: ["Job #1"]
      })
      |> Stubs.Task.create()
      |> Stubs.Task.change_state(:finished)

    jobs
    |> Enum.with_index(1)
    |> Enum.each(fn {job, _index} ->
      job
      |> Stubs.Task.add_job_artifact(
        path: "test-results/junit.json",
        url: "#{Application.get_env(:front, :artifact_host)}/test-results/debug/junit.json"
      )
    end)

    project
  end

  defp create_project(:errored, org, user) do
    project = Stubs.Project.create(org, user, name: "errored")
    branch = Stubs.Branch.create(project)

    hook = Stubs.Hook.create(branch)
    workflow = Stubs.Workflow.create(hook, user)

    pipeline =
      Stubs.Pipeline.create_initial(workflow, name: "Build & Test", organization_id: org.id)

    block1 = Stubs.Pipeline.add_block(pipeline, %{name: "Block 1"})
    block2 = Stubs.Pipeline.add_block(pipeline, %{name: "Block 2", dependencies: ["Block 1"]})
    block3 = Stubs.Pipeline.add_block(pipeline, %{name: "Block 3", dependencies: ["Block 1"]})

    switch = Stubs.Pipeline.add_switch(pipeline)
    Stubs.Switch.add_target(switch, name: "Production")
    Stubs.Switch.add_target(switch, name: "Staging")

    Stubs.Task.create(block1)
    Stubs.Task.create(block2)
    Stubs.Task.create(block3)

    err = """
      {
        "message": "Initialization step failed, see logs for more details.",
        "location":{
          "file": ".semaphore/semaphore.yml",
          "path": []
        },
        "type":"ErrorInitializationFailed"
      }
    """

    Support.Stubs.Pipeline.set_error(pipeline.id, err)

    project
  end

  defp create_project(:after_pipeline, org, user) do
    project = Stubs.Project.create(org, user, name: "After pipeline demo")
    branch = Stubs.Branch.create(project)

    hook = Stubs.Hook.create(branch)
    workflow = Stubs.Workflow.create(hook, user)

    initial_pipeline =
      Stubs.Pipeline.create_initial(workflow, name: "Initial", organization_id: org.id)
      |> then(&Stubs.Pipeline.change_state(&1.id, :passed))
      |> then(
        &Stubs.Pipeline.add_after_task(&1.id, %{
          jobs: [%{name: "Cleanup"}]
        })
      )

    pipeline_with_after_task =
      Stubs.Pipeline.create(workflow, name: "With after task", promotion_of: initial_pipeline.id)
      |> then(&Stubs.Pipeline.change_state(&1.id, :running))

    pipeline_with_after_task =
      pipeline_with_after_task
      |> then(
        &Stubs.Pipeline.add_after_task(&1.id, %{
          jobs: [%{name: "Cleanup"}]
        })
      )

    pipeline_with_after_task_running =
      Stubs.Pipeline.create(workflow,
        name: "With after task running",
        promotion_of: pipeline_with_after_task.id
      )
      |> then(&Stubs.Pipeline.change_state(&1.id, :passed))

    pipeline_with_after_task_running =
      pipeline_with_after_task_running
      |> then(
        &Stubs.Pipeline.add_after_task(&1.id, %{
          jobs: [%{name: "Clean DB"}, %{name: "Downscale"}, %{name: "Test reports"}],
          task_created: true
        })
      )

    Stubs.Pipeline.add_block(initial_pipeline, %{
      name: "Initial",
      job_names: ["Build #1", "Build #2"]
    })
    |> Stubs.Task.create()
    |> Stubs.Task.change_state(:finished)

    Stubs.Pipeline.add_block(pipeline_with_after_task, %{
      name: "With after task",
      job_names: ["Build #1", "Build #2"]
    })
    |> Stubs.Task.create()
    |> Stubs.Task.change_state(:running)

    Stubs.Pipeline.add_block(pipeline_with_after_task_running, %{
      name: "With after task running",
      job_names: ["Build #1", "Build #2"]
    })
    |> Stubs.Task.create()
    |> Stubs.Task.change_state(:finished)

    Stubs.Pipeline.add_switch(initial_pipeline)
    |> Stubs.Switch.add_target(name: "With after task")
    |> Stubs.Switch.add_trigger_event(
      triggered_by: initial_pipeline.id,
      scheduled_pipeline_id: pipeline_with_after_task.id,
      auto_triggered: true,
      processed: true,
      processing_result: InternalApi.Gofer.TriggerEvent.ProcessingResult.value(:PASSED)
    )

    Stubs.Pipeline.add_switch(pipeline_with_after_task)
    |> Stubs.Switch.add_target(name: "With after task running")
    |> Stubs.Switch.add_trigger_event(
      triggered_by: pipeline_with_after_task.id,
      scheduled_pipeline_id: pipeline_with_after_task_running.id,
      auto_triggered: true,
      processed: true,
      processing_result: InternalApi.Gofer.TriggerEvent.ProcessingResult.value(:PASSED)
    )

    project
  end
end
