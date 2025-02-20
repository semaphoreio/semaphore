# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
defmodule Support.GitlabHooks do
  @moduledoc """
  Module serves to collect various hooks examples used for testing the hook parsing
  functions.
  The following are the available functions with example hooks:

  - push_new_branch_with_commits
  - push_new_branch_no_commits
  - push_commit
  - push_delete_branch
  - tag_push
  - merge_request_open
  - merge_request_closed
  - branch_push_skip_ci
  - tag_push_skip_ci
  """

  def push_new_branch_with_commits do
    %{
      "object_kind" => "push",
      "event_name" => "push",
      "before" => "0000000000000000000000000000000000000000",
      "after" => "da1560886d4f094c3e6c9ef40349f7d38b5d27d7",
      "ref" => "refs/heads/master",
      "ref_protected" => true,
      "checkout_sha" => "da1560886d4f094c3e6c9ef40349f7d38b5d27d7",
      "user_id" => 4,
      "user_name" => "John Smith",
      "user_username" => "jsmith",
      "user_email" => "john@example.com",
      "user_avatar" =>
        "https://s.gravatar.com/avatar/d4c74594d841139328695756648b6bd6?s=8://s.gravatar.com/avatar/d4c74594d841139328695756648b6bd6?s=80",
      "project_id" => 15,
      "project" => %{
        "id" => 15,
        "name" => "Diaspora",
        "description" => "",
        "web_url" => "http://example.com/mike/diaspora",
        "avatar_url" => nil,
        "git_ssh_url" => "git@example.com:mike/diaspora.git",
        "git_http_url" => "http://example.com/mike/diaspora.git",
        "namespace" => "Mike",
        "visibility_level" => 0,
        "path_with_namespace" => "mike/diaspora",
        "default_branch" => "master",
        "homepage" => "http://example.com/mike/diaspora",
        "url" => "git@example.com:mike/diaspora.git",
        "ssh_url" => "git@example.com:mike/diaspora.git",
        "http_url" => "http://example.com/mike/diaspora.git"
      },
      "repository" => %{
        "name" => "Diaspora",
        "url" => "git@example.com:mike/diaspora.git",
        "description" => "",
        "homepage" => "http://example.com/mike/diaspora",
        "git_http_url" => "http://example.com/mike/diaspora.git",
        "git_ssh_url" => "git@example.com:mike/diaspora.git",
        "visibility_level" => 0
      },
      "commits" => [
        %{
          "id" => "b6568db1bc1dcd7f8b4d5a946b0b91f9dacd7327",
          "message" =>
            "Update Catalan translation to e38cb41.\n\nSee https://gitlab.com/gitlab-org/gitlab for more information",
          "title" => "Update Catalan translation to e38cb41.",
          "timestamp" => "2011-12-12T14:27:31+02:00",
          "url" => "http://example.com/mike/diaspora/commit/b6568db1bc1dcd7f8b4d5a946b0b91f9dacd7327",
          "author" => %{
            "name" => "Jordi Mallach",
            "email" => "jordi@softcatala.org"
          },
          "added" => ["CHANGELOG"],
          "modified" => ["app/controller/application.rb"],
          "removed" => []
        },
        %{
          "id" => "da1560886d4f094c3e6c9ef40349f7d38b5d27d7",
          "message" => "fixed readme",
          "title" => "fixed readme",
          "timestamp" => "2012-01-03T23:36:29+02:00",
          "url" => "http://example.com/mike/diaspora/commit/da1560886d4f094c3e6c9ef40349f7d38b5d27d7",
          "author" => %{
            "name" => "GitLab dev user",
            "email" => "gitlabdev@dv6700.(none)"
          },
          "added" => ["CHANGELOG"],
          "modified" => ["app/controller/application.rb"],
          "removed" => []
        }
      ],
      "total_commits_count" => 4
    }
  end

  def push_new_branch_no_commits do
    %{
      "object_kind" => "push",
      "event_name" => "push",
      "before" => "0000000000000000000000000000000000000000",
      "after" => "0000000000000000000000000000000000000000",
      "ref" => "refs/heads/master",
      "ref_protected" => true,
      "checkout_sha" => nil,
      "user_id" => 4,
      "user_name" => "John Smith",
      "user_username" => "jsmith",
      "user_email" => "john@example.com",
      "user_avatar" =>
        "https://s.gravatar.com/avatar/d4c74594d841139328695756648b6bd6?s=8://s.gravatar.com/avatar/d4c74594d841139328695756648b6bd6?s=80",
      "project_id" => 15,
      "project" => %{
        "id" => 15,
        "name" => "Diaspora",
        "description" => "",
        "web_url" => "http://example.com/mike/diaspora",
        "avatar_url" => nil,
        "git_ssh_url" => "git@example.com:mike/diaspora.git",
        "git_http_url" => "http://example.com/mike/diaspora.git",
        "namespace" => "Mike",
        "visibility_level" => 0,
        "path_with_namespace" => "mike/diaspora",
        "default_branch" => "master",
        "homepage" => "http://example.com/mike/diaspora",
        "url" => "git@example.com:mike/diaspora.git",
        "ssh_url" => "git@example.com:mike/diaspora.git",
        "http_url" => "http://example.com/mike/diaspora.git"
      },
      "repository" => %{
        "name" => "Diaspora",
        "url" => "git@example.com:mike/diaspora.git",
        "description" => "",
        "homepage" => "http://example.com/mike/diaspora",
        "git_http_url" => "http://example.com/mike/diaspora.git",
        "git_ssh_url" => "git@example.com:mike/diaspora.git",
        "visibility_level" => 0
      },
      "commits" => [],
      "total_commits_count" => 4
    }
  end

  def push_commit do
    %{
      "object_kind" => "push",
      "event_name" => "push",
      "before" => "b6568db1bc1dcd7f8b4d5a946b0b91f9dacd7327",
      "after" => "da1560886d4f094c3e6c9ef40349f7d38b5d27d7",
      "ref" => "refs/heads/master",
      "ref_protected" => true,
      "checkout_sha" => "da1560886d4f094c3e6c9ef40349f7d38b5d27d7",
      "user_id" => 4,
      "user_name" => "John Smith",
      "user_username" => "jsmith",
      "user_email" => "john@example.com",
      "user_avatar" =>
        "https://s.gravatar.com/avatar/d4c74594d841139328695756648b6bd6?s=8://s.gravatar.com/avatar/d4c74594d841139328695756648b6bd6?s=80",
      "project_id" => 15,
      "project" => %{
        "id" => 15,
        "name" => "Diaspora",
        "description" => "",
        "web_url" => "http://example.com/mike/diaspora",
        "avatar_url" => nil,
        "git_ssh_url" => "git@example.com:mike/diaspora.git",
        "git_http_url" => "http://example.com/mike/diaspora.git",
        "namespace" => "Mike",
        "visibility_level" => 0,
        "path_with_namespace" => "mike/diaspora",
        "default_branch" => "master",
        "homepage" => "http://example.com/mike/diaspora",
        "url" => "git@example.com:mike/diaspora.git",
        "ssh_url" => "git@example.com:mike/diaspora.git",
        "http_url" => "http://example.com/mike/diaspora.git"
      },
      "repository" => %{
        "name" => "Diaspora",
        "url" => "git@example.com:mike/diaspora.git",
        "description" => "",
        "homepage" => "http://example.com/mike/diaspora",
        "git_http_url" => "http://example.com/mike/diaspora.git",
        "git_ssh_url" => "git@example.com:mike/diaspora.git",
        "visibility_level" => 0
      },
      "commits" => [
        %{
          "id" => "b6568db1bc1dcd7f8b4d5a946b0b91f9dacd7327",
          "message" =>
            "Update Catalan translation to e38cb41.\n\nSee https://gitlab.com/gitlab-org/gitlab for more information",
          "title" => "Update Catalan translation to e38cb41.",
          "timestamp" => "2011-12-12T14:27:31+02:00",
          "url" => "http://example.com/mike/diaspora/commit/b6568db1bc1dcd7f8b4d5a946b0b91f9dacd7327",
          "author" => %{
            "name" => "Jordi Mallach",
            "email" => "jordi@softcatala.org"
          },
          "added" => ["CHANGELOG"],
          "modified" => ["app/controller/application.rb"],
          "removed" => []
        },
        %{
          "id" => "da1560886d4f094c3e6c9ef40349f7d38b5d27d7",
          "message" => "fixed readme",
          "title" => "fixed readme",
          "timestamp" => "2012-01-03T23:36:29+02:00",
          "url" => "http://example.com/mike/diaspora/commit/da1560886d4f094c3e6c9ef40349f7d38b5d27d7",
          "author" => %{
            "name" => "GitLab dev user",
            "email" => "gitlabdev@dv6700.(none)"
          },
          "added" => ["CHANGELOG"],
          "modified" => ["app/controller/application.rb"],
          "removed" => []
        }
      ],
      "total_commits_count" => 4
    }
  end

  def push_delete_branch do
    %{
      "object_kind" => "push",
      "event_name" => "push",
      "before" => "b6568db1bc1dcd7f8b4d5a946b0b91f9dacd7327",
      # Defines a deleted branch
      "after" => "0000000000000000000000000000000000000000",
      "ref" => "refs/heads/master",
      "ref_protected" => true,
      # Defines a deleted branch
      "checkout_sha" => nil,
      "user_id" => 4,
      "user_name" => "John Smith",
      "user_username" => "jsmith",
      "user_email" => "john@example.com",
      "user_avatar" =>
        "https://s.gravatar.com/avatar/d4c74594d841139328695756648b6bd6?s=8://s.gravatar.com/avatar/d4c74594d841139328695756648b6bd6?s=80",
      "project_id" => 15,
      "project" => %{
        "id" => 15,
        "name" => "Diaspora",
        "description" => "",
        "web_url" => "http://example.com/mike/diaspora",
        "avatar_url" => nil,
        "git_ssh_url" => "git@example.com:mike/diaspora.git",
        "git_http_url" => "http://example.com/mike/diaspora.git",
        "namespace" => "Mike",
        "visibility_level" => 0,
        "path_with_namespace" => "mike/diaspora",
        "default_branch" => "master",
        "homepage" => "http://example.com/mike/diaspora",
        "url" => "git@example.com:mike/diaspora.git",
        "ssh_url" => "git@example.com:mike/diaspora.git",
        "http_url" => "http://example.com/mike/diaspora.git"
      },
      "repository" => %{
        "name" => "Diaspora",
        "url" => "git@example.com:mike/diaspora.git",
        "description" => "",
        "homepage" => "http://example.com/mike/diaspora",
        "git_http_url" => "http://example.com/mike/diaspora.git",
        "git_ssh_url" => "git@example.com:mike/diaspora.git",
        "visibility_level" => 0
      },
      "commits" => [
        %{
          "id" => "b6568db1bc1dcd7f8b4d5a946b0b91f9dacd7327",
          "message" =>
            "Update Catalan translation to e38cb41.\n\nSee https://gitlab.com/gitlab-org/gitlab for more information",
          "title" => "Update Catalan translation to e38cb41.",
          "timestamp" => "2011-12-12T14:27:31+02:00",
          "url" => "http://example.com/mike/diaspora/commit/b6568db1bc1dcd7f8b4d5a946b0b91f9dacd7327",
          "author" => %{
            "name" => "Jordi Mallach",
            "email" => "jordi@softcatala.org"
          },
          "added" => ["CHANGELOG"],
          "modified" => ["app/controller/application.rb"],
          "removed" => []
        }
      ],
      "total_commits_count" => 4
    }
  end

  def tag_push do
    %{
      "object_kind" => "tag_push",
      "event_name" => "tag_push",
      "before" => "0000000000000000000000000000000000000000",
      "after" => "82b3d5ae55f7080f1e6022629cdb57bfae7cccc7",
      "ref" => "refs/tags/v1.0.0",
      "ref_protected" => true,
      "checkout_sha" => "82b3d5ae55f7080f1e6022629cdb57bfae7cccc7",
      "user_id" => 1,
      "user_name" => "John Smith",
      "user_avatar" =>
        "https://s.gravatar.com/avatar/d4c74594d841139328695756648b6bd6?s=8://s.gravatar.com/avatar/d4c74594d841139328695756648b6bd6?s=80",
      "project_id" => 1,
      "project" => %{
        "id" => 1,
        "name" => "Example",
        "description" => "",
        "web_url" => "http://example.com/jsmith/example",
        "avatar_url" => nil,
        "git_ssh_url" => "git@example.com:jsmith/example.git",
        "git_http_url" => "http://example.com/jsmith/example.git",
        "namespace" => "Jsmith",
        "visibility_level" => 0,
        "path_with_namespace" => "jsmith/example",
        "default_branch" => "master",
        "homepage" => "http://example.com/jsmith/example",
        "url" => "git@example.com:jsmith/example.git",
        "ssh_url" => "git@example.com:jsmith/example.git",
        "http_url" => "http://example.com/jsmith/example.git"
      },
      "repository" => %{
        "name" => "Example",
        "url" => "ssh://git@example.com/jsmith/example.git",
        "description" => "",
        "homepage" => "http://example.com/jsmith/example",
        "git_http_url" => "http://example.com/jsmith/example.git",
        "git_ssh_url" => "git@example.com:jsmith/example.git",
        "visibility_level" => 0
      },
      "commits" => [
        %{
          "id" => "82b3d5ae55f7080f1e6022629cdb57bfae7cccc7",
          "message" => "new_tag",
          "title" => "new_tag",
          "timestamp" => "2012-01-03T23:36:29+02:00",
          "url" => "http://example.com/mike/diaspora/commit/da1560886d4f094c3e6c9ef40349f7d38b5d27d7",
          "author" => %{
            "name" => "GitLab dev user",
            "email" => "gitlabdev@dv6700.(none)"
          },
          "added" => ["CHANGELOG"],
          "modified" => ["app/controller/application.rb"],
          "removed" => []
        }
      ],
      "total_commits_count" => 1
    }
  end

  def merge_request_open do
    %{
      "object_kind" => "merge_request",
      "event_type" => "merge_request",
      "user" => %{
        "id" => 1,
        "name" => "Administrator",
        "username" => "root",
        "avatar_url" => "http://www.gravatar.com/avatar/e64c7d89f26bd1972efa854d13d7dd61?s=40\u0026d=identicon",
        "email" => "admin@example.com"
      },
      "project" => %{
        "id" => 1,
        "name" => "Gitlab Test",
        "description" => "Aut reprehenderit ut est.",
        "web_url" => "http://example.com/gitlabhq/gitlab-test",
        "avatar_url" => nil,
        "git_ssh_url" => "git@example.com:gitlabhq/gitlab-test.git",
        "git_http_url" => "http://example.com/gitlabhq/gitlab-test.git",
        "namespace" => "GitlabHQ",
        "visibility_level" => 20,
        "path_with_namespace" => "gitlabhq/gitlab-test",
        "default_branch" => "master",
        "ci_config_path" => "",
        "homepage" => "http://example.com/gitlabhq/gitlab-test",
        "url" => "http://example.com/gitlabhq/gitlab-test.git",
        "ssh_url" => "git@example.com:gitlabhq/gitlab-test.git",
        "http_url" => "http://example.com/gitlabhq/gitlab-test.git"
      },
      "repository" => %{
        "name" => "Gitlab Test",
        "url" => "http://example.com/gitlabhq/gitlab-test.git",
        "description" => "Aut reprehenderit ut est.",
        "homepage" => "http://example.com/gitlabhq/gitlab-test"
      },
      "object_attributes" => %{
        "id" => 99,
        "iid" => 1,
        "target_branch" => "master",
        "source_branch" => "ms-viewport",
        "source_project_id" => 14,
        "author_id" => 51,
        "assignee_ids" => [6],
        "assignee_id" => 6,
        "reviewer_ids" => [6],
        "title" => "MS-Viewport",
        "created_at" => "2013-12-03T17:23:34Z",
        "updated_at" => "2013-12-03T17:23:34Z",
        "last_edited_at" => "2013-12-03T17:23:34Z",
        "last_edited_by_id" => 1,
        "milestone_id" => nil,
        "state_id" => 1,
        "state" => "opened",
        "blocking_discussions_resolved" => true,
        "work_in_progress" => false,
        "draft" => false,
        "first_contribution" => true,
        "merge_status" => "unchecked",
        "target_project_id" => 14,
        "description" => "",
        "prepared_at" => "2013-12-03T19:23:34Z",
        "total_time_spent" => 1800,
        "time_change" => 30,
        "human_total_time_spent" => "30m",
        "human_time_change" => "30s",
        "human_time_estimate" => "30m",
        "url" => "http://example.com/diaspora/merge_requests/1",
        "source" => %{
          "name" => "Awesome Project",
          "description" => "Aut reprehenderit ut est.",
          "web_url" => "http://example.com/awesome_space/awesome_project",
          "avatar_url" => nil,
          "git_ssh_url" => "git@example.com:awesome_space/awesome_project.git",
          "git_http_url" => "http://example.com/awesome_space/awesome_project.git",
          "namespace" => "Awesome Space",
          "visibility_level" => 20,
          "path_with_namespace" => "awesome_space/awesome_project",
          "default_branch" => "master",
          "homepage" => "http://example.com/awesome_space/awesome_project",
          "url" => "http://example.com/awesome_space/awesome_project.git",
          "ssh_url" => "git@example.com:awesome_space/awesome_project.git",
          "http_url" => "http://example.com/awesome_space/awesome_project.git"
        },
        "target" => %{
          "name" => "Awesome Project",
          "description" => "Aut reprehenderit ut est.",
          "web_url" => "http://example.com/awesome_space/awesome_project",
          "avatar_url" => nil,
          "git_ssh_url" => "git@example.com:awesome_space/awesome_project.git",
          "git_http_url" => "http://example.com/awesome_space/awesome_project.git",
          "namespace" => "Awesome Space",
          "visibility_level" => 20,
          "path_with_namespace" => "awesome_space/awesome_project",
          "default_branch" => "master",
          "homepage" => "http://example.com/awesome_space/awesome_project",
          "url" => "http://example.com/awesome_space/awesome_project.git",
          "ssh_url" => "git@example.com:awesome_space/awesome_project.git",
          "http_url" => "http://example.com/awesome_space/awesome_project.git"
        },
        "last_commit" => %{
          "id" => "da1560886d4f094c3e6c9ef40349f7d38b5d27d7",
          "message" => "fixed readme",
          "title" => "Update file README.md",
          "timestamp" => "2012-01-03T23:36:29+02:00",
          "url" => "http://example.com/awesome_space/awesome_project/commits/da1560886d4f094c3e6c9ef40349f7d38b5d27d7",
          "author" => %{
            "name" => "GitLab dev user",
            "email" => "gitlabdev@dv6700.(none)"
          }
        },
        "labels" => [
          %{
            "id" => 206,
            "title" => "API",
            "color" => "#ffffff",
            "project_id" => 14,
            "created_at" => "2013-12-03T17:15:43Z",
            "updated_at" => "2013-12-03T17:15:43Z",
            "template" => false,
            "description" => "API related issues",
            "type" => "ProjectLabel",
            "group_id" => 41
          }
        ],
        "action" => "open",
        "detailed_merge_status" => "mergeable"
      },
      "labels" => [
        %{
          "id" => 206,
          "title" => "API",
          "color" => "#ffffff",
          "project_id" => 14,
          "created_at" => "2013-12-03T17:15:43Z",
          "updated_at" => "2013-12-03T17:15:43Z",
          "template" => false,
          "description" => "API related issues",
          "type" => "ProjectLabel",
          "group_id" => 41
        }
      ],
      "changes" => %{
        "updated_by_id" => %{
          "previous" => nil,
          "current" => 1
        },
        "draft" => %{
          "previous" => true,
          "current" => false
        },
        "updated_at" => %{
          "previous" => "2017-09-15 16:50:55 UTC",
          "current" => "2017-09-15 16:52:00 UTC"
        },
        "labels" => %{
          "previous" => [
            %{
              "id" => 206,
              "title" => "API",
              "color" => "#ffffff",
              "project_id" => 14,
              "created_at" => "2013-12-03T17:15:43Z",
              "updated_at" => "2013-12-03T17:15:43Z",
              "template" => false,
              "description" => "API related issues",
              "type" => "ProjectLabel",
              "group_id" => 41
            }
          ],
          "current" => [
            %{
              "id" => 205,
              "title" => "Platform",
              "color" => "#123123",
              "project_id" => 14,
              "created_at" => "2013-12-03T17:15:43Z",
              "updated_at" => "2013-12-03T17:15:43Z",
              "template" => false,
              "description" => "Platform related issues",
              "type" => "ProjectLabel",
              "group_id" => 41
            }
          ]
        },
        "last_edited_at" => %{
          "previous" => nil,
          "current" => "2023-03-15 00:00:10 UTC"
        },
        "last_edited_by_id" => %{
          "previous" => nil,
          "current" => 3_278_533
        }
      },
      "assignees" => [
        %{
          "id" => 6,
          "name" => "User1",
          "username" => "user1",
          "avatar_url" => "http://www.gravatar.com/avatar/e64c7d89f26bd1972efa854d13d7dd61?s=40\u0026d=identicon"
        }
      ],
      "reviewers" => [
        %{
          "id" => 6,
          "name" => "User1",
          "username" => "user1",
          "avatar_url" => "http://www.gravatar.com/avatar/e64c7d89f26bd1972efa854d13d7dd61?s=40\u0026d=identicon"
        }
      ]
    }
  end

  def merge_request_closed do
    %{
      "object_kind" => "merge_request",
      "event_type" => "merge_request",
      "user" => %{
        "id" => 1,
        "name" => "Administrator",
        "username" => "root",
        "avatar_url" => "http://www.gravatar.com/avatar/e64c7d89f26bd1972efa854d13d7dd61?s=40\u0026d=identicon",
        "email" => "admin@example.com"
      },
      "project" => %{
        "id" => 1,
        "name" => "Gitlab Test",
        "description" => "Aut reprehenderit ut est.",
        "web_url" => "http://example.com/gitlabhq/gitlab-test",
        "avatar_url" => nil,
        "git_ssh_url" => "git@example.com:gitlabhq/gitlab-test.git",
        "git_http_url" => "http://example.com/gitlabhq/gitlab-test.git",
        "namespace" => "GitlabHQ",
        "visibility_level" => 20,
        "path_with_namespace" => "gitlabhq/gitlab-test",
        "default_branch" => "master",
        "ci_config_path" => "",
        "homepage" => "http://example.com/gitlabhq/gitlab-test",
        "url" => "http://example.com/gitlabhq/gitlab-test.git",
        "ssh_url" => "git@example.com:gitlabhq/gitlab-test.git",
        "http_url" => "http://example.com/gitlabhq/gitlab-test.git"
      },
      "repository" => %{
        "name" => "Gitlab Test",
        "url" => "http://example.com/gitlabhq/gitlab-test.git",
        "description" => "Aut reprehenderit ut est.",
        "homepage" => "http://example.com/gitlabhq/gitlab-test"
      },
      "object_attributes" => %{
        "id" => 99,
        "iid" => 1,
        "target_branch" => "master",
        "source_branch" => "ms-viewport",
        "source_project_id" => 14,
        "author_id" => 51,
        "assignee_ids" => [6],
        "assignee_id" => 6,
        "reviewer_ids" => [6],
        "title" => "MS-Viewport",
        "created_at" => "2013-12-03T17:23:34Z",
        "updated_at" => "2013-12-03T17:23:34Z",
        "last_edited_at" => "2013-12-03T17:23:34Z",
        "last_edited_by_id" => 1,
        "milestone_id" => nil,
        "state_id" => 1,
        "state" => "closed",
        "blocking_discussions_resolved" => true,
        "work_in_progress" => false,
        "draft" => false,
        "first_contribution" => true,
        "merge_status" => "unchecked",
        "target_project_id" => 14,
        "description" => "",
        "prepared_at" => "2013-12-03T19:23:34Z",
        "total_time_spent" => 1800,
        "time_change" => 30,
        "human_total_time_spent" => "30m",
        "human_time_change" => "30s",
        "human_time_estimate" => "30m",
        "url" => "http://example.com/diaspora/merge_requests/1",
        "source" => %{
          "name" => "Awesome Project",
          "description" => "Aut reprehenderit ut est.",
          "web_url" => "http://example.com/awesome_space/awesome_project",
          "avatar_url" => nil,
          "git_ssh_url" => "git@example.com:awesome_space/awesome_project.git",
          "git_http_url" => "http://example.com/awesome_space/awesome_project.git",
          "namespace" => "Awesome Space",
          "visibility_level" => 20,
          "path_with_namespace" => "awesome_space/awesome_project",
          "default_branch" => "master",
          "homepage" => "http://example.com/awesome_space/awesome_project",
          "url" => "http://example.com/awesome_space/awesome_project.git",
          "ssh_url" => "git@example.com:awesome_space/awesome_project.git",
          "http_url" => "http://example.com/awesome_space/awesome_project.git"
        },
        "target" => %{
          "name" => "Awesome Project",
          "description" => "Aut reprehenderit ut est.",
          "web_url" => "http://example.com/awesome_space/awesome_project",
          "avatar_url" => nil,
          "git_ssh_url" => "git@example.com:awesome_space/awesome_project.git",
          "git_http_url" => "http://example.com/awesome_space/awesome_project.git",
          "namespace" => "Awesome Space",
          "visibility_level" => 20,
          "path_with_namespace" => "awesome_space/awesome_project",
          "default_branch" => "master",
          "homepage" => "http://example.com/awesome_space/awesome_project",
          "url" => "http://example.com/awesome_space/awesome_project.git",
          "ssh_url" => "git@example.com:awesome_space/awesome_project.git",
          "http_url" => "http://example.com/awesome_space/awesome_project.git"
        },
        "last_commit" => %{
          "id" => "da1560886d4f094c3e6c9ef40349f7d38b5d27d7",
          "message" => "fixed readme",
          "title" => "Update file README.md",
          "timestamp" => "2012-01-03T23:36:29+02:00",
          "url" => "http://example.com/awesome_space/awesome_project/commits/da1560886d4f094c3e6c9ef40349f7d38b5d27d7",
          "author" => %{
            "name" => "GitLab dev user",
            "email" => "gitlabdev@dv6700.(none)"
          }
        },
        "labels" => [
          %{
            "id" => 206,
            "title" => "API",
            "color" => "#ffffff",
            "project_id" => 14,
            "created_at" => "2013-12-03T17:15:43Z",
            "updated_at" => "2013-12-03T17:15:43Z",
            "template" => false,
            "description" => "API related issues",
            "type" => "ProjectLabel",
            "group_id" => 41
          }
        ],
        "action" => "close",
        "detailed_merge_status" => "mergeable"
      },
      "labels" => [
        %{
          "id" => 206,
          "title" => "API",
          "color" => "#ffffff",
          "project_id" => 14,
          "created_at" => "2013-12-03T17:15:43Z",
          "updated_at" => "2013-12-03T17:15:43Z",
          "template" => false,
          "description" => "API related issues",
          "type" => "ProjectLabel",
          "group_id" => 41
        }
      ],
      "changes" => %{
        "updated_by_id" => %{
          "previous" => nil,
          "current" => 1
        },
        "draft" => %{
          "previous" => true,
          "current" => false
        },
        "updated_at" => %{
          "previous" => "2017-09-15 16:50:55 UTC",
          "current" => "2017-09-15 16:52:00 UTC"
        },
        "labels" => %{
          "previous" => [
            %{
              "id" => 206,
              "title" => "API",
              "color" => "#ffffff",
              "project_id" => 14,
              "created_at" => "2013-12-03T17:15:43Z",
              "updated_at" => "2013-12-03T17:15:43Z",
              "template" => false,
              "description" => "API related issues",
              "type" => "ProjectLabel",
              "group_id" => 41
            }
          ],
          "current" => [
            %{
              "id" => 205,
              "title" => "Platform",
              "color" => "#123123",
              "project_id" => 14,
              "created_at" => "2013-12-03T17:15:43Z",
              "updated_at" => "2013-12-03T17:15:43Z",
              "template" => false,
              "description" => "Platform related issues",
              "type" => "ProjectLabel",
              "group_id" => 41
            }
          ]
        },
        "last_edited_at" => %{
          "previous" => nil,
          "current" => "2023-03-15 00:00:10 UTC"
        },
        "last_edited_by_id" => %{
          "previous" => nil,
          "current" => 3_278_533
        }
      },
      "assignees" => [
        %{
          "id" => 6,
          "name" => "User1",
          "username" => "user1",
          "avatar_url" => "http://www.gravatar.com/avatar/e64c7d89f26bd1972efa854d13d7dd61?s=40\u0026d=identicon"
        }
      ],
      "reviewers" => [
        %{
          "id" => 6,
          "name" => "User1",
          "username" => "user1",
          "avatar_url" => "http://www.gravatar.com/avatar/e64c7d89f26bd1972efa854d13d7dd61?s=40\u0026d=identicon"
        }
      ]
    }
  end

  def push_skip_ci do
    push_commit()
    |> update_skip_ci_message()
  end

  def tag_push_skip_ci do
    tag_push()
    |> update_skip_ci_message()
  end

  defp update_skip_ci_message(payload_data) do
    last_commit_hash = Map.get(payload_data, "after")
    commits = Map.get(payload_data, "commits")

    last_commit_index =
      Map.get(payload_data, "commits")
      |> Enum.find_index(&(&1["id"] == last_commit_hash))

    last_commit = Enum.at(commits, last_commit_index)

    updated_commit =
      last_commit
      |> Map.put("message", "Skipping... [skip ci]\n")

    new_commits = List.replace_at(commits, last_commit_index, updated_commit)

    payload_data
    |> Map.put("commits", new_commits)
  end
end
