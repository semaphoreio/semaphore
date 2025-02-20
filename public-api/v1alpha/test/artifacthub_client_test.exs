defmodule PipelinesAPI.ArtifactHubClient.Test do
  use ExUnit.Case

  alias PipelinesAPI.ArtifactHubClient
  alias InternalApi.Artifacthub.RetentionPolicy
  alias InternalApi.Artifacthub.RetentionPolicy.RetentionPolicyRule, as: RPR

  @url_env_name "ARTIFACTS_HUB_URL"
  @mock_server_port 50052
  @one_week 7 * 24 * 3600

  setup do
    Support.Stubs.reset()
    Support.Stubs.build_shared_factories()
    org = Support.Stubs.DB.first(:organizations)
    owner = Support.Stubs.DB.first(:users)
    project = Support.Stubs.Project.create(org, owner)

    policy = %RetentionPolicy{
      project_level_retention_policies: [
        %RPR{selector: "/valid_value_1", age: @one_week}
      ],
      workflow_level_retention_policies: [
        %RPR{selector: "/valid_value_1", age: 2 * @one_week}
      ],
      job_level_retention_policies: [
        %RPR{selector: "/valid_value_1", age: 3 * @one_week}
      ]
    }

    artifact_id = project.api_model.spec.artifact_store_id

    Support.Stubs.Artifacthub.create_policy(artifact_id, policy)

    {:ok, %{project: project}}
  end

  # update_retention_policy call

  test "when URL is invalid in update_retention_policy call => timeout occures" do
    System.put_env(@url_env_name, "invalid_url:12345")
    request = %{}

    assert {:error, {:internal, message}} = ArtifactHubClient.update_retention_policy(request)
    assert message == "Internal error"

    System.put_env(@url_env_name, "localhost:#{@mock_server_port}")
  end

  test "when time-out occures in update_retention_policy call => error is returned" do
    System.put_env(@url_env_name, "localhost:#{@mock_server_port}")
    request = %{"artifact_store_id" => "timeout"}

    assert {:error, {:internal, message}} = ArtifactHubClient.update_retention_policy(request)
    assert message == "Internal error"
  end

  test "when client.update_retention_policy is called => gRPC server response is processed correctly" do
    System.put_env(@url_env_name, "localhost:#{@mock_server_port}")

    # OK response

    request = %{
      "artifact_store_id" => UUID.uuid4(),
      "project_level_retention_policies" => [%{"selector" => ".*", "age" => "5 weeks"}],
      "workflow_level_retention_policies" => [%{"selector" => ".*", "age" => "3 months"}],
      "job_level_retention_policies" => [%{"selector" => ".*", "age" => "1 year"}]
    }

    assert {:ok, response} = ArtifactHubClient.update_retention_policy(request)
    assert response.project_level_retention_policies == [%{selector: ".*", age: "5 weeks"}]
    assert response.workflow_level_retention_policies == [%{selector: ".*", age: "3 months"}]
    assert response.job_level_retention_policies == [%{selector: ".*", age: "1 year"}]

    # FailedPrecondition response

    request = %{"artifact_store_id" => "FailedPrecondition"}

    assert {:error, {:user, message}} = ArtifactHubClient.update_retention_policy(request)
    assert message == "Invalid age field value."
  end

  # describe_retention_policy call

  test "when URL is invalid in describe_retention_policy call => timeout occures" do
    System.put_env(@url_env_name, "invalid_url:12345")
    request = %{}

    assert {:error, {:internal, message}} = ArtifactHubClient.describe_retention_policy(request)
    assert message == "Internal error"

    System.put_env(@url_env_name, "localhost:#{@mock_server_port}")
  end

  test "when time-out occures in describe_retention_policy call => error is returned" do
    System.put_env(@url_env_name, "localhost:#{@mock_server_port}")
    request = %{"artifact_store_id" => "timeout"}

    assert {:error, {:internal, message}} = ArtifactHubClient.describe_retention_policy(request)
    assert message == "Internal error"
  end

  test "when client.describe_retention_policy is called => gRPC server response is processed correctly",
       ctx do
    System.put_env(@url_env_name, "localhost:#{@mock_server_port}")

    # OK response

    artifact_id = ctx.project.api_model.spec.artifact_store_id
    request = %{"artifact_store_id" => artifact_id}

    assert {:ok, response} = ArtifactHubClient.describe_retention_policy(request)

    assert response.project_level_retention_policies == [
             %{selector: "/valid_value_1", age: "1 week"}
           ]

    assert response.workflow_level_retention_policies == [
             %{selector: "/valid_value_1", age: "2 weeks"}
           ]

    assert response.job_level_retention_policies == [
             %{selector: "/valid_value_1", age: "3 weeks"}
           ]

    # FailedPrecondition response

    request = %{"artifact_store_id" => "FailedPrecondition"}

    assert {:error, {:user, message}} = ArtifactHubClient.describe_retention_policy(request)
    assert message == "artifact bucket ID is malformed"
  end
end
