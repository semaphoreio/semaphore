defmodule Projecthub.Models.Project.StateMachine do
  @doc """
  This module represents the state of a project in the system.

  Full diagram of the project's state machine:

                                          ┌───────────-┐     ┌───────────┐
   project created, skip_onboarding=false │initializing├─-───► onboarding┼─────--────┐
                                          └──────┬─────┘     └───────────┘           │
                                                 │                                   │
                                                 │       ┌───────────────┐        ┌──▼──┐
                                                 └───────►error          │        │ready│
                                                 |       |(unrecoverable)│        └──▲──┘
                                                 │       └───────────────┘           │
                                          ┌──────┴──────────┐                        │
   project created, skip_onboarding=true  │initializing_skip├────────────────────────┘
                                          └─────────────────┘

  Decomposed diagram, new_project_onboarding=true, skip_onboarding=false
  ┌────────────┐    ┌──────────┐   ┌─────┐
  │initializing├───►│onboarding├──►│ready│
  └───────┬────┘    └──────────┘   └─────┘
         │
         │
         │   ┌─────────────────────┐
         └──►│errror(unrecoverable)│
             └─────────────────────┘

  When all the dependencies are created via the Workers.ProjectInit worker, the
  state of the project is transitioned from "initializing" to "onboarding".

  Decomposed diagram, new_project_onboarding=false or skip_onboarding=true
  ┌─────────────────┐      ┌─────┐
  │initializing_skip├─────►│ready│
  └──────────┬──────┘      └─────┘
            │
            │
            │    ┌─────────────────────┐
            └───►│errror(unrecoverable)│
                 └─────────────────────┘

  When all the dependencies are created via the Workers.ProjectInit worker, the
  state of the project is transitioned from "initializing" to "ready".

  In other words, "initializing_skip" is a special case of "initializing" where
  the initialization process behaves like `new_project_onboarding: false`
  """

  def initializing, do: "initializing"
  def initializing_skip, do: "initializing_skip"
  def ready, do: "ready"
  def error, do: "error"
  def onboarding, do: "onboarding"

  def initial, do: initializing()
  def skip_onboarding, do: initializing_skip()
  def states, do: [initializing(), initializing_skip(), ready(), error(), onboarding()]

  def next(project) do
    initializing = initializing()
    initializing_skip = initializing_skip()
    onboarding = onboarding()

    case project.state do
      ^initializing -> onboarding()
      ^initializing_skip -> ready()
      ^onboarding -> ready()
      true -> project.state
    end
  end

  def transition(project, new_state) do
    if valid_transition?(project.state, new_state) do
      Projecthub.Models.Project.update_record(project, %{state: new_state})
    else
      {:error, :invalid_transition, project.state, new_state}
    end
  end

  def valid_transition?("initializing", "onboarding"), do: true
  def valid_transition?("initializing", "error"), do: true
  def valid_transition?("onboarding", "ready"), do: true

  def valid_transition?("initializing_skip", "ready"), do: true
  def valid_transition?("initializing_skip", "error"), do: true

  def valid_transition?(_, _, _), do: false
end
