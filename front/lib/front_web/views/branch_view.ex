defmodule FrontWeb.BranchView do
  use FrontWeb, :view

  def page_title(_conn, assigns) do
    "Branch: #{assigns.project.name}/#{assigns.branch.name} - Semaphore"
  end

  def base_domain do
    Application.get_env(:front, :domain)
  end

  def find_hook(hooks, workflow) do
    hooks |> Enum.find(fn hook -> hook.id == workflow.hook_id end)
  end

  def find_user(users, hook) do
    users |> Enum.find(fn user -> user.id == hook.user_id end)
  end

  def find_pipeline(pipelines, workflow) do
    pipelines |> Enum.find(fn pipeline -> pipeline.id == workflow.root_pipeline_id end)
  end
end
