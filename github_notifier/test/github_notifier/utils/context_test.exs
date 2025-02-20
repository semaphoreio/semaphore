defmodule GithubNotifier.Utils.Context.Test do
  use ExUnit.Case

  alias GithubNotifier.Utils.Context

  test "returns default context for new push build" do
    repo_proxy = %GithubNotifier.Models.RepoProxy{
      git_ref_type: InternalApi.RepoProxy.Hook.Type.value(:BRANCH),
      branch_name: "master"
    }

    assert Context.prepare("Foo", repo_proxy, "org_id") == "ci/semaphoreci/push: Foo"
  end

  test "returns push context for push build when it is gh queue and organization is not whitelisted" do
    repo_proxy = %GithubNotifier.Models.RepoProxy{
      git_ref_type: InternalApi.RepoProxy.Hook.Type.value(:BRANCH),
      branch_name: "gh-readonly-queue/main/pr-20394-703131cc2cc2b296944b7a2d9ddc63cd8c0b19aa"
    }

    assert Context.prepare("Foo", repo_proxy, "org_id") == "ci/semaphoreci/push: Foo"
  end

  describe "with merge queues as prs" do
    setup do
      GrpcMock.stub(
        FeatureMock,
        :list_organization_features,
        Support.Factories.feature_list_response(:ENABLED)
      )

      on_exit(fn ->
        GrpcMock.stub(
          FeatureMock,
          :list_organization_features,
          Support.Factories.feature_list_response()
        )
      end)

      :ok
    end

    test "returns push context for push build when it is not a gh queue and organization is whitelisted" do
      repo_proxy = %GithubNotifier.Models.RepoProxy{
        git_ref_type: InternalApi.RepoProxy.Hook.Type.value(:BRANCH),
        branch_name: "master"
      }

      assert Context.prepare("Foo", repo_proxy, "org_with_gh_merge_queues_as_prs") ==
               "ci/semaphoreci/push: Foo"
    end

    test "returns pr context for push build when it is gh queue and organization is whitelisted" do
      repo_proxy = %GithubNotifier.Models.RepoProxy{
        git_ref_type: InternalApi.RepoProxy.Hook.Type.value(:BRANCH),
        branch_name: "gh-readonly-queue/main/pr-20394-703131cc2cc2b296944b7a2d9ddc63cd8c0b19aa"
      }

      assert Context.prepare("Foo", repo_proxy, "org_with_gh_merge_queues_as_prs") ==
               "ci/semaphoreci/pr: Foo"
    end
  end

  test "returns default context for tag build" do
    repo_proxy = %GithubNotifier.Models.RepoProxy{
      git_ref_type: InternalApi.RepoProxy.Hook.Type.value(:TAG),
      branch_name: "master"
    }

    assert Context.prepare("Foo", repo_proxy, "org_id") == "ci/semaphoreci/tag: Foo"
  end

  test "returns default context for pr build" do
    repo_proxy = %GithubNotifier.Models.RepoProxy{
      git_ref_type: InternalApi.RepoProxy.Hook.Type.value(:PR),
      branch_name: "master"
    }

    assert Context.prepare("Foo", repo_proxy, "org_id") == "ci/semaphoreci/pr: Foo"
  end

  test "returns context with reconfigured prefix for non pr build" do
    setup_changed_prefix()

    repo_proxy = %GithubNotifier.Models.RepoProxy{
      git_ref_type: InternalApi.RepoProxy.Hook.Type.value(:BRANCH),
      branch_name: "master"
    }

    assert Context.prepare("Foo", repo_proxy, "org_id") == "ci/semonprem/push: Foo"
  end

  test "returns context with reconfigured prefix for tag build" do
    setup_changed_prefix()

    repo_proxy = %GithubNotifier.Models.RepoProxy{
      git_ref_type: InternalApi.RepoProxy.Hook.Type.value(:TAG),
      branch_name: "master"
    }

    assert Context.prepare("Foo", repo_proxy, "org_id") == "ci/semonprem/tag: Foo"
  end

  test "returns context with reconfigured prefix for pr build" do
    setup_changed_prefix()

    repo_proxy = %GithubNotifier.Models.RepoProxy{
      git_ref_type: InternalApi.RepoProxy.Hook.Type.value(:PR),
      branch_name: "master"
    }

    assert Context.prepare("Foo", repo_proxy, "org_id") == "ci/semonprem/pr: Foo"
  end

  defp setup_changed_prefix do
    prev_prefix = Application.get_env(:github_notifier, :context_prefix)
    Application.put_env(:github_notifier, :context_prefix, "ci/semonprem")

    on_exit(fn ->
      Application.put_env(:github_notifier, :context_prefix, prev_prefix)
    end)
  end
end
