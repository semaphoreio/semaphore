defmodule Zebra.Apis.PublicJobApi.SerializerTest do
  use Zebra.DataCase

  alias Support.Factories
  alias Zebra.Apis.PublicJobApi.Serializer
  alias Semaphore.Jobs.V1alpha.Job

  test ".serialize" do
    {:ok, job} = Support.Factories.Job.create(:finished, %{result: "passed"})
    {:ok, job} = Support.Factories.Job.inject_request(job)

    serialized_job = Serializer.serialize(job)

    assert serialized_job.metadata.name == job.name
    assert serialized_job.metadata.id == job.id
    assert serialized_job.metadata.create_time == DateTime.to_unix(job.created_at)
    assert serialized_job.metadata.update_time == 0
    assert serialized_job.metadata.start_time == DateTime.to_unix(job.started_at)
    assert serialized_job.metadata.finish_time == DateTime.to_unix(job.finished_at)

    assert serialized_job.status.state == Job.Status.State.value(:FINISHED)
    assert serialized_job.status.result == Job.Status.Result.value(:PASSED)

    assert serialized_job.status.agent.ip == job.agent_ip_address
    assert hd(serialized_job.status.agent.ports).name == "ssh"
    assert hd(serialized_job.status.agent.ports).number == job.port

    assert serialized_job.spec.env_vars == [
             Semaphore.Jobs.V1alpha.Job.Spec.EnvVar.new(
               name: "SEMAPHORE_WORKFLOW_ID",
               value: Factories.Job.workflow_id()
             ),
             Semaphore.Jobs.V1alpha.Job.Spec.EnvVar.new(
               name: "SEMAPHORE_WORKFLOW_TRIGGERED_BY_HOOK",
               value: "true"
             ),
             Semaphore.Jobs.V1alpha.Job.Spec.EnvVar.new(
               name: "SEMAPHORE_GIT_BRANCH",
               value: "master"
             ),
             Semaphore.Jobs.V1alpha.Job.Spec.EnvVar.new(
               name: "SEMAPHORE_GIT_SHA",
               value: "HEAD"
             )
           ]
  end

  test ".map_state" do
    assert Serializer.map_state(%{aasm_state: "pending"}) == Job.Status.State.value(:PENDING)
    assert Serializer.map_state(%{aasm_state: "enqueued"}) == Job.Status.State.value(:QUEUED)
    assert Serializer.map_state(%{aasm_state: "scheduled"}) == Job.Status.State.value(:QUEUED)
    assert Serializer.map_state(%{aasm_state: "started"}) == Job.Status.State.value(:RUNNING)
    assert Serializer.map_state(%{aasm_state: "finished"}) == Job.Status.State.value(:FINISHED)
  end

  describe ".request_git_vars" do
    test "nil => []" do
      assert Serializer.request_git_vars(nil) == []
    end

    test "works for current job request" do
      assert Serializer.request_git_vars(%{
               "env_vars" => [
                 %{"name" => "NOT_A_SEMAPHORE_VAR", "value" => Base.encode64("nope")},
                 %{"name" => "SEMAPHORE_NOT_A_GIT_VAR", "value" => Base.encode64("nope")},
                 %{"name" => "SEMAPHORE_GIT_BRANCH", "value" => Base.encode64("master")}
               ]
             }) == [
               %{"name" => "SEMAPHORE_GIT_BRANCH", "value" => "master"}
             ]
    end

    test "works for old job request" do
      assert Serializer.request_git_vars(%{
               "environment_variables" => [
                 %{
                   "name" => "NOT_A_SEMAPHORE_VAR",
                   "unencrypted_content" => Base.encode64("nope")
                 },
                 %{
                   "name" => "SEMAPHORE_NOT_A_GIT_VAR",
                   "unencrypted_content" => Base.encode64("nope")
                 },
                 %{
                   "name" => "SEMAPHORE_GIT_BRANCH",
                   "unencrypted_content" => Base.encode64("master")
                 }
               ]
             }) == [
               %{"name" => "SEMAPHORE_GIT_BRANCH", "value" => "master"}
             ]
    end

    test "unrecognized request structure returns empty list" do
      assert Serializer.request_git_vars(%{
               "this_is_not_the_right_field_name" => [
                 %{
                   "name" => "NOT_A_SEMAPHORE_VAR",
                   "unencrypted_content" => Base.encode64("nope")
                 },
                 %{
                   "name" => "SEMAPHORE_NOT_A_GIT_VAR",
                   "unencrypted_content" => Base.encode64("nope")
                 },
                 %{
                   "name" => "SEMAPHORE_GIT_BRANCH",
                   "unencrypted_content" => Base.encode64("master")
                 }
               ]
             }) == []
    end
  end

  describe ".map_status_agent" do
    test "pending job => no agent is serialized" do
      job = %{aasm_state: "pending"}
      assert Serializer.map_status_agent(job) == []
    end

    test "enqueued job => no agent is serialized" do
      job = %{aasm_state: "enqueued"}
      assert Serializer.map_status_agent(job) == []
    end

    test "scheduled job => no agent is serialized" do
      job = %{aasm_state: "scheduled"}
      assert Serializer.map_status_agent(job) == []
    end

    test "started job => agent is serialized" do
      job = %{
        aasm_state: "started",
        agent_ip_address: "1.2.3.4",
        agent_name: "",
        port: "1234"
      }

      assert Serializer.map_status_agent(job) == [
               agent: %Semaphore.Jobs.V1alpha.Job.Status.Agent{
                 name: "",
                 ip: "1.2.3.4",
                 ports: [
                   %Semaphore.Jobs.V1alpha.Job.Status.Agent.Port{name: "ssh", number: "1234"}
                 ]
               }
             ]
    end

    test "finished job => agent is serialized" do
      job = %{
        aasm_state: "finished",
        agent_ip_address: "1.2.3.4",
        agent_name: "",
        port: "1234"
      }

      assert Serializer.map_status_agent(job) == [
               agent: %Semaphore.Jobs.V1alpha.Job.Status.Agent{
                 name: "",
                 ip: "1.2.3.4",
                 ports: [
                   %Semaphore.Jobs.V1alpha.Job.Status.Agent.Port{name: "ssh", number: "1234"}
                 ]
               }
             ]
    end

    test "if port and ip aren't there, they are not serialized" do
      job = %{
        aasm_state: "finished",
        agent_name: "some-self-hosted-agent",
        port: nil,
        agent_ip_address: ""
      }

      assert Serializer.map_status_agent(job) == [
               agent: %Semaphore.Jobs.V1alpha.Job.Status.Agent{
                 name: "some-self-hosted-agent",
                 ip: "",
                 ports: []
               }
             ]
    end
  end
end
