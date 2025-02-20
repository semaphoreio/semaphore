defmodule JobPage.EventsTest do
  use FrontWeb.ConnCase

  describe "fetch_events" do
    test "returns whole job log in test" do
      {:ok, events} = JobPage.Events.fetch_events("019583d5-0f5d-485a-88e3-82bc7f97df3c", 0)

      assert events.next == "null"
      assert is_list(events.events)
    end
  end

  describe "raw_logs" do
    test "returns whole job log in test" do
      log = JobPage.Events.raw_logs("43dfb721-42e3-48d5-871a-d0c2231435d9", 0, 1000)

      assert log =~
               "\e[31mDECODING LOG FAILED[at position: 79]: {\"event\":\"cmd_output\",\"timestamp\":1720124473,\"output\":\"/home/semaphore/.toolb{\"event\":\"cmd_output\",\"timestamp\":1720124528,\"output\":\"  \\u001b[36mINFO\\u001b[0m[4191] Collected diags bundle:\\r\\n  ==== Begin collecting diagnostics. ====\\r\\n  Collec\"}\e[0m"
    end
  end
end
