# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
defmodule Front.Models.RepoProxyTest do
  use Front.TestCase

  alias Front.Models.RepoProxy

  describe ".missing_ids" do
    test "returnes the whole list of IDs when the cached set is empty" do
      cached = []

      ids = ["1", "2", "3", "4", "5"]

      assert RepoProxy.ids_missing_in_cache(cached, ids) == ["1", "2", "3", "4", "5"]
    end

    test "returnes subset of IDs which arent found in the cached set" do
      cached = [
        %RepoProxy{
          id: "1"
        },
        %RepoProxy{
          id: "2"
        },
        %RepoProxy{
          id: "3"
        }
      ]

      ids = ["1", "2", "3", "4", "5"]

      assert RepoProxy.ids_missing_in_cache(cached, ids) == ["4", "5"]
    end

    test "returnes empty list when all IDs are found in the cached set" do
      cached = [
        %RepoProxy{
          id: "1"
        },
        %RepoProxy{
          id: "2"
        },
        %RepoProxy{
          id: "3"
        },
        %RepoProxy{
          id: "4"
        },
        %RepoProxy{
          id: "5"
        }
      ]

      ids = ["1", "2", "3", "4", "5"]

      assert RepoProxy.ids_missing_in_cache(cached, ids) == []
    end
  end

  describe ".find when ID is provided" do
    test "returns a repo proxy model => when the response is ok" do
      repo_proxy_describe_response =
        InternalApi.RepoProxy.DescribeResponse.new(
          status:
            InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
          hook:
            InternalApi.RepoProxy.Hook.new(
              hook_id: "2cb61a21-c759-4d50-a45a-1e1eaba8c1bf",
              head_commit_sha: "474488cb82e4784b8de8a91d3e58ed188fea4dbd",
              commit_message: "Pull new workflows on the branch page",
              repo_host_url: "",
              semaphore_email: "",
              repo_host_username: "jane",
              repo_host_email: "",
              user_id: "",
              repo_host_avatar_url: "https://avatars3.githubusercontent.com/u/0?v=4",
              branch_name: "master",
              tag_name: "v1.2.3",
              pr_name: "Update README.md",
              pr_branch_name: "master",
              pr_number: "5",
              git_ref_type: InternalApi.RepoProxy.Hook.Type.value(:TAG)
            )
        )

      FunRegistry.set!(
        FS.RepoProxyService,
        :describe,
        repo_proxy_describe_response
      )

      result = RepoProxy.find("2cb61a21-c759-4d50-a45a-1e1eaba8c1bf")

      assert result ==
               %RepoProxy{
                 id: "2cb61a21-c759-4d50-a45a-1e1eaba8c1bf",
                 type: "tag",
                 name: "v1.2.3",
                 repo_host_avatar_url: "https://avatars3.githubusercontent.com/u/0?v=4",
                 repo_host_username: "jane",
                 commit_message: "Pull new workflows on the branch page",
                 commit_author: "",
                 forked_pr: false,
                 pr_branch_name: "master",
                 pr_sha: "",
                 repo_host_url: "",
                 head_commit_sha: "474488cb82e4784b8de8a91d3e58ed188fea4dbd",
                 user_id: "",
                 pr_mergeable: false,
                 pr_number: "5",
                 tag_name: "v1.2.3",
                 branch_name: "master"
               }
    end

    test "returns a repo proxy model from cache => when previously cached" do
      model = %RepoProxy{
        id: "2cb61a21-c759-4d50-a45a-1e1eaba8c1bf",
        type: "tag",
        name: "v1.2.3",
        repo_host_avatar_url: "https://avatars3.githubusercontent.com/u/0?v=4",
        repo_host_username: "jane",
        commit_message: "Pull new workflows on the branch page",
        commit_author: "",
        repo_host_url: "",
        head_commit_sha: "474488cb82e4784b8de8a91d3e58ed188fea4dbd",
        user_id: "",
        pr_mergeable: false,
        pr_number: "5",
        tag_name: "v1.2.3",
        branch_name: "master"
      }

      Cacheman.put(
        :front,
        RepoProxy.cache_key("2cb61a21-c759-4d50-a45a-1e1eaba8c1bf"),
        model |> RepoProxy.encode()
      )

      assert RepoProxy.find("2cb61a21-c759-4d50-a45a-1e1eaba8c1bf") == model
    end

    test "caches repo proxy model => if not cached already" do
      Cacheman.clear(:front)

      refute Cacheman.exists?(
               :front,
               RepoProxy.cache_key("2cb61a21-c759-4d50-a45a-1e1eaba8c1bf")
             )

      repo_proxy_describe_response =
        InternalApi.RepoProxy.DescribeResponse.new(
          status:
            InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
          hook:
            InternalApi.RepoProxy.Hook.new(
              hook_id: "2cb61a21-c759-4d50-a45a-1e1eaba8c1bf",
              head_commit_sha: "474488cb82e4784b8de8a91d3e58ed188fea4dbd",
              commit_message: "Pull new workflows on the branch page",
              repo_host_url: "",
              semaphore_email: "",
              repo_host_username: "jane",
              repo_host_email: "",
              user_id: "",
              repo_host_avatar_url: "https://avatars3.githubusercontent.com/u/0?v=4",
              branch_name: "master",
              tag_name: "v1.2.3",
              pr_name: "Update README.md",
              pr_branch_name: "master",
              pr_number: "5",
              git_ref_type: InternalApi.RepoProxy.Hook.Type.value(:TAG)
            )
        )

      FunRegistry.set!(
        FS.RepoProxyService,
        :describe,
        repo_proxy_describe_response
      )

      RepoProxy.find("2cb61a21-c759-4d50-a45a-1e1eaba8c1bf")

      assert Cacheman.exists?(
               :front,
               RepoProxy.cache_key("2cb61a21-c759-4d50-a45a-1e1eaba8c1bf")
             )
    end

    test "returns nil => when the response is not ok" do
      repo_proxy_describe_response =
        InternalApi.RepoProxy.DescribeResponse.new(
          status:
            InternalApi.ResponseStatus.new(
              code: InternalApi.ResponseStatus.Code.value(:BAD_PARAM)
            )
        )

      FunRegistry.set!(
        FS.RepoProxyService,
        :describe,
        repo_proxy_describe_response
      )

      assert RepoProxy.find("2cb61a21-c759-4d50-a45a-1e1eaba8c1bf") == nil

      refute Cacheman.exists?(
               :front,
               RepoProxy.cache_key("2cb61a21-c759-4d50-a45a-1e1eaba8c1bf")
             )
    end
  end

  describe ".find when list of IDs is provided" do
    test "when the response is ok => it returns a list of repo_proxy models" do
      repo_proxy_describe_many_response =
        InternalApi.RepoProxy.DescribeManyResponse.new(
          status:
            InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
          hooks: [
            InternalApi.RepoProxy.Hook.new(
              hook_id: "2cb61a21-c759-4d50-a45a-1e1eaba8c1bf",
              head_commit_sha: "474488cb82e4784b8de8a91d3e58ed188fea4dbd",
              commit_message: "Pull new workflows on the branch page",
              repo_host_url: "",
              semaphore_email: "",
              repo_host_username: "jane",
              repo_host_email: "",
              user_id: "",
              repo_host_avatar_url: "https://avatars3.githubusercontent.com/u/0?v=4",
              branch_name: "master",
              tag_name: "v1.2.3",
              pr_name: "Update README.md",
              pr_branch_name: "master",
              pr_number: "5",
              git_ref_type: InternalApi.RepoProxy.Hook.Type.value(:TAG)
            )
          ]
        )

      FunRegistry.set!(
        FS.RepoProxyService,
        :describe_many,
        repo_proxy_describe_many_response
      )

      result =
        RepoProxy.find([
          "2cb61a21-c759-4d50-a45a-1e1eaba8c1bf"
        ])

      assert result == [
               %RepoProxy{
                 id: "2cb61a21-c759-4d50-a45a-1e1eaba8c1bf",
                 type: "tag",
                 name: "v1.2.3",
                 repo_host_avatar_url: "https://avatars3.githubusercontent.com/u/0?v=4",
                 repo_host_username: "jane",
                 commit_message: "Pull new workflows on the branch page",
                 commit_author: "",
                 repo_host_url: "",
                 head_commit_sha: "474488cb82e4784b8de8a91d3e58ed188fea4dbd",
                 user_id: "",
                 forked_pr: false,
                 pr_branch_name: "master",
                 pr_mergeable: false,
                 pr_number: "5",
                 pr_sha: "",
                 tag_name: "v1.2.3",
                 branch_name: "master"
               }
             ]
    end

    test "caches the models from response" do
      ids = ["2cb61a21-c759-4d50-a45a-1e1eaba8c1bf", "d0360f48-5bfc-4360-83e4-57b6d5ecbfcb"]

      ids
      |> Enum.each(fn id ->
        refute Cacheman.exists?(:front, RepoProxy.cache_key(id))
      end)

      repo_proxy_describe_many_response =
        InternalApi.RepoProxy.DescribeManyResponse.new(
          status:
            InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
          hooks: [
            InternalApi.RepoProxy.Hook.new(
              hook_id: "2cb61a21-c759-4d50-a45a-1e1eaba8c1bf",
              head_commit_sha: "474488cb82e4784b8de8a91d3e58ed188fea4dbd",
              commit_message: "Pull new workflows on the branch page",
              repo_host_url: "",
              semaphore_email: "",
              repo_host_username: "jane",
              repo_host_email: "",
              user_id: "",
              repo_host_avatar_url: "https://avatars3.githubusercontent.com/u/0?v=4",
              branch_name: "master",
              tag_name: "v1.2.3",
              pr_name: "Update README.md",
              pr_branch_name: "master",
              pr_number: "5",
              git_ref_type: InternalApi.RepoProxy.Hook.Type.value(:TAG)
            ),
            InternalApi.RepoProxy.Hook.new(
              hook_id: "d0360f48-5bfc-4360-83e4-57b6d5ecbfcb",
              head_commit_sha: "474488cb82e4784b8de8a91d3e58ed188fea4dbd",
              commit_message: "Pull new workflows on the branch page",
              repo_host_url: "",
              semaphore_email: "",
              repo_host_username: "jane",
              repo_host_email: "",
              user_id: "",
              repo_host_avatar_url: "https://avatars3.githubusercontent.com/u/0?v=4",
              branch_name: "master",
              tag_name: "v1.2.3",
              pr_name: "Update README.md",
              pr_branch_name: "master",
              pr_number: "5",
              git_ref_type: InternalApi.RepoProxy.Hook.Type.value(:TAG)
            )
          ]
        )

      FunRegistry.set!(
        FS.RepoProxyService,
        :describe_many,
        repo_proxy_describe_many_response
      )

      RepoProxy.find([
        "2cb61a21-c759-4d50-a45a-1e1eaba8c1bf",
        "d0360f48-5bfc-4360-83e4-57b6d5ecbfcb"
      ])

      ids
      |> Enum.each(fn id ->
        assert Cacheman.exists?(:front, RepoProxy.cache_key(id))
      end)
    end

    test "returns hooks when some are cached and some are fetched from API" do
      ids = [
        "2cb61a21-c759-4d50-a45a-1e1eaba8c1bf",
        "d0360f48-5bfc-4360-83e4-57b6d5ecbfcb"
      ]

      # Cache some hooks by calling the find function
      FunRegistry.set!(
        FS.RepoProxyService,
        :describe_many,
        InternalApi.RepoProxy.DescribeManyResponse.new(
          status:
            InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
          hooks: [
            InternalApi.RepoProxy.Hook.new(
              hook_id: "2cb61a21-c759-4d50-a45a-1e1eaba8c1bf",
              head_commit_sha: "474488cb82e4784b8de8a91d3e58ed188fea4dbd",
              commit_message: "Pull new workflows on the branch page",
              repo_host_url: "",
              semaphore_email: "",
              repo_host_username: "jane",
              repo_host_email: "",
              user_id: "",
              repo_host_avatar_url: "https://avatars3.githubusercontent.com/u/0?v=4",
              branch_name: "master",
              tag_name: "v1.2.3",
              pr_name: "Update README.md",
              pr_branch_name: "master",
              pr_number: "5",
              git_ref_type: InternalApi.RepoProxy.Hook.Type.value(:TAG)
            ),
            InternalApi.RepoProxy.Hook.new(
              hook_id: "d0360f48-5bfc-4360-83e4-57b6d5ecbfcb",
              head_commit_sha: "474488cb82e4784b8de8a91d3e58ed188fea4dbd",
              commit_message: "Pull new workflows on the branch page",
              repo_host_url: "",
              semaphore_email: "",
              repo_host_username: "jane",
              repo_host_email: "",
              user_id: "",
              repo_host_avatar_url: "https://avatars3.githubusercontent.com/u/0?v=4",
              branch_name: "master",
              tag_name: "v1.2.3",
              pr_name: "Update README.md",
              pr_branch_name: "master",
              pr_number: "5",
              git_ref_type: InternalApi.RepoProxy.Hook.Type.value(:TAG)
            )
          ]
        )
      )

      RepoProxy.find(ids)

      ids
      |> Enum.each(fn id ->
        assert Cacheman.exists?(:front, RepoProxy.cache_key(id))
      end)

      FunRegistry.set!(
        FS.RepoProxyService,
        :describe_many,
        InternalApi.RepoProxy.DescribeManyResponse.new(
          status:
            InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
          hooks: [
            InternalApi.RepoProxy.Hook.new(
              hook_id: "2cb61a21-c759-4d50-a45a-1e1eaba8c1bf",
              head_commit_sha: "474488cb82e4784b8de8a91d3e58ed188fea4dbd",
              commit_message: "Pull new workflows on the branch page",
              repo_host_url: "",
              semaphore_email: "",
              repo_host_username: "jane",
              repo_host_email: "",
              user_id: "",
              repo_host_avatar_url: "https://avatars3.githubusercontent.com/u/0?v=4",
              branch_name: "master",
              tag_name: "v1.2.3",
              pr_name: "Update README.md",
              pr_branch_name: "master",
              pr_number: "5",
              git_ref_type: InternalApi.RepoProxy.Hook.Type.value(:TAG)
            ),
            InternalApi.RepoProxy.Hook.new(
              hook_id: "d0360f48-5bfc-4360-83e4-57b6d5ecbfcb",
              head_commit_sha: "474488cb82e4784b8de8a91d3e58ed188fea4dbd",
              commit_message: "Pull new workflows on the branch page",
              repo_host_url: "",
              semaphore_email: "",
              repo_host_username: "jane",
              repo_host_email: "",
              user_id: "",
              repo_host_avatar_url: "https://avatars3.githubusercontent.com/u/0?v=4",
              branch_name: "master",
              tag_name: "v1.2.3",
              pr_name: "Update README.md",
              pr_branch_name: "master",
              pr_number: "5",
              git_ref_type: InternalApi.RepoProxy.Hook.Type.value(:TAG)
            ),
            InternalApi.RepoProxy.Hook.new(
              hook_id: "9678a5ef-fda9-4168-983c-ad589eb72029",
              head_commit_sha: "474488cb82e4784b8de8a91d3e58ed188fea4dbd",
              commit_message: "Pull new workflows on the branch page",
              repo_host_url: "",
              semaphore_email: "",
              repo_host_username: "jane",
              repo_host_email: "",
              user_id: "",
              repo_host_avatar_url: "https://avatars3.githubusercontent.com/u/0?v=4",
              branch_name: "master",
              tag_name: "v1.2.3",
              pr_name: "Update README.md",
              pr_branch_name: "master",
              pr_number: "5",
              git_ref_type: InternalApi.RepoProxy.Hook.Type.value(:TAG)
            )
          ]
        )
      )

      RepoProxy.find(ids ++ ["9678a5ef-fda9-4168-983c-ad589eb72029"])

      assert Cacheman.exists?(:front, RepoProxy.cache_key("9678a5ef-fda9-4168-983c-ad589eb72029"))
    end

    test "when the response is not ok => it raises an error" do
      repo_proxy_describe_many_response =
        InternalApi.RepoProxy.DescribeManyResponse.new(
          status:
            InternalApi.ResponseStatus.new(
              code: InternalApi.ResponseStatus.Code.value(:BAD_PARAM)
            )
        )

      FunRegistry.set!(
        FS.RepoProxyService,
        :describe_many,
        repo_proxy_describe_many_response
      )

      assert_raise CaseClauseError, fn ->
        RepoProxy.find([
          "2cb61a21-c759-4d50-a45a-1e1eaba8c1bf"
        ])
      end
    end

    test "when the request fails => it raises an error" do
      FunRegistry.set!(
        FS.RepoProxyService,
        :describe_many,
        fn -> raise "oops!" end
      )

      assert_raise MatchError, fn ->
        RepoProxy.find([
          "2cb61a21-c759-4d50-a45a-1e1eaba8c1bf"
        ])
      end
    end
  end
end
