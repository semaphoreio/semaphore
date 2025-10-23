defmodule Notifications.Workers.CoordinatorTest do
  use Notifications.DataCase
  import Mock

  alias Notifications.Workers.Coordinator.PipelineFinished
  alias Notifications.Workers.Slack
  alias Notifications.Models.{Rule, Notification, Pattern}
  alias Notifications.Repo

  @pipeline_id Ecto.UUID.generate()
  @project_id Ecto.UUID.generate()
  @org_id Ecto.UUID.generate()
  @creator_id Ecto.UUID.generate()

  setup do
    mock_grpc_services()
    :ok
  end

  describe ".handle_message" do
    test "when notification creator has access to the project" do
      add_notification_with_rule_and_patterns()
      authorize_everything()

      with_mock Slack, publish: fn _, _, _, _ -> :ok end do
        pipeline_event = InternalApi.Plumber.PipelineEvent.new(pipeline_id: @pipeline_id)
        message = InternalApi.Plumber.PipelineEvent.encode(pipeline_event)

        assert PipelineFinished.handle_message(message)
        assert_called(Slack.publish(:_, :_, :_, :_))
      end
    end

    test "when notification creator doesn't have access to the project" do
      add_notification_with_rule_and_patterns()

      with_mock Slack, publish: fn _, _, _, _ -> :error end do
        pipeline_event = InternalApi.Plumber.PipelineEvent.new(pipeline_id: @pipeline_id)
        message = InternalApi.Plumber.PipelineEvent.encode(pipeline_event)

        assert PipelineFinished.handle_message(message)
        assert_not_called(Slack.publish(:_, :_, :_, :_))
      end
    end

    test "when notification has empty creator_id" do
      setup_notification_with_empty_creator()

      with_mock Slack, publish: fn _, _, _, _ -> :ok end do
        pipeline_event = InternalApi.Plumber.PipelineEvent.new(pipeline_id: @pipeline_id)
        message = InternalApi.Plumber.PipelineEvent.encode(pipeline_event)

        assert PipelineFinished.handle_message(message)
        assert_called(Slack.publish(:_, :_, :_, :_))
      end
    end

    test "when hook is a tag event with matching tag pattern" do
      add_notification_with_tag_patterns()
      authorize_everything()
      mock_tag_hook("v1.0.0")

      with_mock Slack, publish: fn _, _, _, _ -> :ok end do
        pipeline_event = InternalApi.Plumber.PipelineEvent.new(pipeline_id: @pipeline_id)
        message = InternalApi.Plumber.PipelineEvent.encode(pipeline_event)

        assert PipelineFinished.handle_message(message)
        assert_called(Slack.publish(:_, :_, :_, :_))
      end
    end

    test "when hook is a tag event with non-matching tag pattern" do
      add_notification_with_tag_patterns()
      authorize_everything()
      mock_tag_hook("hotfix-123")

      with_mock Slack, publish: fn _, _, _, _ -> :ok end do
        pipeline_event = InternalApi.Plumber.PipelineEvent.new(pipeline_id: @pipeline_id)
        message = InternalApi.Plumber.PipelineEvent.encode(pipeline_event)

        assert PipelineFinished.handle_message(message)
        assert_not_called(Slack.publish(:_, :_, :_, :_))
      end
    end

    test "when hook is a tag event with branch patterns - should ignore branch filtering" do
      add_notification_with_branch_and_tag_patterns()
      authorize_everything()
      mock_tag_hook("v1.0.0")

      with_mock Slack, publish: fn _, _, _, _ -> :ok end do
        pipeline_event = InternalApi.Plumber.PipelineEvent.new(pipeline_id: @pipeline_id)
        message = InternalApi.Plumber.PipelineEvent.encode(pipeline_event)

        assert PipelineFinished.handle_message(message)
        # Should trigger despite branch_name being "refs/tags/v1.0.0" which doesn't match "master"
        assert_called(Slack.publish(:_, :_, :_, :_))
      end
    end

    test "when hook is a regular branch event - should work normally" do
      add_notification_with_branch_and_tag_patterns()
      authorize_everything()
      mock_branch_hook("master")

      with_mock Slack, publish: fn _, _, _, _ -> :ok end do
        pipeline_event = InternalApi.Plumber.PipelineEvent.new(pipeline_id: @pipeline_id)
        message = InternalApi.Plumber.PipelineEvent.encode(pipeline_event)

        assert PipelineFinished.handle_message(message)
        assert_called(Slack.publish(:_, :_, :_, :_))
      end
    end
  end

  ###
  ### Helper funcs
  ###

  defp authorize_everything do
    GrpcMock.stub(
      RBACMock,
      :list_user_permissions,
      fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(
          permissions: ["organization.view", "project.view"]
        )
      end
    )
  end

  defp mock_grpc_services do
    alias InternalApi.{Plumber, Projecthub, RepoProxy, PlumberWF, Organization, ResponseStatus}

    GrpcMock.stub(
      PipelinesMock,
      :describe,
      fn _, _ ->
        Plumber.DescribeResponse.new(
          response_status: Plumber.ResponseStatus.new(code: :OK),
          pipeline:
            Plumber.Pipeline.new(
              project_id: @project_id,
              branch_name: "master",
              yaml_file_name: "semaphore.yml",
              result: :PASSED
            )
        )
      end
    )

    GrpcMock.stub(
      ProjectServiceMock,
      :describe,
      fn _, _ ->
        project =
          Projecthub.Project.new(
            metadata:
              Projecthub.Project.Metadata.new(
                id: @project_id,
                org_id: @org_id,
                name: "test-project"
              )
          )

        Projecthub.DescribeResponse.new(
          metadata:
            Projecthub.ResponseMeta.new(
              status:
                Projecthub.ResponseMeta.Status.new(code: Projecthub.ResponseMeta.Code.value(:OK))
            ),
          project: project
        )
      end
    )

    GrpcMock.stub(
      RepoProxyMock,
      :describe,
      fn _, _ ->
        RepoProxy.DescribeResponse.new(
          status: ResponseStatus.new(code: ResponseStatus.Code.value(:OK)),
          hook: RepoProxy.Hook.new()
        )
      end
    )

    GrpcMock.stub(
      WorkflowMock,
      :describe,
      fn _, _ ->
        PlumberWF.DescribeResponse.new(
          status: ResponseStatus.new(code: ResponseStatus.Code.value(:OK)),
          workflow: PlumberWF.WorkflowDetails.new()
        )
      end
    )

    GrpcMock.stub(
      OrganizationMock,
      :describe,
      fn _, _ ->
        Organization.DescribeResponse.new(
          status: ResponseStatus.new(code: ResponseStatus.Code.value(:OK)),
          organization: Organization.Organization.new()
        )
      end
    )

    GrpcMock.stub(
      RBACMock,
      :list_user_permissions,
      fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(permissions: [])
      end
    )
  end

  defp setup_notification_with_empty_creator do
    notification =
      Repo.insert!(%Notification{
        org_id: @org_id,
        creator_id: nil,
        name: "Test Notification Empty Creator",
        spec: %{"rules" => []}
      })

    create_rule_with_patterns(notification)
  end

  defp add_notification_with_rule_and_patterns do
    notification =
      Repo.insert!(%Notification{
        org_id: @org_id,
        creator_id: @creator_id,
        name: "Test Notification",
        spec: %{"rules" => []}
      })

    create_rule_with_patterns(notification)
  end

  defp create_rule_with_patterns(notification) do
    rule =
      Repo.insert!(%Rule{
        org_id: @org_id,
        notification_id: notification.id,
        name: "Test Rule",
        slack: %{
          "endpoint" => "https://hooks.slack.com/services/TEST",
          "channels" => ["#test-channel"]
        },
        email: %{},
        webhook: %{}
      })

    # Add patterns to the rule that will match our pipeline
    Repo.insert!(%Pattern{
      org_id: @org_id,
      rule_id: rule.id,
      type: "project",
      regex: true,
      term: ".*"
    })

    Repo.insert!(%Pattern{
      org_id: @org_id,
      rule_id: rule.id,
      type: "branch",
      regex: true,
      term: ".*"
    })

    Repo.insert!(%Pattern{
      org_id: @org_id,
      rule_id: rule.id,
      type: "pipeline",
      regex: true,
      term: ".*"
    })

    Repo.insert!(%Pattern{
      org_id: @org_id,
      rule_id: rule.id,
      type: "result",
      regex: true,
      term: ".*"
    })

    rule
  end

  defp add_notification_with_tag_patterns do
    notification =
      Repo.insert!(%Notification{
        org_id: @org_id,
        creator_id: @creator_id,
        name: "Test Tag Notification",
        spec: %{"rules" => []}
      })

    create_rule_with_tag_patterns(notification)
  end

  defp add_notification_with_branch_and_tag_patterns do
    notification =
      Repo.insert!(%Notification{
        org_id: @org_id,
        creator_id: @creator_id,
        name: "Test Branch and Tag Notification",
        spec: %{"rules" => []}
      })

    create_rule_with_branch_and_tag_patterns(notification)
  end

  defp create_rule_with_tag_patterns(notification) do
    rule =
      Repo.insert!(%Rule{
        org_id: @org_id,
        notification_id: notification.id,
        name: "Test Tag Rule",
        slack: %{
          "endpoint" => "https://hooks.slack.com/services/TEST",
          "channels" => ["#test-channel"]
        },
        email: %{},
        webhook: %{}
      })

    # Add patterns that will match tags starting with "v"
    Repo.insert!(%Pattern{
      org_id: @org_id,
      rule_id: rule.id,
      type: "project",
      regex: true,
      term: ".*"
    })

    Repo.insert!(%Pattern{
      org_id: @org_id,
      rule_id: rule.id,
      type: "pipeline",
      regex: true,
      term: ".*"
    })

    Repo.insert!(%Pattern{
      org_id: @org_id,
      rule_id: rule.id,
      type: "result",
      regex: true,
      term: ".*"
    })

    # Tag pattern that matches "v*"
    Repo.insert!(%Pattern{
      org_id: @org_id,
      rule_id: rule.id,
      type: "tag",
      regex: true,
      term: "^v.*"
    })

    rule
  end

  defp create_rule_with_branch_and_tag_patterns(notification) do
    rule =
      Repo.insert!(%Rule{
        org_id: @org_id,
        notification_id: notification.id,
        name: "Test Branch and Tag Rule",
        slack: %{
          "endpoint" => "https://hooks.slack.com/services/TEST",
          "channels" => ["#test-channel"]
        },
        email: %{},
        webhook: %{}
      })

    # Add patterns for all types
    Repo.insert!(%Pattern{
      org_id: @org_id,
      rule_id: rule.id,
      type: "project",
      regex: true,
      term: ".*"
    })

    # Branch pattern that only matches "master"
    Repo.insert!(%Pattern{
      org_id: @org_id,
      rule_id: rule.id,
      type: "branch",
      regex: false,
      term: "master"
    })

    Repo.insert!(%Pattern{
      org_id: @org_id,
      rule_id: rule.id,
      type: "pipeline",
      regex: true,
      term: ".*"
    })

    Repo.insert!(%Pattern{
      org_id: @org_id,
      rule_id: rule.id,
      type: "result",
      regex: true,
      term: ".*"
    })

    # Tag pattern that matches all tags (works for both branch and tag events)
    Repo.insert!(%Pattern{
      org_id: @org_id,
      rule_id: rule.id,
      type: "tag",
      regex: true,
      term: ".*"
    })

    rule
  end

  defp mock_tag_hook(tag_name) do
    GrpcMock.stub(
      RepoProxyMock,
      :describe,
      fn _, _ ->
        alias InternalApi.{RepoProxy, ResponseStatus}

        RepoProxy.DescribeResponse.new(
          status: ResponseStatus.new(code: ResponseStatus.Code.value(:OK)),
          hook:
            RepoProxy.Hook.new(
              git_ref_type: :TAG,
              git_ref: tag_name,
              branch_name: "refs/tags/#{tag_name}",
              pr_branch_name: "",
              tag_name: tag_name
            )
        )
      end
    )
  end

  defp mock_branch_hook(branch_name) do
    GrpcMock.stub(
      RepoProxyMock,
      :describe,
      fn _, _ ->
        alias InternalApi.{RepoProxy, ResponseStatus}

        RepoProxy.DescribeResponse.new(
          status: ResponseStatus.new(code: ResponseStatus.Code.value(:OK)),
          hook:
            RepoProxy.Hook.new(
              git_ref_type: :BRANCH,
              git_ref: branch_name,
              branch_name: branch_name,
              pr_branch_name: "",
              tag_name: ""
            )
        )
      end
    )
  end
end
