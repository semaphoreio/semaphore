defmodule Support.Browser.WorkflowPage do
  use Wallaby.DSL

  alias Support.Stubs
  use Wallaby.DSL

  def create_workflow do
    Stubs.PermissionPatrol.allow_everything()

    user = Stubs.User.create_default()
    org = Stubs.Organization.create_default()
    project = Stubs.Project.create(org, user)
    branch = Stubs.Branch.create(project)
    Support.Stubs.PermissionPatrol.allow_everything(org.id, user.id)

    hook = Stubs.Hook.create(branch)
    workflow = Stubs.Workflow.create(hook, user)

    pipeline =
      Stubs.Pipeline.create_initial(workflow, name: "Build & Test", organization_id: org.id)

    blocks =
      Stubs.Pipeline.add_blocks(pipeline, [
        %{name: "Block 1"},
        %{name: "Block 2", dependencies: ["Block 1"]},
        %{name: "Block 3", dependencies: ["Block 1"]}
      ])

    switch = Stubs.Pipeline.add_switch(pipeline)

    params = [
      %{
        name: "SERVER_IP",
        description: "Where to deploy?",
        default_value: "1.2.3.4",
        required: true
      },
      %{
        name: "STRATEGY",
        description: "Which deployment strategy should be used?",
        default_value: "fast",
        options: [
          "fast",
          "slow"
        ],
        required: false
      }
    ]

    Stubs.Switch.add_target(switch, name: "Production", parameter_env_vars: params)

    params2 = [
      %{
        name: "REVIEWER",
        description: "Who should review this?",
        required: true
      }
    ]

    Stubs.Switch.add_target(switch, name: "QA", parameter_env_vars: params2)

    Stubs.Switch.add_target(switch, name: "Staging")

    %{
      org: org,
      project: project,
      branch: branch,
      hook: hook,
      workflow: workflow,
      switch: switch,
      pipeline: pipeline,
      blocks: blocks
    }
  end

  def current_favicon(page) do
    page
    |> attr(Query.css(".js-site-favicon[rel='icon']", visible: false), "href")
    |> strip_asset_host
  end

  def current_alternative_favicon(page) do
    page
    |> attr(Query.css(".js-site-favicon[rel='alternate icon']", visible: false), "href")
    |> strip_asset_host
  end

  defp strip_asset_host(href) do
    [_, relative_path] = String.split(href, "/projects/assets", parts: 2)
    relative_path
  end

  def stop_polling(page) do
    page
    |> execute_script("Pollman.stop()")
    |> execute_script("FaviconUpdater.stop()")
  end
end
