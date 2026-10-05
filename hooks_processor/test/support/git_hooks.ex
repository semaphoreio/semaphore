defmodule Support.GitHooks do
  @moduledoc """
  Module serves to collect various hooks examples used for testing the hook parsing
  functions.
  The following are the available functions with example hooks:

  - tag
  - branch
  - skip_branch
  - deleted_branch
  - unsupported_hook_type
  """

  # What the post-receive hook sends when a branch is deleted: git's new revision
  # is all zeros and `git log` has nothing to say about it.
  def deleted_branch do
    %{
      "reference" => "refs/heads/master",
      "commit" => %{
        "sha" => "0000000000000000000000000000000000000000",
        "message" => ""
      },
      "author" => %{
        "name" => "",
        "email" => ""
      }
    }
  end

  def tag do
    %{
      "reference" => "refs/tags/v1.0.1",
      "commit" => %{
        "sha" => "023becf74ae8a5d93911db4bad7967f94343b44b",
        "message" => "Initial commit"
      },
      "author" => %{
        "name" => "Radek",
        "email" => "radek@example.com"
      }
    }
  end

  def branch do
    %{
      "reference" => "refs/heads/master",
      "commit" => %{
        "sha" => "023becf74ae8a5d93911db4bad7967f94343b44b",
        "message" => "Initial commit"
      },
      "author" => %{
        "name" => "Radek",
        "email" => "radek@example.com"
      }
    }
  end

  def skip_branch do
    %{
      "reference" => "refs/heads/master",
      "commit" => %{
        "sha" => "023becf74ae8a5d93911db4bad7967f94343b44b",
        "message" => "[skip ci] Initial commit"
      },
      "author" => %{
        "name" => "Radek",
        "email" => "radek@example.com"
      }
    }
  end

  def unsupported_hook_type do
    %{
      "reference" => "refs/puls/123",
      "commit" => %{
        "sha" => "023becf74ae8a5d93911db4bad7967f94343b44b",
        "message" => "Initial commit"
      },
      "author" => %{
        "name" => "Radek",
        "email" => "radek@example.com"
      }
    }
  end
end
