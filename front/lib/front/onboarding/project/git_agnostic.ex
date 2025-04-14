defmodule Front.Onboarding.Project.GitAgnostic do
  alias Front.Onboarding.Project.GitAgnostic

  @type state :: :init | :git_setup | :webhook_verified

  @type t :: %GitAgnostic{
          project_id: String.t(),
          repository_id: String.t(),
          project_name: String.t(),
          repository_url: String.t()
        }

  defstruct [
    :project_id,
    :repository_id,
    :project_name,
    :repository_url
  ]

  def init() do
    %GitAgnostic{
      project_id: nil,
      repository_id: nil,
      project_name: nil,
      repository_url: nil
    }
  end

  @spec state(t()) :: state()

  def state(_project) do
    :init
  end

  @spec transition(t()) :: state()
  def transition(project) do
    project
    |> state()
    |> case do
      :init ->
        nil

      :git_setup ->
        nil

      :webhook_setup ->
        nil
    end
  end
end
