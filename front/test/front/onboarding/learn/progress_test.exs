defmodule Front.Onboarding.Learn.ProgressTest do
  use ExUnit.Case
  doctest Front.Onboarding.Learn.Progress
  alias Front.Onboarding.Learn.Progress
  alias Front.Onboarding.Learn

  setup do
    Support.Stubs.Scouter.clear()
    :ok
  end

  describe "loading onboarding progress" do
    test "works when there are no sections present" do
      assert %Progress{
               steps: [
                 %{completed: false, subtitle: "Get started", title: "Beginner"},
                 %{completed: false, subtitle: "Learn basics", title: "Explorer"},
                 %{completed: false, subtitle: "Build workflows", title: "Engineer"},
                 %{completed: false, subtitle: "Master delivery", title: "Professional"},
                 %{completed: false, subtitle: "Scale up", title: "Strategist"}
               ],
               is_skipped: false,
               is_finished: false,
               is_completed: false
             } = Progress.load([], "org-id", "user-id")
    end

    test "uses event flags to determine state" do
      Support.Stubs.Scouter.add_event("onboarding.skipped", %{
        organization_id: "org-id",
        user_id: "user-id"
      })

      Support.Stubs.Scouter.add_event("onboarding.finished", %{
        organization_id: "org-id",
        user_id: "user-id"
      })

      assert %Progress{
               steps: _,
               is_skipped: true,
               is_finished: true,
               is_completed: _
             } = Progress.load([], "org-id", "user-id")
    end

    test "when sections are passed, calculates progress" do
      assertions = [
        {[], 0},
        {[false], 0},
        {[true], 5},
        {[true, true, true, true, true], 5},
        {[false, false, false, false, false], 0},
        {[true, true, false], 4},
        {[true, false], 3},
        {[true, true, true], 5},
        {[true, false], 3}
      ]

      for {sections_completed, level_reached} <- assertions do
        sections = sections_completed |> Enum.map(&Learn.Section.parse(%{"completed" => &1}))

        progress = Progress.load(sections, "org-id", "user-id")

        assert Enum.count(progress.steps, & &1.completed) == level_reached
      end
    end
  end
end
