defmodule Front.Onboarding.Learn.SectionTest do
  use ExUnit.Case
  doctest Front.Onboarding.Learn.Section
  alias Front.Onboarding.Learn.Section

  describe "loading onboarding sections" do
    test "works when the state is empty" do
      sections = Section.load("org-id", "user-id")

      assert length(sections) == 5
    end
  end
end
