defmodule Front.ProjectSettings.DeletionValidatorTest do
  use ExUnit.Case

  alias Front.ProjectSettings.DeletionValidator, as: Subject

  describe ".run" do
    test "when reason is not provided and wrong name has been inputed, it communicate both errors" do
      project = %Front.Models.Project{
        name: "real-name",
        created_at: Timex.from_unix(1_522_754_259)
      }

      params = %{delete_confirmation: "test"}

      assert Subject.run(project, params) ==
               %{
                 changes: %{delete_confirmation: "test", feedback: "N/A"},
                 errors: [
                   reason: "Please select reason.",
                   delete_confirmation: "Name does not match."
                 ],
                 valid?: false
               }
    end

    test "when reason and name are provided and project is 5 days old, feedback is included in errors" do
      project = %Front.Models.Project{
        name: "correct-name",
        created_at: Timex.shift(Timex.now(), days: -5)
      }

      params = %{
        delete_confirmation: "correct-name",
        reason: "something"
      }

      assert Subject.run(project, params) ==
               %{
                 errors: [feedback: "Would you mind sharing how can we improve Semaphore?"],
                 valid?: false,
                 changes: %{
                   feedback: "N/A",
                   reason: "something",
                   delete_confirmation: "correct-name"
                 }
               }
    end

    test "when reason and name are provided and project is 10 days old, changes are valid" do
      project = %Front.Models.Project{
        name: "correct-name",
        created_at: Timex.shift(Timex.now(), days: -10)
      }

      params = %{
        delete_confirmation: "correct-name",
        reason: "something"
      }

      assert Subject.run(project, params) ==
               %{
                 errors: [],
                 valid?: true,
                 changes: %{
                   feedback: "N/A",
                   reason: "something",
                   delete_confirmation: "correct-name"
                 }
               }
    end

    test "when reason is provided and name is wrong, it correctly communicates changes and error" do
      project = %Front.Models.Project{
        name: "real-name",
        created_at: Timex.shift(Timex.now(), days: -10)
      }

      params = %{
        delete_confirmation: "test",
        reason: "something"
      }

      assert Subject.run(project, params) ==
               %{
                 changes: %{delete_confirmation: "test", feedback: "N/A", reason: "something"},
                 errors: [delete_confirmation: "Name does not match."],
                 valid?: false
               }
    end
  end
end
