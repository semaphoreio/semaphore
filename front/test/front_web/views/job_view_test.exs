defmodule FrontWeb.JobViewTest do
  use FrontWeb.ConnCase, async: true

  alias FrontWeb.JobView
  alias Front.Models.Job
  alias Front.Models.User

  describe "stopped_by_message/1" do
    test "returns empty string when job is not stopped" do
      job = %Job{state: "running", stopped_by: "user-123"}
      assigns = %{job: job, stopped_by_user: nil}

      assert JobView.stopped_by_message(assigns) == ""
    end

    test "returns generic message when job is stopped but stopped_by is nil" do
      job = %Job{state: "stopped", stopped_by: nil}
      assigns = %{job: job, stopped_by_user: nil}

      assert JobView.stopped_by_message(assigns) == "Job was stopped"
    end

    test "returns system message when job is stopped by system" do
      job = %Job{state: "stopped", stopped_by: "system:timeout"}
      assigns = %{job: job, stopped_by_user: nil}

      assert JobView.stopped_by_message(assigns) == "Job was stopped by the system"
    end

    test "returns user ID when job is stopped by user but user info is not available" do
      job = %Job{state: "stopped", stopped_by: "user-123"}
      assigns = %{job: job, stopped_by_user: nil}

      assert JobView.stopped_by_message(assigns) == "Job was stopped by user user-123"
    end

    test "returns user name when job is stopped by user and user info is available" do
      job = %Job{state: "stopped", stopped_by: "user-123"}
      user = %User{id: "user-123", name: "John Doe"}
      assigns = %{job: job, stopped_by_user: user}

      assert JobView.stopped_by_message(assigns) == "Job was stopped by John Doe"
    end
  end
end
