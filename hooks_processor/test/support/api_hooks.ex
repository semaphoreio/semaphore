defmodule Support.ApiHooks do
  @moduledoc """
  Module serves to collect various hooks examples used for testing the hook parsing
  functions.
  The following are the available functions with example hooks:

  - tag
  - branch
  """

  def tag do
    %{
      "commit" => %{
        "sha" => "023becf74ae8a5d93911db4bad7967f94343b44b",
        "message" => "Initial commit",
        "author_name" => "radwo",
        "author_avatar_url" => "URL"
      },
      "pusher" => %{
        "name" => "Radek",
        "emial" => "radek@example.com"
      },
      "repository" => %{
        "html_url" => "HTML",
        "full_name" => "semaphoreio/semaphore",
        "owner" => "renderedtext",
        "name" => "alles"
      },
      "reference" => "refs/tags/v1.0.1"
    }
  end

  def branch do
    %{
      "commit" => %{
        "sha" => "023becf74ae8a5d93911db4bad7967f94343b44b",
        "message" => "Initial commit",
        "author_name" => "radwo",
        "author_avatar_url" => "URL"
      },
      "pusher" => %{
        "name" => "Radek",
        "emial" => "radek@example.com"
      },
      "repository" => %{
        "html_url" => "HTML",
        "full_name" => "semaphoreio/semaphore",
        "owner" => "renderedtext",
        "name" => "alles"
      },
      "reference" => "refs/heads/master"
    }
  end
end
