defmodule Front.Onboarding.Learn.Progress do
  alias Front.Onboarding.Learn

  @type step :: %{
          completed: boolean(),
          title: String.t(),
          subtitle: String.t()
        }

  @type t :: %Learn.Progress{
          steps: [step()],
          is_completed: boolean(),
          is_skipped: boolean(),
          is_finished: boolean()
        }

  defstruct [
    :steps,
    :is_completed,
    :is_skipped,
    :is_finished
  ]

  @spec load([Learn.Section.t()], String.t(), String.t()) :: t()
  def load(sections, organization_id, user_id) do
    steps = calculate_steps(sections)
    with_skipped_event? = Learn.has_event?("onboarding.skipped", organization_id, user_id)
    with_finished_event? = Learn.has_event?("onboarding.finished", organization_id, user_id)
    is_completed? = Enum.all?(steps, & &1.completed)

    %Learn.Progress{
      steps: steps,
      is_skipped: with_skipped_event?,
      is_finished: with_finished_event?,
      is_completed: is_completed?
    }
  end

  @spec calculate_steps([Learn.Section.t()]) :: [step()]
  defp calculate_steps(sections) do
    section_count = length(sections)
    level_count = length(levels())

    section_weight =
      if section_count > 0,
        do: Decimal.div(level_count, section_count),
        else: 1

    current_level = Decimal.mult(section_weight, Enum.count(sections, & &1.completed))

    levels()
    |> Enum.with_index()
    |> Enum.map(fn {level, idx} ->
      completed =
        if Decimal.compare(current_level, Decimal.new(idx)) == :gt, do: true, else: false

      %{level | completed: completed}
    end)
  end

  @spec levels() :: [step()]
  defp levels do
    [
      %{
        title: "Beginner",
        subtitle: "Get started",
        completed: false
      },
      %{
        title: "Explorer",
        subtitle: "Learn basics",
        completed: false
      },
      %{
        title: "Engineer",
        subtitle: "Build workflows",
        completed: false
      },
      %{
        title: "Professional",
        subtitle: "Master delivery",
        completed: false
      },
      %{
        title: "Strategist",
        subtitle: "Scale up",
        completed: false
      }
    ]
  end
end
