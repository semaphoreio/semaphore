# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
defmodule Support.BitbucketHooks do
  @moduledoc """
  Module serves to collect various hooks examples used for testing the hook parsing
  functions.
  The following are the available functions with example hooks:

  - push_new_branch_with_commits
  - push_new_branch_no_commits
  - push_commit
  - push_commit_force
  - branch_deletion
  - tag_deletion
  - push_annoted_tag
  - push_lightweight_tag
  - pull_request_open
  - pull_request_closed
  - push_to_a_branch_with_pr
  - branch_push_skip_ci
  - tag_push_skip_ci
  """

  def push_new_branch_with_commits do
    %{
      "actor" => %{
        "account_id" => "557058:a19b3000-9205-4825-983a-e223af783fd9",
        "display_name" => "Milana Stojadinov",
        "links" => %{
          "avatar" => %{
            "href" =>
              "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
          },
          "html" => %{
            "href" => "https://bitbucket.org/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D/"
          },
          "self" => %{
            "href" => "https://api.bitbucket.org/2.0/users/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D"
          }
        },
        "nickname" => "milana_stojadinov",
        "type" => "user",
        "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
      },
      "push" => %{
        "changes" => [
          %{
            "closed" => false,
            "commits" => [
              %{
                "author" => %{
                  "raw" => "Milana Stojadinov <milana.stojadinov@gmail.com>",
                  "type" => "author",
                  "user" => %{
                    "account_id" => "557058:a19b3000-9205-4825-983a-e223af783fd9",
                    "display_name" => "Milana Stojadinov",
                    "links" => %{
                      "avatar" => %{
                        "href" =>
                          "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
                      },
                      "html" => %{
                        "href" => "https://bitbucket.org/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D/"
                      },
                      "self" => %{
                        "href" => "https://api.bitbucket.org/2.0/users/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D"
                      }
                    },
                    "nickname" => "milana_stojadinov",
                    "type" => "user",
                    "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
                  }
                },
                "date" => "2021-06-15T09:26:39+00:00",
                "hash" => "2a585bde481f0d5b3a10b10997210b6eb4893897",
                "links" => %{
                  "approve" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/2a585bde481f0d5b3a10b10997210b6eb4893897/approve"
                  },
                  "comments" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/2a585bde481f0d5b3a10b10997210b6eb4893897/comments"
                  },
                  "diff" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/diff/2a585bde481f0d5b3a10b10997210b6eb4893897"
                  },
                  "html" => %{
                    "href" =>
                      "https://bitbucket.org/milana_stojadinov/elixir-project/commits/2a585bde481f0d5b3a10b10997210b6eb4893897"
                  },
                  "patch" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/patch/2a585bde481f0d5b3a10b10997210b6eb4893897"
                  },
                  "self" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/2a585bde481f0d5b3a10b10997210b6eb4893897"
                  },
                  "statuses" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/2a585bde481f0d5b3a10b10997210b6eb4893897/statuses"
                  }
                },
                "message" => "Update readme\n",
                "parents" => [
                  %{
                    "hash" => "c699bacf22afa6f423ec4bc09da26a127559bc9a",
                    "links" => %{
                      "html" => %{
                        "href" =>
                          "https://bitbucket.org/milana_stojadinov/elixir-project/commits/c699bacf22afa6f423ec4bc09da26a127559bc9a"
                      },
                      "self" => %{
                        "href" =>
                          "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/c699bacf22afa6f423ec4bc09da26a127559bc9a"
                      }
                    },
                    "type" => "commit"
                  }
                ],
                "properties" => %{},
                "rendered" => %{},
                "summary" => %{
                  "html" => "<p>Update readme</p>",
                  "markup" => "markdown",
                  "raw" => "Update readme\n",
                  "type" => "rendered"
                },
                "type" => "commit"
              },
              %{
                "author" => %{
                  "raw" => "Milana Stojadinov <mstojadinov@renderedtext.com>",
                  "type" => "author"
                },
                "date" => "2016-09-13T15:17:21+00:00",
                "hash" => "c699bacf22afa6f423ec4bc09da26a127559bc9a",
                "links" => %{
                  "approve" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/c699bacf22afa6f423ec4bc09da26a127559bc9a/approve"
                  },
                  "comments" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/c699bacf22afa6f423ec4bc09da26a127559bc9a/comments"
                  },
                  "diff" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/diff/c699bacf22afa6f423ec4bc09da26a127559bc9a"
                  },
                  "html" => %{
                    "href" =>
                      "https://bitbucket.org/milana_stojadinov/elixir-project/commits/c699bacf22afa6f423ec4bc09da26a127559bc9a"
                  },
                  "patch" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/patch/c699bacf22afa6f423ec4bc09da26a127559bc9a"
                  },
                  "self" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/c699bacf22afa6f423ec4bc09da26a127559bc9a"
                  },
                  "statuses" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/c699bacf22afa6f423ec4bc09da26a127559bc9a/statuses"
                  }
                },
                "message" => "Remove build badge\n",
                "parents" => [
                  %{
                    "hash" => "89c33b336178a6c218f003c678ae96c0301b0a78",
                    "links" => %{
                      "html" => %{
                        "href" =>
                          "https://bitbucket.org/milana_stojadinov/elixir-project/commits/89c33b336178a6c218f003c678ae96c0301b0a78"
                      },
                      "self" => %{
                        "href" =>
                          "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/89c33b336178a6c218f003c678ae96c0301b0a78"
                      }
                    },
                    "type" => "commit"
                  }
                ],
                "properties" => %{},
                "rendered" => %{},
                "summary" => %{
                  "html" => "<p>Remove build badge</p>",
                  "markup" => "markdown",
                  "raw" => "Remove build badge\n",
                  "type" => "rendered"
                },
                "type" => "commit"
              },
              %{
                "author" => %{
                  "raw" => "adequateDeveloper <adequate.developer@gmail.com>",
                  "type" => "author"
                },
                "date" => "2016-09-13T14:27:02+00:00",
                "hash" => "89c33b336178a6c218f003c678ae96c0301b0a78",
                "links" => %{
                  "approve" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/89c33b336178a6c218f003c678ae96c0301b0a78/approve"
                  },
                  "comments" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/89c33b336178a6c218f003c678ae96c0301b0a78/comments"
                  },
                  "diff" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/diff/89c33b336178a6c218f003c678ae96c0301b0a78"
                  },
                  "html" => %{
                    "href" =>
                      "https://bitbucket.org/milana_stojadinov/elixir-project/commits/89c33b336178a6c218f003c678ae96c0301b0a78"
                  },
                  "patch" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/patch/89c33b336178a6c218f003c678ae96c0301b0a78"
                  },
                  "self" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/89c33b336178a6c218f003c678ae96c0301b0a78"
                  },
                  "statuses" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/89c33b336178a6c218f003c678ae96c0301b0a78/statuses"
                  }
                },
                "message" => "Updated alias statements\n",
                "parents" => [
                  %{
                    "hash" => "f4866285864a6c28e21c270586f9f0651ed28a3f",
                    "links" => %{
                      "html" => %{
                        "href" =>
                          "https://bitbucket.org/milana_stojadinov/elixir-project/commits/f4866285864a6c28e21c270586f9f0651ed28a3f"
                      },
                      "self" => %{
                        "href" =>
                          "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/f4866285864a6c28e21c270586f9f0651ed28a3f"
                      }
                    },
                    "type" => "commit"
                  }
                ],
                "properties" => %{},
                "rendered" => %{},
                "summary" => %{
                  "html" => "<p>Updated alias statements</p>",
                  "markup" => "markdown",
                  "raw" => "Updated alias statements\n",
                  "type" => "rendered"
                },
                "type" => "commit"
              },
              %{
                "author" => %{
                  "raw" => "Dan McHarness <adequate.developer@gmail.com>",
                  "type" => "author"
                },
                "date" => "2016-09-10T16:48:58+00:00",
                "hash" => "f4866285864a6c28e21c270586f9f0651ed28a3f",
                "links" => %{
                  "approve" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/f4866285864a6c28e21c270586f9f0651ed28a3f/approve"
                  },
                  "comments" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/f4866285864a6c28e21c270586f9f0651ed28a3f/comments"
                  },
                  "diff" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/diff/f4866285864a6c28e21c270586f9f0651ed28a3f"
                  },
                  "html" => %{
                    "href" =>
                      "https://bitbucket.org/milana_stojadinov/elixir-project/commits/f4866285864a6c28e21c270586f9f0651ed28a3f"
                  },
                  "patch" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/patch/f4866285864a6c28e21c270586f9f0651ed28a3f"
                  },
                  "self" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/f4866285864a6c28e21c270586f9f0651ed28a3f"
                  },
                  "statuses" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/f4866285864a6c28e21c270586f9f0651ed28a3f/statuses"
                  }
                },
                "message" => "Mods to test and Semaphore CI config notes\n",
                "parents" => [
                  %{
                    "hash" => "b241d65dd90a6bb90612c0bb33b35393e37e2027",
                    "links" => %{
                      "html" => %{
                        "href" =>
                          "https://bitbucket.org/milana_stojadinov/elixir-project/commits/b241d65dd90a6bb90612c0bb33b35393e37e2027"
                      },
                      "self" => %{
                        "href" =>
                          "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/b241d65dd90a6bb90612c0bb33b35393e37e2027"
                      }
                    },
                    "type" => "commit"
                  }
                ],
                "properties" => %{},
                "rendered" => %{},
                "summary" => %{
                  "html" => "<p>Mods to test and Semaphore CI config notes</p>",
                  "markup" => "markdown",
                  "raw" => "Mods to test and Semaphore CI config notes\n",
                  "type" => "rendered"
                },
                "type" => "commit"
              },
              %{
                "author" => %{
                  "raw" => "Dan McHarness <adequate.developer@gmail.com>",
                  "type" => "author"
                },
                "date" => "2016-09-10T15:53:33+00:00",
                "hash" => "b241d65dd90a6bb90612c0bb33b35393e37e2027",
                "links" => %{
                  "approve" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/b241d65dd90a6bb90612c0bb33b35393e37e2027/approve"
                  },
                  "comments" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/b241d65dd90a6bb90612c0bb33b35393e37e2027/comments"
                  },
                  "diff" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/diff/b241d65dd90a6bb90612c0bb33b35393e37e2027"
                  },
                  "html" => %{
                    "href" =>
                      "https://bitbucket.org/milana_stojadinov/elixir-project/commits/b241d65dd90a6bb90612c0bb33b35393e37e2027"
                  },
                  "patch" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/patch/b241d65dd90a6bb90612c0bb33b35393e37e2027"
                  },
                  "self" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/b241d65dd90a6bb90612c0bb33b35393e37e2027"
                  },
                  "statuses" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/b241d65dd90a6bb90612c0bb33b35393e37e2027/statuses"
                  }
                },
                "message" => "More notes\n",
                "parents" => [
                  %{
                    "hash" => "15edd44b4cbf5d119c6158e99b7c4191ec3f2b60",
                    "links" => %{
                      "html" => %{
                        "href" =>
                          "https://bitbucket.org/milana_stojadinov/elixir-project/commits/15edd44b4cbf5d119c6158e99b7c4191ec3f2b60"
                      },
                      "self" => %{
                        "href" =>
                          "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/15edd44b4cbf5d119c6158e99b7c4191ec3f2b60"
                      }
                    },
                    "type" => "commit"
                  }
                ],
                "properties" => %{},
                "rendered" => %{},
                "summary" => %{
                  "html" => "<p>More notes</p>",
                  "markup" => "markdown",
                  "raw" => "More notes\n",
                  "type" => "rendered"
                },
                "type" => "commit"
              }
            ],
            "created" => true,
            "forced" => false,
            "links" => %{
              "commits" => %{
                "href" =>
                  "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commits?include=2a585bde481f0d5b3a10b10997210b6eb4893897"
              },
              "html" => %{
                "href" => "https://bitbucket.org/milana_stojadinov/elixir-project/branch/new-branch-push-new-commits"
              }
            },
            "new" => %{
              "default_merge_strategy" => "merge_commit",
              "links" => %{
                "commits" => %{
                  "href" =>
                    "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commits/new-branch-push-new-commits"
                },
                "html" => %{
                  "href" => "https://bitbucket.org/milana_stojadinov/elixir-project/branch/new-branch-push-new-commits"
                },
                "self" => %{
                  "href" =>
                    "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/refs/branches/new-branch-push-new-commits"
                }
              },
              "merge_strategies" => ["merge_commit", "squash", "fast_forward"],
              "name" => "new-branch-push-new-commits",
              "target" => %{
                "author" => %{
                  "raw" => "Milana Stojadinov <milana.stojadinov@gmail.com>",
                  "type" => "author",
                  "user" => %{
                    "account_id" => "557058:a19b3000-9205-4825-983a-e223af783fd9",
                    "display_name" => "Milana Stojadinov",
                    "links" => %{
                      "avatar" => %{
                        "href" =>
                          "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
                      },
                      "html" => %{
                        "href" => "https://bitbucket.org/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D/"
                      },
                      "self" => %{
                        "href" => "https://api.bitbucket.org/2.0/users/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D"
                      }
                    },
                    "nickname" => "milana_stojadinov",
                    "type" => "user",
                    "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
                  }
                },
                "date" => "2021-06-15T09:26:39+00:00",
                "hash" => "2a585bde481f0d5b3a10b10997210b6eb4893897",
                "links" => %{
                  "html" => %{
                    "href" =>
                      "https://bitbucket.org/milana_stojadinov/elixir-project/commits/2a585bde481f0d5b3a10b10997210b6eb4893897"
                  },
                  "self" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/2a585bde481f0d5b3a10b10997210b6eb4893897"
                  }
                },
                "message" => "Update readme\n",
                "parents" => [
                  %{
                    "hash" => "c699bacf22afa6f423ec4bc09da26a127559bc9a",
                    "links" => %{
                      "html" => %{
                        "href" =>
                          "https://bitbucket.org/milana_stojadinov/elixir-project/commits/c699bacf22afa6f423ec4bc09da26a127559bc9a"
                      },
                      "self" => %{
                        "href" =>
                          "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/c699bacf22afa6f423ec4bc09da26a127559bc9a"
                      }
                    },
                    "type" => "commit"
                  }
                ],
                "properties" => %{},
                "rendered" => %{},
                "summary" => %{
                  "html" => "<p>Update readme</p>",
                  "markup" => "markdown",
                  "raw" => "Update readme\n",
                  "type" => "rendered"
                },
                "type" => "commit"
              },
              "type" => "branch"
            },
            "old" => nil,
            "truncated" => true
          }
        ]
      },
      "repository" => %{
        "full_name" => "milana_stojadinov/elixir-project",
        "is_private" => true,
        "links" => %{
          "avatar" => %{
            "href" => "https://bytebucket.org/ravatar/%7B730ede8d-c0de-4f85-aef1-133881a9624f%7D?ts=default"
          },
          "html" => %{"href" => "https://bitbucket.org/milana_stojadinov/elixir-project"},
          "self" => %{
            "href" => "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project"
          }
        },
        "name" => "elixir-project",
        "owner" => %{
          "account_id" => "557058:a19b3000-9205-4825-983a-e223af783fd9",
          "display_name" => "Milana Stojadinov",
          "links" => %{
            "avatar" => %{
              "href" =>
                "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
            },
            "html" => %{
              "href" => "https://bitbucket.org/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D/"
            },
            "self" => %{
              "href" => "https://api.bitbucket.org/2.0/users/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D"
            }
          },
          "nickname" => "milana_stojadinov",
          "type" => "user",
          "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
        },
        "project" => %{
          "key" => "WEB",
          "links" => %{
            "avatar" => %{
              "href" => "https://bitbucket.org/account/user/milana_stojadinov/projects/WEB/avatar/32?ts=1623417282"
            },
            "html" => %{
              "href" => "https://bitbucket.org/milana_stojadinov/workspace/projects/WEB"
            },
            "self" => %{
              "href" => "https://api.bitbucket.org/2.0/workspaces/milana_stojadinov/projects/WEB"
            }
          },
          "name" => "webhooks-test",
          "type" => "project",
          "uuid" => "{1e6187d8-23a6-47fe-9a3d-328fbf61f572}"
        },
        "scm" => "git",
        "type" => "repository",
        "uuid" => "{730ede8d-c0de-4f85-aef1-133881a9624f}",
        "website" => "",
        "workspace" => %{
          "links" => %{
            "avatar" => %{
              "href" => "https://bitbucket.org/workspaces/milana_stojadinov/avatar/?ts=1543639881"
            },
            "html" => %{"href" => "https://bitbucket.org/milana_stojadinov/"},
            "self" => %{"href" => "https://api.bitbucket.org/2.0/workspaces/milana_stojadinov"}
          },
          "name" => "Milana Stojadinov",
          "slug" => "milana_stojadinov",
          "type" => "workspace",
          "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
        }
      }
    }
  end

  def push_new_branch_no_commits do
    %{
      "actor" => %{
        "account_id" => "557058:a19b3000-9205-4825-983a-e223af783fd9",
        "display_name" => "Milana Stojadinov",
        "links" => %{
          "avatar" => %{
            "href" =>
              "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
          },
          "html" => %{
            "href" => "https://bitbucket.org/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D/"
          },
          "self" => %{
            "href" => "https://api.bitbucket.org/2.0/users/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D"
          }
        },
        "nickname" => "milana_stojadinov",
        "type" => "user",
        "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
      },
      "push" => %{
        "changes" => [
          %{
            "closed" => false,
            "commits" => [
              %{
                "author" => %{
                  "raw" => "Milana Stojadinov <mstojadinov@renderedtext.com>",
                  "type" => "author"
                },
                "date" => "2016-09-13T15:17:21+00:00",
                "hash" => "c699bacf22afa6f423ec4bc09da26a127559bc9a",
                "links" => %{
                  "approve" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/c699bacf22afa6f423ec4bc09da26a127559bc9a/approve"
                  },
                  "comments" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/c699bacf22afa6f423ec4bc09da26a127559bc9a/comments"
                  },
                  "diff" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/diff/c699bacf22afa6f423ec4bc09da26a127559bc9a"
                  },
                  "html" => %{
                    "href" =>
                      "https://bitbucket.org/milana_stojadinov/elixir-project/commits/c699bacf22afa6f423ec4bc09da26a127559bc9a"
                  },
                  "patch" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/patch/c699bacf22afa6f423ec4bc09da26a127559bc9a"
                  },
                  "self" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/c699bacf22afa6f423ec4bc09da26a127559bc9a"
                  },
                  "statuses" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/c699bacf22afa6f423ec4bc09da26a127559bc9a/statuses"
                  }
                },
                "message" => "Remove build badge\n",
                "parents" => [
                  %{
                    "hash" => "89c33b336178a6c218f003c678ae96c0301b0a78",
                    "links" => %{
                      "html" => %{
                        "href" =>
                          "https://bitbucket.org/milana_stojadinov/elixir-project/commits/89c33b336178a6c218f003c678ae96c0301b0a78"
                      },
                      "self" => %{
                        "href" =>
                          "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/89c33b336178a6c218f003c678ae96c0301b0a78"
                      }
                    },
                    "type" => "commit"
                  }
                ],
                "properties" => %{},
                "rendered" => %{},
                "summary" => %{
                  "html" => "<p>Remove build badge</p>",
                  "markup" => "markdown",
                  "raw" => "Remove build badge\n",
                  "type" => "rendered"
                },
                "type" => "commit"
              },
              %{
                "author" => %{
                  "raw" => "adequateDeveloper <adequate.developer@gmail.com>",
                  "type" => "author"
                },
                "date" => "2016-09-13T14:27:02+00:00",
                "hash" => "89c33b336178a6c218f003c678ae96c0301b0a78",
                "links" => %{
                  "approve" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/89c33b336178a6c218f003c678ae96c0301b0a78/approve"
                  },
                  "comments" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/89c33b336178a6c218f003c678ae96c0301b0a78/comments"
                  },
                  "diff" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/diff/89c33b336178a6c218f003c678ae96c0301b0a78"
                  },
                  "html" => %{
                    "href" =>
                      "https://bitbucket.org/milana_stojadinov/elixir-project/commits/89c33b336178a6c218f003c678ae96c0301b0a78"
                  },
                  "patch" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/patch/89c33b336178a6c218f003c678ae96c0301b0a78"
                  },
                  "self" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/89c33b336178a6c218f003c678ae96c0301b0a78"
                  },
                  "statuses" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/89c33b336178a6c218f003c678ae96c0301b0a78/statuses"
                  }
                },
                "message" => "Updated alias statements\n",
                "parents" => [
                  %{
                    "hash" => "f4866285864a6c28e21c270586f9f0651ed28a3f",
                    "links" => %{
                      "html" => %{
                        "href" =>
                          "https://bitbucket.org/milana_stojadinov/elixir-project/commits/f4866285864a6c28e21c270586f9f0651ed28a3f"
                      },
                      "self" => %{
                        "href" =>
                          "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/f4866285864a6c28e21c270586f9f0651ed28a3f"
                      }
                    },
                    "type" => "commit"
                  }
                ],
                "properties" => %{},
                "rendered" => %{},
                "summary" => %{
                  "html" => "<p>Updated alias statements</p>",
                  "markup" => "markdown",
                  "raw" => "Updated alias statements\n",
                  "type" => "rendered"
                },
                "type" => "commit"
              },
              %{
                "author" => %{
                  "raw" => "Dan McHarness <adequate.developer@gmail.com>",
                  "type" => "author"
                },
                "date" => "2016-09-10T16:48:58+00:00",
                "hash" => "f4866285864a6c28e21c270586f9f0651ed28a3f",
                "links" => %{
                  "approve" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/f4866285864a6c28e21c270586f9f0651ed28a3f/approve"
                  },
                  "comments" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/f4866285864a6c28e21c270586f9f0651ed28a3f/comments"
                  },
                  "diff" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/diff/f4866285864a6c28e21c270586f9f0651ed28a3f"
                  },
                  "html" => %{
                    "href" =>
                      "https://bitbucket.org/milana_stojadinov/elixir-project/commits/f4866285864a6c28e21c270586f9f0651ed28a3f"
                  },
                  "patch" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/patch/f4866285864a6c28e21c270586f9f0651ed28a3f"
                  },
                  "self" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/f4866285864a6c28e21c270586f9f0651ed28a3f"
                  },
                  "statuses" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/f4866285864a6c28e21c270586f9f0651ed28a3f/statuses"
                  }
                },
                "message" => "Mods to test and Semaphore CI config notes\n",
                "parents" => [
                  %{
                    "hash" => "b241d65dd90a6bb90612c0bb33b35393e37e2027",
                    "links" => %{
                      "html" => %{
                        "href" =>
                          "https://bitbucket.org/milana_stojadinov/elixir-project/commits/b241d65dd90a6bb90612c0bb33b35393e37e2027"
                      },
                      "self" => %{
                        "href" =>
                          "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/b241d65dd90a6bb90612c0bb33b35393e37e2027"
                      }
                    },
                    "type" => "commit"
                  }
                ],
                "properties" => %{},
                "rendered" => %{},
                "summary" => %{
                  "html" => "<p>Mods to test and Semaphore CI config notes</p>",
                  "markup" => "markdown",
                  "raw" => "Mods to test and Semaphore CI config notes\n",
                  "type" => "rendered"
                },
                "type" => "commit"
              },
              %{
                "author" => %{
                  "raw" => "Dan McHarness <adequate.developer@gmail.com>",
                  "type" => "author"
                },
                "date" => "2016-09-10T15:53:33+00:00",
                "hash" => "b241d65dd90a6bb90612c0bb33b35393e37e2027",
                "links" => %{
                  "approve" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/b241d65dd90a6bb90612c0bb33b35393e37e2027/approve"
                  },
                  "comments" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/b241d65dd90a6bb90612c0bb33b35393e37e2027/comments"
                  },
                  "diff" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/diff/b241d65dd90a6bb90612c0bb33b35393e37e2027"
                  },
                  "html" => %{
                    "href" =>
                      "https://bitbucket.org/milana_stojadinov/elixir-project/commits/b241d65dd90a6bb90612c0bb33b35393e37e2027"
                  },
                  "patch" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/patch/b241d65dd90a6bb90612c0bb33b35393e37e2027"
                  },
                  "self" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/b241d65dd90a6bb90612c0bb33b35393e37e2027"
                  },
                  "statuses" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/b241d65dd90a6bb90612c0bb33b35393e37e2027/statuses"
                  }
                },
                "message" => "More notes\n",
                "parents" => [
                  %{
                    "hash" => "15edd44b4cbf5d119c6158e99b7c4191ec3f2b60",
                    "links" => %{
                      "html" => %{
                        "href" =>
                          "https://bitbucket.org/milana_stojadinov/elixir-project/commits/15edd44b4cbf5d119c6158e99b7c4191ec3f2b60"
                      },
                      "self" => %{
                        "href" =>
                          "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/15edd44b4cbf5d119c6158e99b7c4191ec3f2b60"
                      }
                    },
                    "type" => "commit"
                  }
                ],
                "properties" => %{},
                "rendered" => %{},
                "summary" => %{
                  "html" => "<p>More notes</p>",
                  "markup" => "markdown",
                  "raw" => "More notes\n",
                  "type" => "rendered"
                },
                "type" => "commit"
              },
              %{
                "author" => %{
                  "raw" => "Dan McHarness <adequate.developer@gmail.com>",
                  "type" => "author"
                },
                "date" => "2016-09-10T15:52:51+00:00",
                "hash" => "15edd44b4cbf5d119c6158e99b7c4191ec3f2b60",
                "links" => %{
                  "approve" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/15edd44b4cbf5d119c6158e99b7c4191ec3f2b60/approve"
                  },
                  "comments" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/15edd44b4cbf5d119c6158e99b7c4191ec3f2b60/comments"
                  },
                  "diff" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/diff/15edd44b4cbf5d119c6158e99b7c4191ec3f2b60"
                  },
                  "html" => %{
                    "href" =>
                      "https://bitbucket.org/milana_stojadinov/elixir-project/commits/15edd44b4cbf5d119c6158e99b7c4191ec3f2b60"
                  },
                  "patch" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/patch/15edd44b4cbf5d119c6158e99b7c4191ec3f2b60"
                  },
                  "self" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/15edd44b4cbf5d119c6158e99b7c4191ec3f2b60"
                  },
                  "statuses" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/15edd44b4cbf5d119c6158e99b7c4191ec3f2b60/statuses"
                  }
                },
                "message" => "More notes\n",
                "parents" => [
                  %{
                    "hash" => "7aa054d9ae7a31dc7f853cb7e9393a2994419f09",
                    "links" => %{
                      "html" => %{
                        "href" =>
                          "https://bitbucket.org/milana_stojadinov/elixir-project/commits/7aa054d9ae7a31dc7f853cb7e9393a2994419f09"
                      },
                      "self" => %{
                        "href" =>
                          "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/7aa054d9ae7a31dc7f853cb7e9393a2994419f09"
                      }
                    },
                    "type" => "commit"
                  }
                ],
                "properties" => %{},
                "rendered" => %{},
                "summary" => %{
                  "html" => "<p>More notes</p>",
                  "markup" => "markdown",
                  "raw" => "More notes\n",
                  "type" => "rendered"
                },
                "type" => "commit"
              }
            ],
            "created" => true,
            "forced" => false,
            "links" => %{
              "commits" => %{
                "href" =>
                  "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commits?include=c699bacf22afa6f423ec4bc09da26a127559bc9a"
              },
              "html" => %{
                "href" => "https://bitbucket.org/milana_stojadinov/elixir-project/branch/new-branch-push"
              }
            },
            "new" => %{
              "default_merge_strategy" => "merge_commit",
              "links" => %{
                "commits" => %{
                  "href" =>
                    "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commits/new-branch-push"
                },
                "html" => %{
                  "href" => "https://bitbucket.org/milana_stojadinov/elixir-project/branch/new-branch-push"
                },
                "self" => %{
                  "href" =>
                    "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/refs/branches/new-branch-push"
                }
              },
              "merge_strategies" => ["merge_commit", "squash", "fast_forward"],
              "name" => "new-branch-push",
              "target" => %{
                "author" => %{
                  "raw" => "Milana Stojadinov <mstojadinov@renderedtext.com>",
                  "type" => "author"
                },
                "date" => "2016-09-13T15:17:21+00:00",
                "hash" => "c699bacf22afa6f423ec4bc09da26a127559bc9a",
                "links" => %{
                  "html" => %{
                    "href" =>
                      "https://bitbucket.org/milana_stojadinov/elixir-project/commits/c699bacf22afa6f423ec4bc09da26a127559bc9a"
                  },
                  "self" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/c699bacf22afa6f423ec4bc09da26a127559bc9a"
                  }
                },
                "message" => "Remove build badge\n",
                "parents" => [
                  %{
                    "hash" => "89c33b336178a6c218f003c678ae96c0301b0a78",
                    "links" => %{
                      "html" => %{
                        "href" =>
                          "https://bitbucket.org/milana_stojadinov/elixir-project/commits/89c33b336178a6c218f003c678ae96c0301b0a78"
                      },
                      "self" => %{
                        "href" =>
                          "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/89c33b336178a6c218f003c678ae96c0301b0a78"
                      }
                    },
                    "type" => "commit"
                  }
                ],
                "properties" => %{},
                "rendered" => %{},
                "summary" => %{
                  "html" => "<p>Remove build badge</p>",
                  "markup" => "markdown",
                  "raw" => "Remove build badge\n",
                  "type" => "rendered"
                },
                "type" => "commit"
              },
              "type" => "branch"
            },
            "old" => nil,
            "truncated" => true
          }
        ]
      },
      "repository" => %{
        "full_name" => "milana_stojadinov/elixir-project",
        "is_private" => true,
        "links" => %{
          "avatar" => %{
            "href" => "https://bytebucket.org/ravatar/%7B730ede8d-c0de-4f85-aef1-133881a9624f%7D?ts=default"
          },
          "html" => %{"href" => "https://bitbucket.org/milana_stojadinov/elixir-project"},
          "self" => %{
            "href" => "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project"
          }
        },
        "name" => "elixir-project",
        "owner" => %{
          "account_id" => "557058:a19b3000-9205-4825-983a-e223af783fd9",
          "display_name" => "Milana Stojadinov",
          "links" => %{
            "avatar" => %{
              "href" =>
                "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
            },
            "html" => %{
              "href" => "https://bitbucket.org/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D/"
            },
            "self" => %{
              "href" => "https://api.bitbucket.org/2.0/users/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D"
            }
          },
          "nickname" => "milana_stojadinov",
          "type" => "user",
          "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
        },
        "project" => %{
          "key" => "WEB",
          "links" => %{
            "avatar" => %{
              "href" => "https://bitbucket.org/account/user/milana_stojadinov/projects/WEB/avatar/32?ts=1623417282"
            },
            "html" => %{
              "href" => "https://bitbucket.org/milana_stojadinov/workspace/projects/WEB"
            },
            "self" => %{
              "href" => "https://api.bitbucket.org/2.0/workspaces/milana_stojadinov/projects/WEB"
            }
          },
          "name" => "webhooks-test",
          "type" => "project",
          "uuid" => "{1e6187d8-23a6-47fe-9a3d-328fbf61f572}"
        },
        "scm" => "git",
        "type" => "repository",
        "uuid" => "{730ede8d-c0de-4f85-aef1-133881a9624f}",
        "website" => "",
        "workspace" => %{
          "links" => %{
            "avatar" => %{
              "href" => "https://bitbucket.org/workspaces/milana_stojadinov/avatar/?ts=1543639881"
            },
            "html" => %{"href" => "https://bitbucket.org/milana_stojadinov/"},
            "self" => %{"href" => "https://api.bitbucket.org/2.0/workspaces/milana_stojadinov"}
          },
          "name" => "Milana Stojadinov",
          "slug" => "milana_stojadinov",
          "type" => "workspace",
          "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
        }
      }
    }
  end

  def push_commit do
    %{
      "actor" => %{
        "account_id" => "557058:a19b3000-9205-4825-983a-e223af783fd9",
        "display_name" => "Milana Stojadinov",
        "links" => %{
          "avatar" => %{
            "href" =>
              "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
          },
          "html" => %{
            "href" => "https://bitbucket.org/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D/"
          },
          "self" => %{
            "href" => "https://api.bitbucket.org/2.0/users/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D"
          }
        },
        "nickname" => "milana_stojadinov",
        "type" => "user",
        "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
      },
      "push" => %{
        "changes" => [
          %{
            "closed" => false,
            "commits" => [
              %{
                "author" => %{
                  "raw" => "Milana Stojadinov <milana.stojadinov@gmail.com>",
                  "type" => "author",
                  "user" => %{
                    "account_id" => "557058:a19b3000-9205-4825-983a-e223af783fd9",
                    "display_name" => "Milana Stojadinov",
                    "links" => %{
                      "avatar" => %{
                        "href" =>
                          "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
                      },
                      "html" => %{
                        "href" => "https://bitbucket.org/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D/"
                      },
                      "self" => %{
                        "href" => "https://api.bitbucket.org/2.0/users/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D"
                      }
                    },
                    "nickname" => "milana_stojadinov",
                    "type" => "user",
                    "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
                  }
                },
                "date" => "2021-06-15T10:45:59+00:00",
                "hash" => "daf07dd85350b95d05a7fe898e07022c5dcd95b9",
                "links" => %{
                  "approve" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/daf07dd85350b95d05a7fe898e07022c5dcd95b9/approve"
                  },
                  "comments" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/daf07dd85350b95d05a7fe898e07022c5dcd95b9/comments"
                  },
                  "diff" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/diff/daf07dd85350b95d05a7fe898e07022c5dcd95b9"
                  },
                  "html" => %{
                    "href" =>
                      "https://bitbucket.org/milana_stojadinov/elixir-project/commits/daf07dd85350b95d05a7fe898e07022c5dcd95b9"
                  },
                  "patch" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/patch/daf07dd85350b95d05a7fe898e07022c5dcd95b9"
                  },
                  "self" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/daf07dd85350b95d05a7fe898e07022c5dcd95b9"
                  },
                  "statuses" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/daf07dd85350b95d05a7fe898e07022c5dcd95b9/statuses"
                  }
                },
                "message" => "Push commit\n",
                "parents" => [
                  %{
                    "hash" => "d3da4886495b865f836a0c77daa9c8e080b136d1",
                    "links" => %{
                      "html" => %{
                        "href" =>
                          "https://bitbucket.org/milana_stojadinov/elixir-project/commits/d3da4886495b865f836a0c77daa9c8e080b136d1"
                      },
                      "self" => %{
                        "href" =>
                          "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/d3da4886495b865f836a0c77daa9c8e080b136d1"
                      }
                    },
                    "type" => "commit"
                  }
                ],
                "properties" => %{},
                "rendered" => %{},
                "summary" => %{
                  "html" => "<p>Push commit</p>",
                  "markup" => "markdown",
                  "raw" => "Push commit\n",
                  "type" => "rendered"
                },
                "type" => "commit"
              }
            ],
            "created" => false,
            "forced" => false,
            "links" => %{
              "commits" => %{
                "href" =>
                  "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commits?include=daf07dd85350b95d05a7fe898e07022c5dcd95b9&exclude=d3da4886495b865f836a0c77daa9c8e080b136d1"
              },
              "diff" => %{
                "href" =>
                  "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/diff/daf07dd85350b95d05a7fe898e07022c5dcd95b9..d3da4886495b865f836a0c77daa9c8e080b136d1"
              },
              "html" => %{
                "href" =>
                  "https://bitbucket.org/milana_stojadinov/elixir-project/branches/compare/daf07dd85350b95d05a7fe898e07022c5dcd95b9..d3da4886495b865f836a0c77daa9c8e080b136d1"
              }
            },
            "new" => %{
              "default_merge_strategy" => "merge_commit",
              "links" => %{
                "commits" => %{
                  "href" =>
                    "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commits/new-branch-push-new-commits"
                },
                "html" => %{
                  "href" => "https://bitbucket.org/milana_stojadinov/elixir-project/branch/new-branch-push-new-commits"
                },
                "self" => %{
                  "href" =>
                    "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/refs/branches/new-branch-push-new-commits"
                }
              },
              "merge_strategies" => ["merge_commit", "squash", "fast_forward"],
              "name" => "new-branch-push-new-commits",
              "target" => %{
                "author" => %{
                  "raw" => "Milana Stojadinov <milana.stojadinov@gmail.com>",
                  "type" => "author",
                  "user" => %{
                    "account_id" => "557058:a19b3000-9205-4825-983a-e223af783fd9",
                    "display_name" => "Milana Stojadinov",
                    "links" => %{
                      "avatar" => %{
                        "href" =>
                          "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
                      },
                      "html" => %{
                        "href" => "https://bitbucket.org/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D/"
                      },
                      "self" => %{
                        "href" => "https://api.bitbucket.org/2.0/users/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D"
                      }
                    },
                    "nickname" => "milana_stojadinov",
                    "type" => "user",
                    "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
                  }
                },
                "date" => "2021-06-15T10:45:59+00:00",
                "hash" => "daf07dd85350b95d05a7fe898e07022c5dcd95b9",
                "links" => %{
                  "html" => %{
                    "href" =>
                      "https://bitbucket.org/milana_stojadinov/elixir-project/commits/daf07dd85350b95d05a7fe898e07022c5dcd95b9"
                  },
                  "self" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/daf07dd85350b95d05a7fe898e07022c5dcd95b9"
                  }
                },
                "message" => "Push commit\n",
                "parents" => [
                  %{
                    "hash" => "d3da4886495b865f836a0c77daa9c8e080b136d1",
                    "links" => %{
                      "html" => %{
                        "href" =>
                          "https://bitbucket.org/milana_stojadinov/elixir-project/commits/d3da4886495b865f836a0c77daa9c8e080b136d1"
                      },
                      "self" => %{
                        "href" =>
                          "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/d3da4886495b865f836a0c77daa9c8e080b136d1"
                      }
                    },
                    "type" => "commit"
                  }
                ],
                "properties" => %{},
                "rendered" => %{},
                "summary" => %{
                  "html" => "<p>Push commit</p>",
                  "markup" => "markdown",
                  "raw" => "Push commit\n",
                  "type" => "rendered"
                },
                "type" => "commit"
              },
              "type" => "branch"
            },
            "old" => %{
              "default_merge_strategy" => "merge_commit",
              "links" => %{
                "commits" => %{
                  "href" =>
                    "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commits/new-branch-push-new-commits"
                },
                "html" => %{
                  "href" => "https://bitbucket.org/milana_stojadinov/elixir-project/branch/new-branch-push-new-commits"
                },
                "self" => %{
                  "href" =>
                    "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/refs/branches/new-branch-push-new-commits"
                }
              },
              "merge_strategies" => ["merge_commit", "squash", "fast_forward"],
              "name" => "new-branch-push-new-commits",
              "target" => %{
                "author" => %{
                  "raw" => "Milana Stojadinov <milana.stojadinov@gmail.com>",
                  "type" => "author",
                  "user" => %{
                    "account_id" => "557058:a19b3000-9205-4825-983a-e223af783fd9",
                    "display_name" => "Milana Stojadinov",
                    "links" => %{
                      "avatar" => %{
                        "href" =>
                          "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
                      },
                      "html" => %{
                        "href" => "https://bitbucket.org/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D/"
                      },
                      "self" => %{
                        "href" => "https://api.bitbucket.org/2.0/users/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D"
                      }
                    },
                    "nickname" => "milana_stojadinov",
                    "type" => "user",
                    "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
                  }
                },
                "date" => "2021-06-15T10:40:21+00:00",
                "hash" => "d3da4886495b865f836a0c77daa9c8e080b136d1",
                "links" => %{
                  "html" => %{
                    "href" =>
                      "https://bitbucket.org/milana_stojadinov/elixir-project/commits/d3da4886495b865f836a0c77daa9c8e080b136d1"
                  },
                  "self" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/d3da4886495b865f836a0c77daa9c8e080b136d1"
                  }
                },
                "message" => "Push new commit - force push\n",
                "parents" => [
                  %{
                    "hash" => "2a585bde481f0d5b3a10b10997210b6eb4893897",
                    "links" => %{
                      "html" => %{
                        "href" =>
                          "https://bitbucket.org/milana_stojadinov/elixir-project/commits/2a585bde481f0d5b3a10b10997210b6eb4893897"
                      },
                      "self" => %{
                        "href" =>
                          "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/2a585bde481f0d5b3a10b10997210b6eb4893897"
                      }
                    },
                    "type" => "commit"
                  }
                ],
                "properties" => %{},
                "rendered" => %{},
                "summary" => %{
                  "html" => "<p>Push new commit - force push</p>",
                  "markup" => "markdown",
                  "raw" => "Push new commit - force push\n",
                  "type" => "rendered"
                },
                "type" => "commit"
              },
              "type" => "branch"
            },
            "truncated" => false
          }
        ]
      },
      "repository" => %{
        "full_name" => "milana_stojadinov/elixir-project",
        "is_private" => true,
        "links" => %{
          "avatar" => %{
            "href" => "https://bytebucket.org/ravatar/%7B730ede8d-c0de-4f85-aef1-133881a9624f%7D?ts=default"
          },
          "html" => %{"href" => "https://bitbucket.org/milana_stojadinov/elixir-project"},
          "self" => %{
            "href" => "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project"
          }
        },
        "name" => "elixir-project",
        "owner" => %{
          "account_id" => "557058:a19b3000-9205-4825-983a-e223af783fd9",
          "display_name" => "Milana Stojadinov",
          "links" => %{
            "avatar" => %{
              "href" =>
                "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
            },
            "html" => %{
              "href" => "https://bitbucket.org/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D/"
            },
            "self" => %{
              "href" => "https://api.bitbucket.org/2.0/users/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D"
            }
          },
          "nickname" => "milana_stojadinov",
          "type" => "user",
          "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
        },
        "project" => %{
          "key" => "WEB",
          "links" => %{
            "avatar" => %{
              "href" => "https://bitbucket.org/account/user/milana_stojadinov/projects/WEB/avatar/32?ts=1623417282"
            },
            "html" => %{
              "href" => "https://bitbucket.org/milana_stojadinov/workspace/projects/WEB"
            },
            "self" => %{
              "href" => "https://api.bitbucket.org/2.0/workspaces/milana_stojadinov/projects/WEB"
            }
          },
          "name" => "webhooks-test",
          "type" => "project",
          "uuid" => "{1e6187d8-23a6-47fe-9a3d-328fbf61f572}"
        },
        "scm" => "git",
        "type" => "repository",
        "uuid" => "{730ede8d-c0de-4f85-aef1-133881a9624f}",
        "website" => "",
        "workspace" => %{
          "links" => %{
            "avatar" => %{
              "href" => "https://bitbucket.org/workspaces/milana_stojadinov/avatar/?ts=1543639881"
            },
            "html" => %{"href" => "https://bitbucket.org/milana_stojadinov/"},
            "self" => %{"href" => "https://api.bitbucket.org/2.0/workspaces/milana_stojadinov"}
          },
          "name" => "Milana Stojadinov",
          "slug" => "milana_stojadinov",
          "type" => "workspace",
          "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
        }
      }
    }
  end

  def push_commit_force do
    %{
      "actor" => %{
        "account_id" => "557058:a19b3000-9205-4825-983a-e223af783fd9",
        "display_name" => "Milana Stojadinov",
        "links" => %{
          "avatar" => %{
            "href" =>
              "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
          },
          "html" => %{
            "href" => "https://bitbucket.org/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D/"
          },
          "self" => %{
            "href" => "https://api.bitbucket.org/2.0/users/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D"
          }
        },
        "nickname" => "milana_stojadinov",
        "type" => "user",
        "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
      },
      "push" => %{
        "changes" => [
          %{
            "closed" => false,
            "commits" => [
              %{
                "author" => %{
                  "raw" => "Milana Stojadinov <milana.stojadinov@gmail.com>",
                  "type" => "author",
                  "user" => %{
                    "account_id" => "557058:a19b3000-9205-4825-983a-e223af783fd9",
                    "display_name" => "Milana Stojadinov",
                    "links" => %{
                      "avatar" => %{
                        "href" =>
                          "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
                      },
                      "html" => %{
                        "href" => "https://bitbucket.org/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D/"
                      },
                      "self" => %{
                        "href" => "https://api.bitbucket.org/2.0/users/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D"
                      }
                    },
                    "nickname" => "milana_stojadinov",
                    "type" => "user",
                    "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
                  }
                },
                "date" => "2021-06-15T10:40:21+00:00",
                "hash" => "d3da4886495b865f836a0c77daa9c8e080b136d1",
                "links" => %{
                  "approve" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/d3da4886495b865f836a0c77daa9c8e080b136d1/approve"
                  },
                  "comments" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/d3da4886495b865f836a0c77daa9c8e080b136d1/comments"
                  },
                  "diff" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/diff/d3da4886495b865f836a0c77daa9c8e080b136d1"
                  },
                  "html" => %{
                    "href" =>
                      "https://bitbucket.org/milana_stojadinov/elixir-project/commits/d3da4886495b865f836a0c77daa9c8e080b136d1"
                  },
                  "patch" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/patch/d3da4886495b865f836a0c77daa9c8e080b136d1"
                  },
                  "self" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/d3da4886495b865f836a0c77daa9c8e080b136d1"
                  },
                  "statuses" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/d3da4886495b865f836a0c77daa9c8e080b136d1/statuses"
                  }
                },
                "message" => "Push new commit - force push\n",
                "parents" => [
                  %{
                    "hash" => "2a585bde481f0d5b3a10b10997210b6eb4893897",
                    "links" => %{
                      "html" => %{
                        "href" =>
                          "https://bitbucket.org/milana_stojadinov/elixir-project/commits/2a585bde481f0d5b3a10b10997210b6eb4893897"
                      },
                      "self" => %{
                        "href" =>
                          "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/2a585bde481f0d5b3a10b10997210b6eb4893897"
                      }
                    },
                    "type" => "commit"
                  }
                ],
                "properties" => %{},
                "rendered" => %{},
                "summary" => %{
                  "html" => "<p>Push new commit - force push</p>",
                  "markup" => "markdown",
                  "raw" => "Push new commit - force push\n",
                  "type" => "rendered"
                },
                "type" => "commit"
              },
              %{
                "author" => %{
                  "raw" => "Milana Stojadinov <milana.stojadinov@gmail.com>",
                  "type" => "author",
                  "user" => %{
                    "account_id" => "557058:a19b3000-9205-4825-983a-e223af783fd9",
                    "display_name" => "Milana Stojadinov",
                    "links" => %{
                      "avatar" => %{
                        "href" =>
                          "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
                      },
                      "html" => %{
                        "href" => "https://bitbucket.org/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D/"
                      },
                      "self" => %{
                        "href" => "https://api.bitbucket.org/2.0/users/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D"
                      }
                    },
                    "nickname" => "milana_stojadinov",
                    "type" => "user",
                    "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
                  }
                },
                "date" => "2021-06-15T09:26:39+00:00",
                "hash" => "2a585bde481f0d5b3a10b10997210b6eb4893897",
                "links" => %{
                  "approve" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/2a585bde481f0d5b3a10b10997210b6eb4893897/approve"
                  },
                  "comments" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/2a585bde481f0d5b3a10b10997210b6eb4893897/comments"
                  },
                  "diff" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/diff/2a585bde481f0d5b3a10b10997210b6eb4893897"
                  },
                  "html" => %{
                    "href" =>
                      "https://bitbucket.org/milana_stojadinov/elixir-project/commits/2a585bde481f0d5b3a10b10997210b6eb4893897"
                  },
                  "patch" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/patch/2a585bde481f0d5b3a10b10997210b6eb4893897"
                  },
                  "self" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/2a585bde481f0d5b3a10b10997210b6eb4893897"
                  },
                  "statuses" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/2a585bde481f0d5b3a10b10997210b6eb4893897/statuses"
                  }
                },
                "message" => "Update readme\n",
                "parents" => [
                  %{
                    "hash" => "c699bacf22afa6f423ec4bc09da26a127559bc9a",
                    "links" => %{
                      "html" => %{
                        "href" =>
                          "https://bitbucket.org/milana_stojadinov/elixir-project/commits/c699bacf22afa6f423ec4bc09da26a127559bc9a"
                      },
                      "self" => %{
                        "href" =>
                          "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/c699bacf22afa6f423ec4bc09da26a127559bc9a"
                      }
                    },
                    "type" => "commit"
                  }
                ],
                "properties" => %{},
                "rendered" => %{},
                "summary" => %{
                  "html" => "<p>Update readme</p>",
                  "markup" => "markdown",
                  "raw" => "Update readme\n",
                  "type" => "rendered"
                },
                "type" => "commit"
              },
              %{
                "author" => %{
                  "raw" => "Milana Stojadinov <mstojadinov@renderedtext.com>",
                  "type" => "author"
                },
                "date" => "2016-09-13T15:17:21+00:00",
                "hash" => "c699bacf22afa6f423ec4bc09da26a127559bc9a",
                "links" => %{
                  "approve" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/c699bacf22afa6f423ec4bc09da26a127559bc9a/approve"
                  },
                  "comments" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/c699bacf22afa6f423ec4bc09da26a127559bc9a/comments"
                  },
                  "diff" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/diff/c699bacf22afa6f423ec4bc09da26a127559bc9a"
                  },
                  "html" => %{
                    "href" =>
                      "https://bitbucket.org/milana_stojadinov/elixir-project/commits/c699bacf22afa6f423ec4bc09da26a127559bc9a"
                  },
                  "patch" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/patch/c699bacf22afa6f423ec4bc09da26a127559bc9a"
                  },
                  "self" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/c699bacf22afa6f423ec4bc09da26a127559bc9a"
                  },
                  "statuses" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/c699bacf22afa6f423ec4bc09da26a127559bc9a/statuses"
                  }
                },
                "message" => "Remove build badge\n",
                "parents" => [
                  %{
                    "hash" => "89c33b336178a6c218f003c678ae96c0301b0a78",
                    "links" => %{
                      "html" => %{
                        "href" =>
                          "https://bitbucket.org/milana_stojadinov/elixir-project/commits/89c33b336178a6c218f003c678ae96c0301b0a78"
                      },
                      "self" => %{
                        "href" =>
                          "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/89c33b336178a6c218f003c678ae96c0301b0a78"
                      }
                    },
                    "type" => "commit"
                  }
                ],
                "properties" => %{},
                "rendered" => %{},
                "summary" => %{
                  "html" => "<p>Remove build badge</p>",
                  "markup" => "markdown",
                  "raw" => "Remove build badge\n",
                  "type" => "rendered"
                },
                "type" => "commit"
              },
              %{
                "author" => %{
                  "raw" => "adequateDeveloper <adequate.developer@gmail.com>",
                  "type" => "author"
                },
                "date" => "2016-09-13T14:27:02+00:00",
                "hash" => "89c33b336178a6c218f003c678ae96c0301b0a78",
                "links" => %{
                  "approve" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/89c33b336178a6c218f003c678ae96c0301b0a78/approve"
                  },
                  "comments" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/89c33b336178a6c218f003c678ae96c0301b0a78/comments"
                  },
                  "diff" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/diff/89c33b336178a6c218f003c678ae96c0301b0a78"
                  },
                  "html" => %{
                    "href" =>
                      "https://bitbucket.org/milana_stojadinov/elixir-project/commits/89c33b336178a6c218f003c678ae96c0301b0a78"
                  },
                  "patch" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/patch/89c33b336178a6c218f003c678ae96c0301b0a78"
                  },
                  "self" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/89c33b336178a6c218f003c678ae96c0301b0a78"
                  },
                  "statuses" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/89c33b336178a6c218f003c678ae96c0301b0a78/statuses"
                  }
                },
                "message" => "Updated alias statements\n",
                "parents" => [
                  %{
                    "hash" => "f4866285864a6c28e21c270586f9f0651ed28a3f",
                    "links" => %{
                      "html" => %{
                        "href" =>
                          "https://bitbucket.org/milana_stojadinov/elixir-project/commits/f4866285864a6c28e21c270586f9f0651ed28a3f"
                      },
                      "self" => %{
                        "href" =>
                          "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/f4866285864a6c28e21c270586f9f0651ed28a3f"
                      }
                    },
                    "type" => "commit"
                  }
                ],
                "properties" => %{},
                "rendered" => %{},
                "summary" => %{
                  "html" => "<p>Updated alias statements</p>",
                  "markup" => "markdown",
                  "raw" => "Updated alias statements\n",
                  "type" => "rendered"
                },
                "type" => "commit"
              },
              %{
                "author" => %{
                  "raw" => "Dan McHarness <adequate.developer@gmail.com>",
                  "type" => "author"
                },
                "date" => "2016-09-10T16:48:58+00:00",
                "hash" => "f4866285864a6c28e21c270586f9f0651ed28a3f",
                "links" => %{
                  "approve" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/f4866285864a6c28e21c270586f9f0651ed28a3f/approve"
                  },
                  "comments" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/f4866285864a6c28e21c270586f9f0651ed28a3f/comments"
                  },
                  "diff" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/diff/f4866285864a6c28e21c270586f9f0651ed28a3f"
                  },
                  "html" => %{
                    "href" =>
                      "https://bitbucket.org/milana_stojadinov/elixir-project/commits/f4866285864a6c28e21c270586f9f0651ed28a3f"
                  },
                  "patch" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/patch/f4866285864a6c28e21c270586f9f0651ed28a3f"
                  },
                  "self" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/f4866285864a6c28e21c270586f9f0651ed28a3f"
                  },
                  "statuses" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/f4866285864a6c28e21c270586f9f0651ed28a3f/statuses"
                  }
                },
                "message" => "Mods to test and Semaphore CI config notes\n",
                "parents" => [
                  %{
                    "hash" => "b241d65dd90a6bb90612c0bb33b35393e37e2027",
                    "links" => %{
                      "html" => %{
                        "href" =>
                          "https://bitbucket.org/milana_stojadinov/elixir-project/commits/b241d65dd90a6bb90612c0bb33b35393e37e2027"
                      },
                      "self" => %{
                        "href" =>
                          "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/b241d65dd90a6bb90612c0bb33b35393e37e2027"
                      }
                    },
                    "type" => "commit"
                  }
                ],
                "properties" => %{},
                "rendered" => %{},
                "summary" => %{
                  "html" => "<p>Mods to test and Semaphore CI config notes</p>",
                  "markup" => "markdown",
                  "raw" => "Mods to test and Semaphore CI config notes\n",
                  "type" => "rendered"
                },
                "type" => "commit"
              }
            ],
            "created" => false,
            "forced" => true,
            "links" => %{
              "commits" => %{
                "href" =>
                  "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commits?include=d3da4886495b865f836a0c77daa9c8e080b136d1&exclude=c9a484933fcd7abb438600eb9786c21aa0f68dfa"
              },
              "html" => %{
                "href" => "https://bitbucket.org/milana_stojadinov/elixir-project/branch/new-branch-push-new-commits"
              }
            },
            "new" => %{
              "default_merge_strategy" => "merge_commit",
              "links" => %{
                "commits" => %{
                  "href" =>
                    "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commits/new-branch-push-new-commits"
                },
                "html" => %{
                  "href" => "https://bitbucket.org/milana_stojadinov/elixir-project/branch/new-branch-push-new-commits"
                },
                "self" => %{
                  "href" =>
                    "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/refs/branches/new-branch-push-new-commits"
                }
              },
              "merge_strategies" => ["merge_commit", "squash", "fast_forward"],
              "name" => "new-branch-push-new-commits",
              "target" => %{
                "author" => %{
                  "raw" => "Milana Stojadinov <milana.stojadinov@gmail.com>",
                  "type" => "author",
                  "user" => %{
                    "account_id" => "557058:a19b3000-9205-4825-983a-e223af783fd9",
                    "display_name" => "Milana Stojadinov",
                    "links" => %{
                      "avatar" => %{
                        "href" =>
                          "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
                      },
                      "html" => %{
                        "href" => "https://bitbucket.org/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D/"
                      },
                      "self" => %{
                        "href" => "https://api.bitbucket.org/2.0/users/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D"
                      }
                    },
                    "nickname" => "milana_stojadinov",
                    "type" => "user",
                    "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
                  }
                },
                "date" => "2021-06-15T10:40:21+00:00",
                "hash" => "d3da4886495b865f836a0c77daa9c8e080b136d1",
                "links" => %{
                  "html" => %{
                    "href" =>
                      "https://bitbucket.org/milana_stojadinov/elixir-project/commits/d3da4886495b865f836a0c77daa9c8e080b136d1"
                  },
                  "self" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/d3da4886495b865f836a0c77daa9c8e080b136d1"
                  }
                },
                "message" => "Push new commit - force push\n",
                "parents" => [
                  %{
                    "hash" => "2a585bde481f0d5b3a10b10997210b6eb4893897",
                    "links" => %{
                      "html" => %{
                        "href" =>
                          "https://bitbucket.org/milana_stojadinov/elixir-project/commits/2a585bde481f0d5b3a10b10997210b6eb4893897"
                      },
                      "self" => %{
                        "href" =>
                          "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/2a585bde481f0d5b3a10b10997210b6eb4893897"
                      }
                    },
                    "type" => "commit"
                  }
                ],
                "properties" => %{},
                "rendered" => %{},
                "summary" => %{
                  "html" => "<p>Push new commit - force push</p>",
                  "markup" => "markdown",
                  "raw" => "Push new commit - force push\n",
                  "type" => "rendered"
                },
                "type" => "commit"
              },
              "type" => "branch"
            },
            "old" => %{
              "default_merge_strategy" => "merge_commit",
              "links" => %{
                "commits" => %{
                  "href" =>
                    "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commits/new-branch-push-new-commits"
                },
                "html" => %{
                  "href" => "https://bitbucket.org/milana_stojadinov/elixir-project/branch/new-branch-push-new-commits"
                },
                "self" => %{
                  "href" =>
                    "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/refs/branches/new-branch-push-new-commits"
                }
              },
              "merge_strategies" => ["merge_commit", "squash", "fast_forward"],
              "name" => "new-branch-push-new-commits",
              "target" => %{
                "author" => %{
                  "raw" => "Milana Stojadinov <milana.stojadinov@gmail.com>",
                  "type" => "author",
                  "user" => %{
                    "account_id" => "557058:a19b3000-9205-4825-983a-e223af783fd9",
                    "display_name" => "Milana Stojadinov",
                    "links" => %{
                      "avatar" => %{
                        "href" =>
                          "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
                      },
                      "html" => %{
                        "href" => "https://bitbucket.org/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D/"
                      },
                      "self" => %{
                        "href" => "https://api.bitbucket.org/2.0/users/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D"
                      }
                    },
                    "nickname" => "milana_stojadinov",
                    "type" => "user",
                    "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
                  }
                },
                "date" => "2021-06-15T10:39:52+00:00",
                "hash" => "c9a484933fcd7abb438600eb9786c21aa0f68dfa",
                "links" => %{
                  "html" => %{
                    "href" =>
                      "https://bitbucket.org/milana_stojadinov/elixir-project/commits/c9a484933fcd7abb438600eb9786c21aa0f68dfa"
                  },
                  "self" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/c9a484933fcd7abb438600eb9786c21aa0f68dfa"
                  }
                },
                "message" => "Push new commit\n",
                "parents" => [
                  %{
                    "hash" => "2a585bde481f0d5b3a10b10997210b6eb4893897",
                    "links" => %{
                      "html" => %{
                        "href" =>
                          "https://bitbucket.org/milana_stojadinov/elixir-project/commits/2a585bde481f0d5b3a10b10997210b6eb4893897"
                      },
                      "self" => %{
                        "href" =>
                          "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/2a585bde481f0d5b3a10b10997210b6eb4893897"
                      }
                    },
                    "type" => "commit"
                  }
                ],
                "properties" => %{},
                "rendered" => %{},
                "summary" => %{
                  "html" => "<p>Push new commit</p>",
                  "markup" => "markdown",
                  "raw" => "Push new commit\n",
                  "type" => "rendered"
                },
                "type" => "commit"
              },
              "type" => "branch"
            },
            "truncated" => true
          }
        ]
      },
      "repository" => %{
        "full_name" => "milana_stojadinov/elixir-project",
        "is_private" => true,
        "links" => %{
          "avatar" => %{
            "href" => "https://bytebucket.org/ravatar/%7B730ede8d-c0de-4f85-aef1-133881a9624f%7D?ts=default"
          },
          "html" => %{"href" => "https://bitbucket.org/milana_stojadinov/elixir-project"},
          "self" => %{
            "href" => "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project"
          }
        },
        "name" => "elixir-project",
        "owner" => %{
          "account_id" => "557058:a19b3000-9205-4825-983a-e223af783fd9",
          "display_name" => "Milana Stojadinov",
          "links" => %{
            "avatar" => %{
              "href" =>
                "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
            },
            "html" => %{
              "href" => "https://bitbucket.org/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D/"
            },
            "self" => %{
              "href" => "https://api.bitbucket.org/2.0/users/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D"
            }
          },
          "nickname" => "milana_stojadinov",
          "type" => "user",
          "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
        },
        "project" => %{
          "key" => "WEB",
          "links" => %{
            "avatar" => %{
              "href" => "https://bitbucket.org/account/user/milana_stojadinov/projects/WEB/avatar/32?ts=1623417282"
            },
            "html" => %{
              "href" => "https://bitbucket.org/milana_stojadinov/workspace/projects/WEB"
            },
            "self" => %{
              "href" => "https://api.bitbucket.org/2.0/workspaces/milana_stojadinov/projects/WEB"
            }
          },
          "name" => "webhooks-test",
          "type" => "project",
          "uuid" => "{1e6187d8-23a6-47fe-9a3d-328fbf61f572}"
        },
        "scm" => "git",
        "type" => "repository",
        "uuid" => "{730ede8d-c0de-4f85-aef1-133881a9624f}",
        "website" => "",
        "workspace" => %{
          "links" => %{
            "avatar" => %{
              "href" => "https://bitbucket.org/workspaces/milana_stojadinov/avatar/?ts=1543639881"
            },
            "html" => %{"href" => "https://bitbucket.org/milana_stojadinov/"},
            "self" => %{"href" => "https://api.bitbucket.org/2.0/workspaces/milana_stojadinov"}
          },
          "name" => "Milana Stojadinov",
          "slug" => "milana_stojadinov",
          "type" => "workspace",
          "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
        }
      }
    }
  end

  def branch_deletion do
    %{
      "actor" => %{
        "account_id" => "557058:a19b3000-9205-4825-983a-e223af783fd9",
        "display_name" => "Milana Stojadinov",
        "links" => %{
          "avatar" => %{
            "href" =>
              "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
          },
          "html" => %{
            "href" => "https://bitbucket.org/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D/"
          },
          "self" => %{
            "href" => "https://api.bitbucket.org/2.0/users/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D"
          }
        },
        "nickname" => "milana_stojadinov",
        "type" => "user",
        "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
      },
      "push" => %{
        "changes" => [
          %{
            "closed" => true,
            "created" => false,
            "forced" => false,
            "new" => nil,
            "old" => %{
              "default_merge_strategy" => "merge_commit",
              "links" => %{
                "commits" => %{
                  "href" =>
                    "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commits/mtmp1123333333"
                },
                "html" => %{
                  "href" => "https://bitbucket.org/milana_stojadinov/elixir-project/branch/mtmp1123333333"
                },
                "self" => %{
                  "href" =>
                    "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/refs/branches/mtmp1123333333"
                }
              },
              "merge_strategies" => ["merge_commit", "squash", "fast_forward"],
              "name" => "mtmp1123333333",
              "target" => %{
                "author" => %{
                  "raw" => "Milana Stojadinov <milana.stojadinov@gmail.com>",
                  "type" => "author",
                  "user" => %{
                    "account_id" => "557058:a19b3000-9205-4825-983a-e223af783fd9",
                    "display_name" => "Milana Stojadinov",
                    "links" => %{
                      "avatar" => %{
                        "href" =>
                          "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
                      },
                      "html" => %{
                        "href" => "https://bitbucket.org/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D/"
                      },
                      "self" => %{
                        "href" => "https://api.bitbucket.org/2.0/users/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D"
                      }
                    },
                    "nickname" => "milana_stojadinov",
                    "type" => "user",
                    "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
                  }
                },
                "date" => "2021-06-11T16:01:26+00:00",
                "hash" => "d2b7d8ca15effafc1a24ac5fd099f34b5447c9ad",
                "links" => %{
                  "html" => %{
                    "href" =>
                      "https://bitbucket.org/milana_stojadinov/elixir-project/commits/d2b7d8ca15effafc1a24ac5fd099f34b5447c9ad"
                  },
                  "self" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/d2b7d8ca15effafc1a24ac5fd099f34b5447c9ad"
                  }
                },
                "message" => "Update readme\n",
                "parents" => [
                  %{
                    "hash" => "c699bacf22afa6f423ec4bc09da26a127559bc9a",
                    "links" => %{
                      "html" => %{
                        "href" =>
                          "https://bitbucket.org/milana_stojadinov/elixir-project/commits/c699bacf22afa6f423ec4bc09da26a127559bc9a"
                      },
                      "self" => %{
                        "href" =>
                          "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/c699bacf22afa6f423ec4bc09da26a127559bc9a"
                      }
                    },
                    "type" => "commit"
                  }
                ],
                "properties" => %{},
                "rendered" => %{},
                "summary" => %{
                  "html" => "<p>Update readme</p>",
                  "markup" => "markdown",
                  "raw" => "Update readme\n",
                  "type" => "rendered"
                },
                "type" => "commit"
              },
              "type" => "branch"
            },
            "truncated" => false
          }
        ]
      },
      "repository" => %{
        "full_name" => "milana_stojadinov/elixir-project",
        "is_private" => true,
        "links" => %{
          "avatar" => %{
            "href" => "https://bytebucket.org/ravatar/%7B730ede8d-c0de-4f85-aef1-133881a9624f%7D?ts=default"
          },
          "html" => %{"href" => "https://bitbucket.org/milana_stojadinov/elixir-project"},
          "self" => %{
            "href" => "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project"
          }
        },
        "name" => "elixir-project",
        "owner" => %{
          "account_id" => "557058:a19b3000-9205-4825-983a-e223af783fd9",
          "display_name" => "Milana Stojadinov",
          "links" => %{
            "avatar" => %{
              "href" =>
                "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
            },
            "html" => %{
              "href" => "https://bitbucket.org/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D/"
            },
            "self" => %{
              "href" => "https://api.bitbucket.org/2.0/users/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D"
            }
          },
          "nickname" => "milana_stojadinov",
          "type" => "user",
          "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
        },
        "project" => %{
          "key" => "WEB",
          "links" => %{
            "avatar" => %{
              "href" => "https://bitbucket.org/account/user/milana_stojadinov/projects/WEB/avatar/32?ts=1623417282"
            },
            "html" => %{
              "href" => "https://bitbucket.org/milana_stojadinov/workspace/projects/WEB"
            },
            "self" => %{
              "href" => "https://api.bitbucket.org/2.0/workspaces/milana_stojadinov/projects/WEB"
            }
          },
          "name" => "webhooks-test",
          "type" => "project",
          "uuid" => "{1e6187d8-23a6-47fe-9a3d-328fbf61f572}"
        },
        "scm" => "git",
        "type" => "repository",
        "uuid" => "{730ede8d-c0de-4f85-aef1-133881a9624f}",
        "website" => "",
        "workspace" => %{
          "links" => %{
            "avatar" => %{
              "href" => "https://bitbucket.org/workspaces/milana_stojadinov/avatar/?ts=1543639881"
            },
            "html" => %{"href" => "https://bitbucket.org/milana_stojadinov/"},
            "self" => %{"href" => "https://api.bitbucket.org/2.0/workspaces/milana_stojadinov"}
          },
          "name" => "Milana Stojadinov",
          "slug" => "milana_stojadinov",
          "type" => "workspace",
          "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
        }
      }
    }
  end

  def push_annoted_tag do
    %{
      "actor" => %{
        "account_id" => "557058:a19b3000-9205-4825-983a-e223af783fd9",
        "display_name" => "Milana Stojadinov",
        "links" => %{
          "avatar" => %{
            "href" =>
              "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
          },
          "html" => %{
            "href" => "https://bitbucket.org/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D/"
          },
          "self" => %{
            "href" => "https://api.bitbucket.org/2.0/users/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D"
          }
        },
        "nickname" => "milana_stojadinov",
        "type" => "user",
        "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
      },
      "push" => %{
        "changes" => [
          %{
            "closed" => false,
            "created" => true,
            "forced" => false,
            "links" => %{
              "commits" => %{
                "href" =>
                  "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commits?include=daf07dd85350b95d05a7fe898e07022c5dcd95b9"
              }
            },
            "new" => %{
              "date" => "2021-06-15T10:58:28+00:00",
              "links" => %{
                "commits" => %{
                  "href" => "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commits/v1.6"
                },
                "html" => %{
                  "href" => "https://bitbucket.org/milana_stojadinov/elixir-project/commits/tag/v1.6"
                },
                "self" => %{
                  "href" => "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/refs/tags/v1.6"
                }
              },
              "message" => "my version 1.6\n",
              "name" => "v1.6",
              "tagger" => %{},
              "target" => %{
                "author" => %{
                  "raw" => "Milana Stojadinov <milana.stojadinov@gmail.com>",
                  "type" => "author",
                  "user" => %{
                    "account_id" => "557058:a19b3000-9205-4825-983a-e223af783fd9",
                    "display_name" => "Milana Stojadinov",
                    "links" => %{
                      "avatar" => %{
                        "href" =>
                          "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
                      },
                      "html" => %{
                        "href" => "https://bitbucket.org/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D/"
                      },
                      "self" => %{
                        "href" => "https://api.bitbucket.org/2.0/users/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D"
                      }
                    },
                    "nickname" => "milana_stojadinov",
                    "type" => "user",
                    "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
                  }
                },
                "date" => "2021-06-15T10:45:59+00:00",
                "hash" => "daf07dd85350b95d05a7fe898e07022c5dcd95b9",
                "links" => %{
                  "html" => %{
                    "href" =>
                      "https://bitbucket.org/milana_stojadinov/elixir-project/commits/daf07dd85350b95d05a7fe898e07022c5dcd95b9"
                  },
                  "self" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/daf07dd85350b95d05a7fe898e07022c5dcd95b9"
                  }
                },
                "message" => "Push commit\n",
                "parents" => [
                  %{
                    "hash" => "d3da4886495b865f836a0c77daa9c8e080b136d1",
                    "links" => %{
                      "html" => %{
                        "href" =>
                          "https://bitbucket.org/milana_stojadinov/elixir-project/commits/d3da4886495b865f836a0c77daa9c8e080b136d1"
                      },
                      "self" => %{
                        "href" =>
                          "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/d3da4886495b865f836a0c77daa9c8e080b136d1"
                      }
                    },
                    "type" => "commit"
                  }
                ],
                "properties" => %{},
                "rendered" => %{},
                "summary" => %{
                  "html" => "<p>Push commit</p>",
                  "markup" => "markdown",
                  "raw" => "Push commit\n",
                  "type" => "rendered"
                },
                "type" => "commit"
              },
              "type" => "tag"
            },
            "old" => nil,
            "truncated" => false
          }
        ]
      },
      "repository" => %{
        "full_name" => "milana_stojadinov/elixir-project",
        "is_private" => true,
        "links" => %{
          "avatar" => %{
            "href" => "https://bytebucket.org/ravatar/%7B730ede8d-c0de-4f85-aef1-133881a9624f%7D?ts=default"
          },
          "html" => %{"href" => "https://bitbucket.org/milana_stojadinov/elixir-project"},
          "self" => %{
            "href" => "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project"
          }
        },
        "name" => "elixir-project",
        "owner" => %{
          "account_id" => "557058:a19b3000-9205-4825-983a-e223af783fd9",
          "display_name" => "Milana Stojadinov",
          "links" => %{
            "avatar" => %{
              "href" =>
                "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
            },
            "html" => %{
              "href" => "https://bitbucket.org/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D/"
            },
            "self" => %{
              "href" => "https://api.bitbucket.org/2.0/users/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D"
            }
          },
          "nickname" => "milana_stojadinov",
          "type" => "user",
          "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
        },
        "project" => %{
          "key" => "WEB",
          "links" => %{
            "avatar" => %{
              "href" => "https://bitbucket.org/account/user/milana_stojadinov/projects/WEB/avatar/32?ts=1623417282"
            },
            "html" => %{
              "href" => "https://bitbucket.org/milana_stojadinov/workspace/projects/WEB"
            },
            "self" => %{
              "href" => "https://api.bitbucket.org/2.0/workspaces/milana_stojadinov/projects/WEB"
            }
          },
          "name" => "webhooks-test",
          "type" => "project",
          "uuid" => "{1e6187d8-23a6-47fe-9a3d-328fbf61f572}"
        },
        "scm" => "git",
        "type" => "repository",
        "uuid" => "{730ede8d-c0de-4f85-aef1-133881a9624f}",
        "website" => "",
        "workspace" => %{
          "links" => %{
            "avatar" => %{
              "href" => "https://bitbucket.org/workspaces/milana_stojadinov/avatar/?ts=1543639881"
            },
            "html" => %{"href" => "https://bitbucket.org/milana_stojadinov/"},
            "self" => %{"href" => "https://api.bitbucket.org/2.0/workspaces/milana_stojadinov"}
          },
          "name" => "Milana Stojadinov",
          "slug" => "milana_stojadinov",
          "type" => "workspace",
          "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
        }
      }
    }
  end

  def tag_deletion do
    %{
      "id" => "00000000-4000-4000-b000-000000000011",
      "push" => %{
        "changes" => [
          %{
            "new" => nil,
            "old" => %{
              "date" => "2025-08-27T11:17:57+00:00",
              "name" => "v1.0-alpha",
              "type" => "tag",
              "links" => %{
                "html" => %{
                  "href" => "https://bitbucket.org/fake-test-user-1234/fake-test-repo-2025/commits/tag/v1.0-alpha"
                },
                "self" => %{
                  "href" =>
                    "https://api.bitbucket.org/2.0/repositories/fake-test-user-1234/fake-test-repo-2025/refs/tags/v1.0-alpha"
                },
                "commits" => %{
                  "href" =>
                    "https://api.bitbucket.org/2.0/repositories/fake-test-user-1234/fake-test-repo-2025/commits/v1.0-alpha"
                }
              },
              "tagger" => %{},
              "target" => %{
                "date" => "2025-07-11T16:40:54+00:00",
                "hash" => "86efd1e2f788d237a9b8d6da5c04683d289ad805",
                "type" => "commit",
                "links" => %{
                  "html" => %{
                    "href" =>
                      "https://bitbucket.org/fake-test-user-1234/fake-test-repo-2025/commits/86efd1e2f788d237a9b8d6da5c04683d289ad805"
                  },
                  "self" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/fake-test-user-1234/fake-test-repo-2025/commit/86efd1e2f788d237a9b8d6da5c04683d289ad805"
                  }
                },
                "author" => %{
                  "raw" => "fake-test-user-1234 <fake-test-user-1234@gmail.com>",
                  "type" => "author",
                  "user" => %{
                    "type" => "user",
                    "uuid" => "{10000000-5000-4000-9000-000000000012}",
                    "links" => %{
                      "html" => %{
                        "href" => "https://bitbucket.org/%7B10000000-5000-4000-9000-000000000012%7D/"
                      },
                      "self" => %{
                        "href" => "https://api.bitbucket.org/2.0/users/%7B10000000-5000-4000-9000-000000000012%7D"
                      },
                      "avatar" => %{
                        "href" =>
                          "https://secure.gravatar.com/avatar/77922059a60e9df4e4896620745be781?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FO-3.png"
                      }
                    },
                    "nickname" => "fake-test-user-1234",
                    "account_id" => "123456:90000000-e000-4000-b000-000000000012",
                    "display_name" => "fake-test-user-1234"
                  }
                },
                "message" => "README.md created online with Bitbucket",
                "parents" => [],
                "summary" => %{
                  "raw" => "README.md created online with Bitbucket",
                  "html" => "<p>README.md created online with Bitbucket</p>",
                  "type" => "rendered",
                  "markup" => "markdown"
                },
                "rendered" => %{},
                "committer" => %{},
                "properties" => %{}
              },
              "message" => "test tag description v1.0-alpha"
            },
            "closed" => true,
            "forced" => false,
            "created" => false,
            "truncated" => false
          }
        ]
      },
      "actor" => %{
        "kind" => "repository_access_token",
        "type" => "app_user",
        "uuid" => "{00000000-6000-4000-9000-000000000012}",
        "links" => %{
          "avatar" => %{
            "href" =>
              "https://avatar-management--avatars.us-west-2.prod.public.atl-paas.net/123123:00000000-1000-4000-9000-000000000012/00000000-b000-4000-8000-000000000012/128"
          }
        },
        "account_id" => "123123:00000000-1000-4000-9000-000000000012",
        "created_on" => "2025-08-27T11:39:07.919487+00:00",
        "display_name" => "test-onprem-27082025",
        "account_status" => "active"
      },
      "repository" => %{
        "scm" => "git",
        "name" => "fake-test-repo-2025",
        "type" => "repository",
        "uuid" => "{00000000-1000-4000-9000-000000000012}",
        "links" => %{
          "html" => %{
            "href" => "https://bitbucket.org/fake-test-user-1234/fake-test-repo-2025"
          },
          "self" => %{
            "href" => "https://api.bitbucket.org/2.0/repositories/fake-test-user-1234/fake-test-repo-2025"
          },
          "avatar" => %{
            "href" => "https://bytebucket.org/ravatar/%7B00000000-1000-4000-9000-000000000012%7D?ts=default"
          }
        },
        "owner" => %{
          "type" => "team",
          "uuid" => "{00000000-e000-4000-8000-000000000012}",
          "links" => %{
            "html" => %{
              "href" => "https://bitbucket.org/%7B00000000-e000-4000-8000-000000000012%7D/"
            },
            "self" => %{
              "href" => "https://api.bitbucket.org/2.0/workspaces/%7B00000000-e000-4000-8000-000000000012%7D"
            },
            "avatar" => %{
              "href" => "https://bitbucket.org/account/fake-test-user-1234/avatar/"
            }
          },
          "username" => "fake-test-user-1234",
          "display_name" => "fake-test-user-1234"
        },
        "parent" => nil,
        "project" => %{
          "key" => "ON",
          "name" => "fake-test-repo-2025",
          "type" => "project",
          "uuid" => "{63b82869-0d52-4840-a528-4dc1ed07c496}",
          "links" => %{
            "html" => %{
              "href" => "https://bitbucket.org/fake-test-user-1234/workspace/projects/ON"
            },
            "self" => %{
              "href" => "https://api.bitbucket.org/2.0/workspaces/fake-test-user-1234/projects/ON"
            },
            "avatar" => %{
              "href" => "https://bitbucket.org/fake-test-user-1234/workspace/projects/ON/avatar/32?ts=1752251119"
            }
          }
        },
        "website" => nil,
        "full_name" => "fake-test-user-1234/fake-test-repo-2025",
        "workspace" => %{
          "name" => "fake-test-user-1234",
          "slug" => "fake-test-user-1234",
          "type" => "workspace",
          "uuid" => "{00000000-e000-4000-8000-000000000012}",
          "links" => %{
            "html" => %{
              "href" => "https://bitbucket.org/fake-test-user-1234/"
            },
            "self" => %{
              "href" => "https://api.bitbucket.org/2.0/workspaces/fake-test-user-1234"
            },
            "avatar" => %{
              "href" => "https://bitbucket.org/workspaces/fake-test-user-1234/avatar/?ts=1752251089"
            }
          }
        },
        "is_private" => true
      }
    }
  end

  def push_lightweight_tag do
    %{
      "actor" => %{
        "account_id" => "557058:a19b3000-9205-4825-983a-e223af783fd9",
        "display_name" => "Milana Stojadinov",
        "links" => %{
          "avatar" => %{
            "href" =>
              "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
          },
          "html" => %{
            "href" => "https://bitbucket.org/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D/"
          },
          "self" => %{
            "href" => "https://api.bitbucket.org/2.0/users/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D"
          }
        },
        "nickname" => "milana_stojadinov",
        "type" => "user",
        "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
      },
      "push" => %{
        "changes" => [
          %{
            "closed" => false,
            "created" => true,
            "forced" => false,
            "links" => %{
              "commits" => %{
                "href" =>
                  "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commits?include=daf07dd85350b95d05a7fe898e07022c5dcd95b9"
              }
            },
            "new" => %{
              "date" => nil,
              "links" => %{
                "commits" => %{
                  "href" =>
                    "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commits/v1.6-lw"
                },
                "html" => %{
                  "href" => "https://bitbucket.org/milana_stojadinov/elixir-project/commits/tag/v1.6-lw"
                },
                "self" => %{
                  "href" =>
                    "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/refs/tags/v1.6-lw"
                }
              },
              "message" => nil,
              "name" => "v1.6-lw",
              "tagger" => nil,
              "target" => %{
                "author" => %{
                  "raw" => "Milana Stojadinov <milana.stojadinov@gmail.com>",
                  "type" => "author",
                  "user" => %{
                    "account_id" => "557058:a19b3000-9205-4825-983a-e223af783fd9",
                    "display_name" => "Milana Stojadinov",
                    "links" => %{
                      "avatar" => %{
                        "href" =>
                          "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
                      },
                      "html" => %{
                        "href" => "https://bitbucket.org/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D/"
                      },
                      "self" => %{
                        "href" => "https://api.bitbucket.org/2.0/users/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D"
                      }
                    },
                    "nickname" => "milana_stojadinov",
                    "type" => "user",
                    "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
                  }
                },
                "date" => "2021-06-15T10:45:59+00:00",
                "hash" => "daf07dd85350b95d05a7fe898e07022c5dcd95b9",
                "links" => %{
                  "html" => %{
                    "href" =>
                      "https://bitbucket.org/milana_stojadinov/elixir-project/commits/daf07dd85350b95d05a7fe898e07022c5dcd95b9"
                  },
                  "self" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/daf07dd85350b95d05a7fe898e07022c5dcd95b9"
                  }
                },
                "message" => "Push commit\n",
                "parents" => [
                  %{
                    "hash" => "d3da4886495b865f836a0c77daa9c8e080b136d1",
                    "links" => %{
                      "html" => %{
                        "href" =>
                          "https://bitbucket.org/milana_stojadinov/elixir-project/commits/d3da4886495b865f836a0c77daa9c8e080b136d1"
                      },
                      "self" => %{
                        "href" =>
                          "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/d3da4886495b865f836a0c77daa9c8e080b136d1"
                      }
                    },
                    "type" => "commit"
                  }
                ],
                "properties" => %{},
                "rendered" => %{},
                "summary" => %{
                  "html" => "<p>Push commit</p>",
                  "markup" => "markdown",
                  "raw" => "Push commit\n",
                  "type" => "rendered"
                },
                "type" => "commit"
              },
              "type" => "tag"
            },
            "old" => nil,
            "truncated" => false
          }
        ]
      },
      "repository" => %{
        "full_name" => "milana_stojadinov/elixir-project",
        "is_private" => true,
        "links" => %{
          "avatar" => %{
            "href" => "https://bytebucket.org/ravatar/%7B730ede8d-c0de-4f85-aef1-133881a9624f%7D?ts=default"
          },
          "html" => %{"href" => "https://bitbucket.org/milana_stojadinov/elixir-project"},
          "self" => %{
            "href" => "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project"
          }
        },
        "name" => "elixir-project",
        "owner" => %{
          "account_id" => "557058:a19b3000-9205-4825-983a-e223af783fd9",
          "display_name" => "Milana Stojadinov",
          "links" => %{
            "avatar" => %{
              "href" =>
                "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
            },
            "html" => %{
              "href" => "https://bitbucket.org/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D/"
            },
            "self" => %{
              "href" => "https://api.bitbucket.org/2.0/users/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D"
            }
          },
          "nickname" => "milana_stojadinov",
          "type" => "user",
          "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
        },
        "project" => %{
          "key" => "WEB",
          "links" => %{
            "avatar" => %{
              "href" => "https://bitbucket.org/account/user/milana_stojadinov/projects/WEB/avatar/32?ts=1623417282"
            },
            "html" => %{
              "href" => "https://bitbucket.org/milana_stojadinov/workspace/projects/WEB"
            },
            "self" => %{
              "href" => "https://api.bitbucket.org/2.0/workspaces/milana_stojadinov/projects/WEB"
            }
          },
          "name" => "webhooks-test",
          "type" => "project",
          "uuid" => "{1e6187d8-23a6-47fe-9a3d-328fbf61f572}"
        },
        "scm" => "git",
        "type" => "repository",
        "uuid" => "{730ede8d-c0de-4f85-aef1-133881a9624f}",
        "website" => "",
        "workspace" => %{
          "links" => %{
            "avatar" => %{
              "href" => "https://bitbucket.org/workspaces/milana_stojadinov/avatar/?ts=1543639881"
            },
            "html" => %{"href" => "https://bitbucket.org/milana_stojadinov/"},
            "self" => %{"href" => "https://api.bitbucket.org/2.0/workspaces/milana_stojadinov"}
          },
          "name" => "Milana Stojadinov",
          "slug" => "milana_stojadinov",
          "type" => "workspace",
          "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
        }
      }
    }
  end

  def pull_request_open do
    %{
      "actor" => %{
        "account_id" => "557058:a19b3000-9205-4825-983a-e223af783fd9",
        "display_name" => "Milana Stojadinov",
        "links" => %{
          "avatar" => %{
            "href" =>
              "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
          },
          "html" => %{
            "href" => "https://bitbucket.org/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D/"
          },
          "self" => %{
            "href" => "https://api.bitbucket.org/2.0/users/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D"
          }
        },
        "nickname" => "milana_stojadinov",
        "type" => "user",
        "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
      },
      "pullrequest" => %{
        "author" => %{
          "account_id" => "557058:a19b3000-9205-4825-983a-e223af783fd9",
          "display_name" => "Milana Stojadinov",
          "links" => %{
            "avatar" => %{
              "href" =>
                "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
            },
            "html" => %{
              "href" => "https://bitbucket.org/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D/"
            },
            "self" => %{
              "href" => "https://api.bitbucket.org/2.0/users/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D"
            }
          },
          "nickname" => "milana_stojadinov",
          "type" => "user",
          "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
        },
        "close_source_branch" => false,
        "closed_by" => nil,
        "comment_count" => 0,
        "created_on" => "2021-06-15T11:21:12.428214+00:00",
        "description" => "tsest",
        "destination" => %{
          "branch" => %{"name" => "master"},
          "commit" => %{
            "hash" => "c699bacf22af",
            "links" => %{
              "html" => %{
                "href" => "https://bitbucket.org/milana_stojadinov/elixir-project/commits/c699bacf22af"
              },
              "self" => %{
                "href" =>
                  "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/c699bacf22af"
              }
            },
            "type" => "commit"
          },
          "repository" => %{
            "full_name" => "milana_stojadinov/elixir-project",
            "links" => %{
              "avatar" => %{
                "href" => "https://bytebucket.org/ravatar/%7B730ede8d-c0de-4f85-aef1-133881a9624f%7D?ts=default"
              },
              "html" => %{"href" => "https://bitbucket.org/milana_stojadinov/elixir-project"},
              "self" => %{
                "href" => "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project"
              }
            },
            "name" => "elixir-project",
            "type" => "repository",
            "uuid" => "{730ede8d-c0de-4f85-aef1-133881a9624f}"
          }
        },
        "id" => 4,
        "links" => %{
          "activity" => %{
            "href" =>
              "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/pullrequests/4/activity"
          },
          "approve" => %{
            "href" =>
              "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/pullrequests/4/approve"
          },
          "comments" => %{
            "href" =>
              "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/pullrequests/4/comments"
          },
          "commits" => %{
            "href" =>
              "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/pullrequests/4/commits"
          },
          "decline" => %{
            "href" =>
              "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/pullrequests/4/decline"
          },
          "diff" => %{
            "href" =>
              "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/diff/milana_stojadinov/elixir-project:d2b7d8ca15ef%0Dc699bacf22af?from_pullrequest_id=4"
          },
          "diffstat" => %{
            "href" =>
              "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/diffstat/milana_stojadinov/elixir-project:d2b7d8ca15ef%0Dc699bacf22af?from_pullrequest_id=4"
          },
          "html" => %{
            "href" => "https://bitbucket.org/milana_stojadinov/elixir-project/pull-requests/4"
          },
          "merge" => %{
            "href" => "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/pullrequests/4/merge"
          },
          "request-changes" => %{
            "href" =>
              "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/pullrequests/4/request-changes"
          },
          "self" => %{
            "href" => "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/pullrequests/4"
          },
          "statuses" => %{
            "href" =>
              "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/pullrequests/4/statuses"
          }
        },
        "merge_commit" => nil,
        "participants" => [],
        "reason" => "",
        "rendered" => %{
          "description" => %{
            "html" => "<p>tsest</p>",
            "markup" => "markdown",
            "raw" => "tsest",
            "type" => "rendered"
          },
          "title" => %{
            "html" => "<p>open pr</p>",
            "markup" => "markdown",
            "raw" => "open pr",
            "type" => "rendered"
          }
        },
        "reviewers" => [],
        "source" => %{
          "branch" => %{"name" => "push-new-branch"},
          "commit" => %{
            "hash" => "d2b7d8ca15ef",
            "links" => %{
              "html" => %{
                "href" => "https://bitbucket.org/milana_stojadinov/elixir-project/commits/d2b7d8ca15ef"
              },
              "self" => %{
                "href" =>
                  "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/d2b7d8ca15ef"
              }
            },
            "type" => "commit"
          },
          "repository" => %{
            "full_name" => "milana_stojadinov/elixir-project",
            "links" => %{
              "avatar" => %{
                "href" => "https://bytebucket.org/ravatar/%7B730ede8d-c0de-4f85-aef1-133881a9624f%7D?ts=default"
              },
              "html" => %{"href" => "https://bitbucket.org/milana_stojadinov/elixir-project"},
              "self" => %{
                "href" => "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project"
              }
            },
            "name" => "elixir-project",
            "type" => "repository",
            "uuid" => "{730ede8d-c0de-4f85-aef1-133881a9624f}"
          }
        },
        "state" => "OPEN",
        "summary" => %{
          "html" => "<p>tsest</p>",
          "markup" => "markdown",
          "raw" => "tsest",
          "type" => "rendered"
        },
        "task_count" => 0,
        "title" => "open pr",
        "type" => "pullrequest",
        "updated_on" => "2021-06-15T11:21:12.941786+00:00"
      },
      "repository" => %{
        "full_name" => "milana_stojadinov/elixir-project",
        "is_private" => true,
        "links" => %{
          "avatar" => %{
            "href" => "https://bytebucket.org/ravatar/%7B730ede8d-c0de-4f85-aef1-133881a9624f%7D?ts=default"
          },
          "html" => %{"href" => "https://bitbucket.org/milana_stojadinov/elixir-project"},
          "self" => %{
            "href" => "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project"
          }
        },
        "name" => "elixir-project",
        "owner" => %{
          "account_id" => "557058:a19b3000-9205-4825-983a-e223af783fd9",
          "display_name" => "Milana Stojadinov",
          "links" => %{
            "avatar" => %{
              "href" =>
                "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
            },
            "html" => %{
              "href" => "https://bitbucket.org/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D/"
            },
            "self" => %{
              "href" => "https://api.bitbucket.org/2.0/users/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D"
            }
          },
          "nickname" => "milana_stojadinov",
          "type" => "user",
          "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
        },
        "project" => %{
          "key" => "WEB",
          "links" => %{
            "avatar" => %{
              "href" => "https://bitbucket.org/account/user/milana_stojadinov/projects/WEB/avatar/32?ts=1623417282"
            },
            "html" => %{
              "href" => "https://bitbucket.org/milana_stojadinov/workspace/projects/WEB"
            },
            "self" => %{
              "href" => "https://api.bitbucket.org/2.0/workspaces/milana_stojadinov/projects/WEB"
            }
          },
          "name" => "webhooks-test",
          "type" => "project",
          "uuid" => "{1e6187d8-23a6-47fe-9a3d-328fbf61f572}"
        },
        "scm" => "git",
        "type" => "repository",
        "uuid" => "{730ede8d-c0de-4f85-aef1-133881a9624f}",
        "website" => "",
        "workspace" => %{
          "links" => %{
            "avatar" => %{
              "href" => "https://bitbucket.org/workspaces/milana_stojadinov/avatar/?ts=1543639881"
            },
            "html" => %{"href" => "https://bitbucket.org/milana_stojadinov/"},
            "self" => %{"href" => "https://api.bitbucket.org/2.0/workspaces/milana_stojadinov"}
          },
          "name" => "Milana Stojadinov",
          "slug" => "milana_stojadinov",
          "type" => "workspace",
          "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
        }
      }
    }
  end

  def pull_request_closed do
    %{
      "actor" => %{
        "account_id" => "557058:a19b3000-9205-4825-983a-e223af783fd9",
        "display_name" => "Milana Stojadinov",
        "links" => %{
          "avatar" => %{
            "href" =>
              "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
          },
          "html" => %{
            "href" => "https://bitbucket.org/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D/"
          },
          "self" => %{
            "href" => "https://api.bitbucket.org/2.0/users/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D"
          }
        },
        "nickname" => "milana_stojadinov",
        "type" => "user",
        "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
      },
      "pullrequest" => %{
        "author" => %{
          "account_id" => "557058:a19b3000-9205-4825-983a-e223af783fd9",
          "display_name" => "Milana Stojadinov",
          "links" => %{
            "avatar" => %{
              "href" =>
                "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
            },
            "html" => %{
              "href" => "https://bitbucket.org/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D/"
            },
            "self" => %{
              "href" => "https://api.bitbucket.org/2.0/users/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D"
            }
          },
          "nickname" => "milana_stojadinov",
          "type" => "user",
          "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
        },
        "close_source_branch" => false,
        "closed_by" => %{
          "account_id" => "557058:a19b3000-9205-4825-983a-e223af783fd9",
          "display_name" => "Milana Stojadinov",
          "links" => %{
            "avatar" => %{
              "href" =>
                "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
            },
            "html" => %{
              "href" => "https://bitbucket.org/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D/"
            },
            "self" => %{
              "href" => "https://api.bitbucket.org/2.0/users/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D"
            }
          },
          "nickname" => "milana_stojadinov",
          "type" => "user",
          "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
        },
        "comment_count" => 0,
        "created_on" => "2021-06-15T11:21:12.428214+00:00",
        "description" => "tsest",
        "destination" => %{
          "branch" => %{"name" => "master"},
          "commit" => %{
            "hash" => "c699bacf22af",
            "links" => %{
              "html" => %{
                "href" => "https://bitbucket.org/milana_stojadinov/elixir-project/commits/c699bacf22af"
              },
              "self" => %{
                "href" =>
                  "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/c699bacf22af"
              }
            },
            "type" => "commit"
          },
          "repository" => %{
            "full_name" => "milana_stojadinov/elixir-project",
            "links" => %{
              "avatar" => %{
                "href" => "https://bytebucket.org/ravatar/%7B730ede8d-c0de-4f85-aef1-133881a9624f%7D?ts=default"
              },
              "html" => %{"href" => "https://bitbucket.org/milana_stojadinov/elixir-project"},
              "self" => %{
                "href" => "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project"
              }
            },
            "name" => "elixir-project",
            "type" => "repository",
            "uuid" => "{730ede8d-c0de-4f85-aef1-133881a9624f}"
          }
        },
        "id" => 4,
        "links" => %{
          "activity" => %{
            "href" =>
              "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/pullrequests/4/activity"
          },
          "approve" => %{
            "href" =>
              "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/pullrequests/4/approve"
          },
          "comments" => %{
            "href" =>
              "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/pullrequests/4/comments"
          },
          "commits" => %{
            "href" =>
              "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/pullrequests/4/commits"
          },
          "decline" => %{
            "href" =>
              "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/pullrequests/4/decline"
          },
          "diff" => %{
            "href" =>
              "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/diff/milana_stojadinov/elixir-project:d2b7d8ca15ef%0Dc699bacf22af?from_pullrequest_id=4"
          },
          "diffstat" => %{
            "href" =>
              "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/diffstat/milana_stojadinov/elixir-project:d2b7d8ca15ef%0Dc699bacf22af?from_pullrequest_id=4"
          },
          "html" => %{
            "href" => "https://bitbucket.org/milana_stojadinov/elixir-project/pull-requests/4"
          },
          "merge" => %{
            "href" => "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/pullrequests/4/merge"
          },
          "request-changes" => %{
            "href" =>
              "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/pullrequests/4/request-changes"
          },
          "self" => %{
            "href" => "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/pullrequests/4"
          },
          "statuses" => %{
            "href" =>
              "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/pullrequests/4/statuses"
          }
        },
        "merge_commit" => nil,
        "participants" => [],
        "reason" => "",
        "rendered" => %{
          "description" => %{
            "html" => "<p>tsest</p>",
            "markup" => "markdown",
            "raw" => "tsest",
            "type" => "rendered"
          },
          "title" => %{
            "html" => "<p>open pr</p>",
            "markup" => "markdown",
            "raw" => "open pr",
            "type" => "rendered"
          }
        },
        "reviewers" => [],
        "source" => %{
          "branch" => %{"name" => "push-new-branch"},
          "commit" => %{
            "hash" => "d2b7d8ca15ef",
            "links" => %{
              "html" => %{
                "href" => "https://bitbucket.org/milana_stojadinov/elixir-project/commits/d2b7d8ca15ef"
              },
              "self" => %{
                "href" =>
                  "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/d2b7d8ca15ef"
              }
            },
            "type" => "commit"
          },
          "repository" => %{
            "full_name" => "milana_stojadinov/elixir-project",
            "links" => %{
              "avatar" => %{
                "href" => "https://bytebucket.org/ravatar/%7B730ede8d-c0de-4f85-aef1-133881a9624f%7D?ts=default"
              },
              "html" => %{"href" => "https://bitbucket.org/milana_stojadinov/elixir-project"},
              "self" => %{
                "href" => "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project"
              }
            },
            "name" => "elixir-project",
            "type" => "repository",
            "uuid" => "{730ede8d-c0de-4f85-aef1-133881a9624f}"
          }
        },
        "state" => "DECLINED",
        "summary" => %{
          "html" => "<p>tsest</p>",
          "markup" => "markdown",
          "raw" => "tsest",
          "type" => "rendered"
        },
        "task_count" => 0,
        "title" => "open pr",
        "type" => "pullrequest",
        "updated_on" => "2021-06-15T11:23:47.294192+00:00"
      },
      "repository" => %{
        "full_name" => "milana_stojadinov/elixir-project",
        "is_private" => true,
        "links" => %{
          "avatar" => %{
            "href" => "https://bytebucket.org/ravatar/%7B730ede8d-c0de-4f85-aef1-133881a9624f%7D?ts=default"
          },
          "html" => %{"href" => "https://bitbucket.org/milana_stojadinov/elixir-project"},
          "self" => %{
            "href" => "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project"
          }
        },
        "name" => "elixir-project",
        "owner" => %{
          "account_id" => "557058:a19b3000-9205-4825-983a-e223af783fd9",
          "display_name" => "Milana Stojadinov",
          "links" => %{
            "avatar" => %{
              "href" =>
                "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
            },
            "html" => %{
              "href" => "https://bitbucket.org/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D/"
            },
            "self" => %{
              "href" => "https://api.bitbucket.org/2.0/users/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D"
            }
          },
          "nickname" => "milana_stojadinov",
          "type" => "user",
          "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
        },
        "project" => %{
          "key" => "WEB",
          "links" => %{
            "avatar" => %{
              "href" => "https://bitbucket.org/account/user/milana_stojadinov/projects/WEB/avatar/32?ts=1623417282"
            },
            "html" => %{
              "href" => "https://bitbucket.org/milana_stojadinov/workspace/projects/WEB"
            },
            "self" => %{
              "href" => "https://api.bitbucket.org/2.0/workspaces/milana_stojadinov/projects/WEB"
            }
          },
          "name" => "webhooks-test",
          "type" => "project",
          "uuid" => "{1e6187d8-23a6-47fe-9a3d-328fbf61f572}"
        },
        "scm" => "git",
        "type" => "repository",
        "uuid" => "{730ede8d-c0de-4f85-aef1-133881a9624f}",
        "website" => "",
        "workspace" => %{
          "links" => %{
            "avatar" => %{
              "href" => "https://bitbucket.org/workspaces/milana_stojadinov/avatar/?ts=1543639881"
            },
            "html" => %{"href" => "https://bitbucket.org/milana_stojadinov/"},
            "self" => %{"href" => "https://api.bitbucket.org/2.0/workspaces/milana_stojadinov"}
          },
          "name" => "Milana Stojadinov",
          "slug" => "milana_stojadinov",
          "type" => "workspace",
          "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
        }
      }
    }
  end

  def push_to_a_branch_with_pr do
    %{
      "actor" => %{
        "account_id" => "557058:a19b3000-9205-4825-983a-e223af783fd9",
        "display_name" => "Milana Stojadinov",
        "links" => %{
          "avatar" => %{
            "href" =>
              "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
          },
          "html" => %{
            "href" => "https://bitbucket.org/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D/"
          },
          "self" => %{
            "href" => "https://api.bitbucket.org/2.0/users/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D"
          }
        },
        "nickname" => "milana_stojadinov",
        "type" => "user",
        "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
      },
      "push" => %{
        "changes" => [
          %{
            "closed" => false,
            "commits" => [
              %{
                "author" => %{
                  "raw" => "Milana Stojadinov <milana.stojadinov@gmail.com>",
                  "type" => "author",
                  "user" => %{
                    "account_id" => "557058:a19b3000-9205-4825-983a-e223af783fd9",
                    "display_name" => "Milana Stojadinov",
                    "links" => %{
                      "avatar" => %{
                        "href" =>
                          "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
                      },
                      "html" => %{
                        "href" => "https://bitbucket.org/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D/"
                      },
                      "self" => %{
                        "href" => "https://api.bitbucket.org/2.0/users/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D"
                      }
                    },
                    "nickname" => "milana_stojadinov",
                    "type" => "user",
                    "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
                  }
                },
                "date" => "2021-06-15T11:36:48+00:00",
                "hash" => "c2863cab3c8e838394cfdd6e4b4bfbfcddb1d354",
                "links" => %{
                  "approve" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/c2863cab3c8e838394cfdd6e4b4bfbfcddb1d354/approve"
                  },
                  "comments" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/c2863cab3c8e838394cfdd6e4b4bfbfcddb1d354/comments"
                  },
                  "diff" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/diff/c2863cab3c8e838394cfdd6e4b4bfbfcddb1d354"
                  },
                  "html" => %{
                    "href" =>
                      "https://bitbucket.org/milana_stojadinov/elixir-project/commits/c2863cab3c8e838394cfdd6e4b4bfbfcddb1d354"
                  },
                  "patch" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/patch/c2863cab3c8e838394cfdd6e4b4bfbfcddb1d354"
                  },
                  "self" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/c2863cab3c8e838394cfdd6e4b4bfbfcddb1d354"
                  },
                  "statuses" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/c2863cab3c8e838394cfdd6e4b4bfbfcddb1d354/statuses"
                  }
                },
                "message" => "Push commit on branch with PR\n",
                "parents" => [
                  %{
                    "hash" => "d2b7d8ca15effafc1a24ac5fd099f34b5447c9ad",
                    "links" => %{
                      "html" => %{
                        "href" =>
                          "https://bitbucket.org/milana_stojadinov/elixir-project/commits/d2b7d8ca15effafc1a24ac5fd099f34b5447c9ad"
                      },
                      "self" => %{
                        "href" =>
                          "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/d2b7d8ca15effafc1a24ac5fd099f34b5447c9ad"
                      }
                    },
                    "type" => "commit"
                  }
                ],
                "properties" => %{},
                "rendered" => %{},
                "summary" => %{
                  "html" => "<p>Push commit on branch with PR</p>",
                  "markup" => "markdown",
                  "raw" => "Push commit on branch with PR\n",
                  "type" => "rendered"
                },
                "type" => "commit"
              }
            ],
            "created" => false,
            "forced" => false,
            "links" => %{
              "commits" => %{
                "href" =>
                  "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commits?include=c2863cab3c8e838394cfdd6e4b4bfbfcddb1d354&exclude=d2b7d8ca15effafc1a24ac5fd099f34b5447c9ad"
              },
              "diff" => %{
                "href" =>
                  "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/diff/c2863cab3c8e838394cfdd6e4b4bfbfcddb1d354..d2b7d8ca15effafc1a24ac5fd099f34b5447c9ad"
              },
              "html" => %{
                "href" =>
                  "https://bitbucket.org/milana_stojadinov/elixir-project/branches/compare/c2863cab3c8e838394cfdd6e4b4bfbfcddb1d354..d2b7d8ca15effafc1a24ac5fd099f34b5447c9ad"
              }
            },
            "new" => %{
              "default_merge_strategy" => "merge_commit",
              "links" => %{
                "commits" => %{
                  "href" =>
                    "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commits/push-new-branch"
                },
                "html" => %{
                  "href" => "https://bitbucket.org/milana_stojadinov/elixir-project/branch/push-new-branch"
                },
                "self" => %{
                  "href" =>
                    "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/refs/branches/push-new-branch"
                }
              },
              "merge_strategies" => ["merge_commit", "squash", "fast_forward"],
              "name" => "push-new-branch",
              "target" => %{
                "author" => %{
                  "raw" => "Milana Stojadinov <milana.stojadinov@gmail.com>",
                  "type" => "author",
                  "user" => %{
                    "account_id" => "557058:a19b3000-9205-4825-983a-e223af783fd9",
                    "display_name" => "Milana Stojadinov",
                    "links" => %{
                      "avatar" => %{
                        "href" =>
                          "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
                      },
                      "html" => %{
                        "href" => "https://bitbucket.org/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D/"
                      },
                      "self" => %{
                        "href" => "https://api.bitbucket.org/2.0/users/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D"
                      }
                    },
                    "nickname" => "milana_stojadinov",
                    "type" => "user",
                    "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
                  }
                },
                "date" => "2021-06-15T11:36:48+00:00",
                "hash" => "c2863cab3c8e838394cfdd6e4b4bfbfcddb1d354",
                "links" => %{
                  "html" => %{
                    "href" =>
                      "https://bitbucket.org/milana_stojadinov/elixir-project/commits/c2863cab3c8e838394cfdd6e4b4bfbfcddb1d354"
                  },
                  "self" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/c2863cab3c8e838394cfdd6e4b4bfbfcddb1d354"
                  }
                },
                "message" => "Push commit on branch with PR\n",
                "parents" => [
                  %{
                    "hash" => "d2b7d8ca15effafc1a24ac5fd099f34b5447c9ad",
                    "links" => %{
                      "html" => %{
                        "href" =>
                          "https://bitbucket.org/milana_stojadinov/elixir-project/commits/d2b7d8ca15effafc1a24ac5fd099f34b5447c9ad"
                      },
                      "self" => %{
                        "href" =>
                          "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/d2b7d8ca15effafc1a24ac5fd099f34b5447c9ad"
                      }
                    },
                    "type" => "commit"
                  }
                ],
                "properties" => %{},
                "rendered" => %{},
                "summary" => %{
                  "html" => "<p>Push commit on branch with PR</p>",
                  "markup" => "markdown",
                  "raw" => "Push commit on branch with PR\n",
                  "type" => "rendered"
                },
                "type" => "commit"
              },
              "type" => "branch"
            },
            "old" => %{
              "default_merge_strategy" => "merge_commit",
              "links" => %{
                "commits" => %{
                  "href" =>
                    "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commits/push-new-branch"
                },
                "html" => %{
                  "href" => "https://bitbucket.org/milana_stojadinov/elixir-project/branch/push-new-branch"
                },
                "self" => %{
                  "href" =>
                    "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/refs/branches/push-new-branch"
                }
              },
              "merge_strategies" => ["merge_commit", "squash", "fast_forward"],
              "name" => "push-new-branch",
              "target" => %{
                "author" => %{
                  "raw" => "Milana Stojadinov <milana.stojadinov@gmail.com>",
                  "type" => "author",
                  "user" => %{
                    "account_id" => "557058:a19b3000-9205-4825-983a-e223af783fd9",
                    "display_name" => "Milana Stojadinov",
                    "links" => %{
                      "avatar" => %{
                        "href" =>
                          "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
                      },
                      "html" => %{
                        "href" => "https://bitbucket.org/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D/"
                      },
                      "self" => %{
                        "href" => "https://api.bitbucket.org/2.0/users/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D"
                      }
                    },
                    "nickname" => "milana_stojadinov",
                    "type" => "user",
                    "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
                  }
                },
                "date" => "2021-06-11T16:01:26+00:00",
                "hash" => "d2b7d8ca15effafc1a24ac5fd099f34b5447c9ad",
                "links" => %{
                  "html" => %{
                    "href" =>
                      "https://bitbucket.org/milana_stojadinov/elixir-project/commits/d2b7d8ca15effafc1a24ac5fd099f34b5447c9ad"
                  },
                  "self" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/d2b7d8ca15effafc1a24ac5fd099f34b5447c9ad"
                  }
                },
                "message" => "Update readme\n",
                "parents" => [
                  %{
                    "hash" => "c699bacf22afa6f423ec4bc09da26a127559bc9a",
                    "links" => %{
                      "html" => %{
                        "href" =>
                          "https://bitbucket.org/milana_stojadinov/elixir-project/commits/c699bacf22afa6f423ec4bc09da26a127559bc9a"
                      },
                      "self" => %{
                        "href" =>
                          "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/c699bacf22afa6f423ec4bc09da26a127559bc9a"
                      }
                    },
                    "type" => "commit"
                  }
                ],
                "properties" => %{},
                "rendered" => %{},
                "summary" => %{
                  "html" => "<p>Update readme</p>",
                  "markup" => "markdown",
                  "raw" => "Update readme\n",
                  "type" => "rendered"
                },
                "type" => "commit"
              },
              "type" => "branch"
            },
            "truncated" => false
          }
        ]
      },
      "repository" => %{
        "full_name" => "milana_stojadinov/elixir-project",
        "is_private" => true,
        "links" => %{
          "avatar" => %{
            "href" => "https://bytebucket.org/ravatar/%7B730ede8d-c0de-4f85-aef1-133881a9624f%7D?ts=default"
          },
          "html" => %{"href" => "https://bitbucket.org/milana_stojadinov/elixir-project"},
          "self" => %{
            "href" => "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project"
          }
        },
        "name" => "elixir-project",
        "owner" => %{
          "account_id" => "557058:a19b3000-9205-4825-983a-e223af783fd9",
          "display_name" => "Milana Stojadinov",
          "links" => %{
            "avatar" => %{
              "href" =>
                "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
            },
            "html" => %{
              "href" => "https://bitbucket.org/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D/"
            },
            "self" => %{
              "href" => "https://api.bitbucket.org/2.0/users/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D"
            }
          },
          "nickname" => "milana_stojadinov",
          "type" => "user",
          "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
        },
        "project" => %{
          "key" => "WEB",
          "links" => %{
            "avatar" => %{
              "href" => "https://bitbucket.org/account/user/milana_stojadinov/projects/WEB/avatar/32?ts=1623417282"
            },
            "html" => %{
              "href" => "https://bitbucket.org/milana_stojadinov/workspace/projects/WEB"
            },
            "self" => %{
              "href" => "https://api.bitbucket.org/2.0/workspaces/milana_stojadinov/projects/WEB"
            }
          },
          "name" => "webhooks-test",
          "type" => "project",
          "uuid" => "{1e6187d8-23a6-47fe-9a3d-328fbf61f572}"
        },
        "scm" => "git",
        "type" => "repository",
        "uuid" => "{730ede8d-c0de-4f85-aef1-133881a9624f}",
        "website" => "",
        "workspace" => %{
          "links" => %{
            "avatar" => %{
              "href" => "https://bitbucket.org/workspaces/milana_stojadinov/avatar/?ts=1543639881"
            },
            "html" => %{"href" => "https://bitbucket.org/milana_stojadinov/"},
            "self" => %{"href" => "https://api.bitbucket.org/2.0/workspaces/milana_stojadinov"}
          },
          "name" => "Milana Stojadinov",
          "slug" => "milana_stojadinov",
          "type" => "workspace",
          "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
        }
      }
    }
  end

  def branch_push_skip_ci do
    %{
      "actor" => %{
        "account_id" => "557058:a19b3000-9205-4825-983a-e223af783fd9",
        "display_name" => "Milana Stojadinov",
        "links" => %{
          "avatar" => %{
            "href" =>
              "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
          },
          "html" => %{
            "href" => "https://bitbucket.org/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D/"
          },
          "self" => %{
            "href" => "https://api.bitbucket.org/2.0/users/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D"
          }
        },
        "nickname" => "milana_stojadinov",
        "type" => "user",
        "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
      },
      "push" => %{
        "changes" => [
          %{
            "closed" => false,
            "commits" => [
              %{
                "author" => %{
                  "raw" => "Milana Stojadinov <milana.stojadinov@gmail.com>",
                  "type" => "author",
                  "user" => %{
                    "account_id" => "557058:a19b3000-9205-4825-983a-e223af783fd9",
                    "display_name" => "Milana Stojadinov",
                    "links" => %{
                      "avatar" => %{
                        "href" =>
                          "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
                      },
                      "html" => %{
                        "href" => "https://bitbucket.org/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D/"
                      },
                      "self" => %{
                        "href" => "https://api.bitbucket.org/2.0/users/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D"
                      }
                    },
                    "nickname" => "milana_stojadinov",
                    "type" => "user",
                    "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
                  }
                },
                "date" => "2021-06-15T10:45:59+00:00",
                "hash" => "175d0109daf6f1bb2489b9bb4ac6809a3ea2c11d",
                "links" => %{
                  "approve" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/175d0109daf6f1bb2489b9bb4ac6809a3ea2c11d/approve"
                  },
                  "comments" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/175d0109daf6f1bb2489b9bb4ac6809a3ea2c11d/comments"
                  },
                  "diff" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/diff/175d0109daf6f1bb2489b9bb4ac6809a3ea2c11d"
                  },
                  "html" => %{
                    "href" =>
                      "https://bitbucket.org/milana_stojadinov/elixir-project/commits/175d0109daf6f1bb2489b9bb4ac6809a3ea2c11d"
                  },
                  "patch" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/patch/175d0109daf6f1bb2489b9bb4ac6809a3ea2c11d"
                  },
                  "self" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/175d0109daf6f1bb2489b9bb4ac6809a3ea2c11d"
                  },
                  "statuses" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/175d0109daf6f1bb2489b9bb4ac6809a3ea2c11d/statuses"
                  }
                },
                "message" => "Push commit [skip ci]\n",
                "parents" => [
                  %{
                    "hash" => "d3da4886495b865f836a0c77daa9c8e080b136d1",
                    "links" => %{
                      "html" => %{
                        "href" =>
                          "https://bitbucket.org/milana_stojadinov/elixir-project/commits/d3da4886495b865f836a0c77daa9c8e080b136d1"
                      },
                      "self" => %{
                        "href" =>
                          "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/d3da4886495b865f836a0c77daa9c8e080b136d1"
                      }
                    },
                    "type" => "commit"
                  }
                ],
                "properties" => %{},
                "rendered" => %{},
                "summary" => %{
                  "html" => "<p>Push commit [skip ci]</p>",
                  "markup" => "markdown",
                  "raw" => "Push commit\n",
                  "type" => "rendered"
                },
                "type" => "commit"
              }
            ],
            "created" => false,
            "forced" => false,
            "links" => %{
              "commits" => %{
                "href" =>
                  "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commits?include=175d0109daf6f1bb2489b9bb4ac6809a3ea2c11d&exclude=d3da4886495b865f836a0c77daa9c8e080b136d1"
              },
              "diff" => %{
                "href" =>
                  "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/diff/175d0109daf6f1bb2489b9bb4ac6809a3ea2c11d..d3da4886495b865f836a0c77daa9c8e080b136d1"
              },
              "html" => %{
                "href" =>
                  "https://bitbucket.org/milana_stojadinov/elixir-project/branches/compare/175d0109daf6f1bb2489b9bb4ac6809a3ea2c11d..d3da4886495b865f836a0c77daa9c8e080b136d1"
              }
            },
            "new" => %{
              "default_merge_strategy" => "merge_commit",
              "links" => %{
                "commits" => %{
                  "href" =>
                    "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commits/new-branch-push-new-commits"
                },
                "html" => %{
                  "href" => "https://bitbucket.org/milana_stojadinov/elixir-project/branch/new-branch-push-new-commits"
                },
                "self" => %{
                  "href" =>
                    "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/refs/branches/new-branch-push-new-commits"
                }
              },
              "merge_strategies" => ["merge_commit", "squash", "fast_forward"],
              "name" => "new-branch-push-new-commits",
              "target" => %{
                "author" => %{
                  "raw" => "Milana Stojadinov <milana.stojadinov@gmail.com>",
                  "type" => "author",
                  "user" => %{
                    "account_id" => "557058:a19b3000-9205-4825-983a-e223af783fd9",
                    "display_name" => "Milana Stojadinov",
                    "links" => %{
                      "avatar" => %{
                        "href" =>
                          "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
                      },
                      "html" => %{
                        "href" => "https://bitbucket.org/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D/"
                      },
                      "self" => %{
                        "href" => "https://api.bitbucket.org/2.0/users/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D"
                      }
                    },
                    "nickname" => "milana_stojadinov",
                    "type" => "user",
                    "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
                  }
                },
                "date" => "2021-06-15T10:45:59+00:00",
                "hash" => "175d0109daf6f1bb2489b9bb4ac6809a3ea2c11d",
                "links" => %{
                  "html" => %{
                    "href" =>
                      "https://bitbucket.org/milana_stojadinov/elixir-project/commits/175d0109daf6f1bb2489b9bb4ac6809a3ea2c11d"
                  },
                  "self" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/175d0109daf6f1bb2489b9bb4ac6809a3ea2c11d"
                  }
                },
                "message" => "Push commit [skip ci]\n",
                "parents" => [
                  %{
                    "hash" => "d3da4886495b865f836a0c77daa9c8e080b136d1",
                    "links" => %{
                      "html" => %{
                        "href" =>
                          "https://bitbucket.org/milana_stojadinov/elixir-project/commits/d3da4886495b865f836a0c77daa9c8e080b136d1"
                      },
                      "self" => %{
                        "href" =>
                          "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/d3da4886495b865f836a0c77daa9c8e080b136d1"
                      }
                    },
                    "type" => "commit"
                  }
                ],
                "properties" => %{},
                "rendered" => %{},
                "summary" => %{
                  "html" => "<p>Push commit [skip ci]</p>",
                  "markup" => "markdown",
                  "raw" => "Push commit [skip ci]\n",
                  "type" => "rendered"
                },
                "type" => "commit"
              },
              "type" => "branch"
            },
            "old" => %{
              "default_merge_strategy" => "merge_commit",
              "links" => %{
                "commits" => %{
                  "href" =>
                    "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commits/new-branch-push-new-commits"
                },
                "html" => %{
                  "href" => "https://bitbucket.org/milana_stojadinov/elixir-project/branch/new-branch-push-new-commits"
                },
                "self" => %{
                  "href" =>
                    "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/refs/branches/new-branch-push-new-commits"
                }
              },
              "merge_strategies" => ["merge_commit", "squash", "fast_forward"],
              "name" => "new-branch-push-new-commits",
              "target" => %{
                "author" => %{
                  "raw" => "Milana Stojadinov <milana.stojadinov@gmail.com>",
                  "type" => "author",
                  "user" => %{
                    "account_id" => "557058:a19b3000-9205-4825-983a-e223af783fd9",
                    "display_name" => "Milana Stojadinov",
                    "links" => %{
                      "avatar" => %{
                        "href" =>
                          "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
                      },
                      "html" => %{
                        "href" => "https://bitbucket.org/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D/"
                      },
                      "self" => %{
                        "href" => "https://api.bitbucket.org/2.0/users/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D"
                      }
                    },
                    "nickname" => "milana_stojadinov",
                    "type" => "user",
                    "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
                  }
                },
                "date" => "2021-06-15T10:40:21+00:00",
                "hash" => "d3da4886495b865f836a0c77daa9c8e080b136d1",
                "links" => %{
                  "html" => %{
                    "href" =>
                      "https://bitbucket.org/milana_stojadinov/elixir-project/commits/d3da4886495b865f836a0c77daa9c8e080b136d1"
                  },
                  "self" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/d3da4886495b865f836a0c77daa9c8e080b136d1"
                  }
                },
                "message" => "Push new commit - force push\n",
                "parents" => [
                  %{
                    "hash" => "2a585bde481f0d5b3a10b10997210b6eb4893897",
                    "links" => %{
                      "html" => %{
                        "href" =>
                          "https://bitbucket.org/milana_stojadinov/elixir-project/commits/2a585bde481f0d5b3a10b10997210b6eb4893897"
                      },
                      "self" => %{
                        "href" =>
                          "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/2a585bde481f0d5b3a10b10997210b6eb4893897"
                      }
                    },
                    "type" => "commit"
                  }
                ],
                "properties" => %{},
                "rendered" => %{},
                "summary" => %{
                  "html" => "<p>Push new commit - force push</p>",
                  "markup" => "markdown",
                  "raw" => "Push new commit - force push\n",
                  "type" => "rendered"
                },
                "type" => "commit"
              },
              "type" => "branch"
            },
            "truncated" => false
          }
        ]
      },
      "repository" => %{
        "full_name" => "milana_stojadinov/elixir-project",
        "is_private" => true,
        "links" => %{
          "avatar" => %{
            "href" => "https://bytebucket.org/ravatar/%7B730ede8d-c0de-4f85-aef1-133881a9624f%7D?ts=default"
          },
          "html" => %{"href" => "https://bitbucket.org/milana_stojadinov/elixir-project"},
          "self" => %{
            "href" => "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project"
          }
        },
        "name" => "elixir-project",
        "owner" => %{
          "account_id" => "557058:a19b3000-9205-4825-983a-e223af783fd9",
          "display_name" => "Milana Stojadinov",
          "links" => %{
            "avatar" => %{
              "href" =>
                "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
            },
            "html" => %{
              "href" => "https://bitbucket.org/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D/"
            },
            "self" => %{
              "href" => "https://api.bitbucket.org/2.0/users/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D"
            }
          },
          "nickname" => "milana_stojadinov",
          "type" => "user",
          "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
        },
        "project" => %{
          "key" => "WEB",
          "links" => %{
            "avatar" => %{
              "href" => "https://bitbucket.org/account/user/milana_stojadinov/projects/WEB/avatar/32?ts=1623417282"
            },
            "html" => %{
              "href" => "https://bitbucket.org/milana_stojadinov/workspace/projects/WEB"
            },
            "self" => %{
              "href" => "https://api.bitbucket.org/2.0/workspaces/milana_stojadinov/projects/WEB"
            }
          },
          "name" => "webhooks-test",
          "type" => "project",
          "uuid" => "{1e6187d8-23a6-47fe-9a3d-328fbf61f572}"
        },
        "scm" => "git",
        "type" => "repository",
        "uuid" => "{730ede8d-c0de-4f85-aef1-133881a9624f}",
        "website" => "",
        "workspace" => %{
          "links" => %{
            "avatar" => %{
              "href" => "https://bitbucket.org/workspaces/milana_stojadinov/avatar/?ts=1543639881"
            },
            "html" => %{"href" => "https://bitbucket.org/milana_stojadinov/"},
            "self" => %{"href" => "https://api.bitbucket.org/2.0/workspaces/milana_stojadinov"}
          },
          "name" => "Milana Stojadinov",
          "slug" => "milana_stojadinov",
          "type" => "workspace",
          "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
        }
      }
    }
  end

  def tag_push_skip_ci do
    %{
      "actor" => %{
        "account_id" => "557058:a19b3000-9205-4825-983a-e223af783fd9",
        "display_name" => "Milana Stojadinov",
        "links" => %{
          "avatar" => %{
            "href" =>
              "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
          },
          "html" => %{
            "href" => "https://bitbucket.org/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D/"
          },
          "self" => %{
            "href" => "https://api.bitbucket.org/2.0/users/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D"
          }
        },
        "nickname" => "milana_stojadinov",
        "type" => "user",
        "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
      },
      "push" => %{
        "changes" => [
          %{
            "closed" => false,
            "created" => true,
            "forced" => false,
            "links" => %{
              "commits" => %{
                "href" =>
                  "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commits?include=175d0109daf6f1bb2489b9bb4ac6809a3ea2c11d"
              }
            },
            "new" => %{
              "date" => "2021-06-15T10:58:28+00:00",
              "links" => %{
                "commits" => %{
                  "href" => "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commits/v1.6"
                },
                "html" => %{
                  "href" => "https://bitbucket.org/milana_stojadinov/elixir-project/commits/tag/v1.6"
                },
                "self" => %{
                  "href" => "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/refs/tags/v1.6"
                }
              },
              "message" => "my version 1.6\n",
              "name" => "v1.6",
              "tagger" => %{},
              "target" => %{
                "author" => %{
                  "raw" => "Milana Stojadinov <milana.stojadinov@gmail.com>",
                  "type" => "author",
                  "user" => %{
                    "account_id" => "557058:a19b3000-9205-4825-983a-e223af783fd9",
                    "display_name" => "Milana Stojadinov",
                    "links" => %{
                      "avatar" => %{
                        "href" =>
                          "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
                      },
                      "html" => %{
                        "href" => "https://bitbucket.org/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D/"
                      },
                      "self" => %{
                        "href" => "https://api.bitbucket.org/2.0/users/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D"
                      }
                    },
                    "nickname" => "milana_stojadinov",
                    "type" => "user",
                    "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
                  }
                },
                "date" => "2021-06-15T10:45:59+00:00",
                "hash" => "175d0109daf6f1bb2489b9bb4ac6809a3ea2c11d",
                "links" => %{
                  "html" => %{
                    "href" =>
                      "https://bitbucket.org/milana_stojadinov/elixir-project/commits/175d0109daf6f1bb2489b9bb4ac6809a3ea2c11d"
                  },
                  "self" => %{
                    "href" =>
                      "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/175d0109daf6f1bb2489b9bb4ac6809a3ea2c11d"
                  }
                },
                "message" => "Push commit [skip ci]\n",
                "parents" => [
                  %{
                    "hash" => "d3da4886495b865f836a0c77daa9c8e080b136d1",
                    "links" => %{
                      "html" => %{
                        "href" =>
                          "https://bitbucket.org/milana_stojadinov/elixir-project/commits/d3da4886495b865f836a0c77daa9c8e080b136d1"
                      },
                      "self" => %{
                        "href" =>
                          "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project/commit/d3da4886495b865f836a0c77daa9c8e080b136d1"
                      }
                    },
                    "type" => "commit"
                  }
                ],
                "properties" => %{},
                "rendered" => %{},
                "summary" => %{
                  "html" => "<p>Push commit [skip ci]</p>",
                  "markup" => "markdown",
                  "raw" => "Push commit [skip ci]\n",
                  "type" => "rendered"
                },
                "type" => "commit"
              },
              "type" => "tag"
            },
            "old" => nil,
            "truncated" => false
          }
        ]
      },
      "repository" => %{
        "full_name" => "milana_stojadinov/elixir-project",
        "is_private" => true,
        "links" => %{
          "avatar" => %{
            "href" => "https://bytebucket.org/ravatar/%7B730ede8d-c0de-4f85-aef1-133881a9624f%7D?ts=default"
          },
          "html" => %{"href" => "https://bitbucket.org/milana_stojadinov/elixir-project"},
          "self" => %{
            "href" => "https://api.bitbucket.org/2.0/repositories/milana_stojadinov/elixir-project"
          }
        },
        "name" => "elixir-project",
        "owner" => %{
          "account_id" => "557058:a19b3000-9205-4825-983a-e223af783fd9",
          "display_name" => "Milana Stojadinov",
          "links" => %{
            "avatar" => %{
              "href" =>
                "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
            },
            "html" => %{
              "href" => "https://bitbucket.org/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D/"
            },
            "self" => %{
              "href" => "https://api.bitbucket.org/2.0/users/%7B53c5afd4-936e-4ded-9b8a-398f527a33c9%7D"
            }
          },
          "nickname" => "milana_stojadinov",
          "type" => "user",
          "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
        },
        "project" => %{
          "key" => "WEB",
          "links" => %{
            "avatar" => %{
              "href" => "https://bitbucket.org/account/user/milana_stojadinov/projects/WEB/avatar/32?ts=1623417282"
            },
            "html" => %{
              "href" => "https://bitbucket.org/milana_stojadinov/workspace/projects/WEB"
            },
            "self" => %{
              "href" => "https://api.bitbucket.org/2.0/workspaces/milana_stojadinov/projects/WEB"
            }
          },
          "name" => "webhooks-test",
          "type" => "project",
          "uuid" => "{1e6187d8-23a6-47fe-9a3d-328fbf61f572}"
        },
        "scm" => "git",
        "type" => "repository",
        "uuid" => "{730ede8d-c0de-4f85-aef1-133881a9624f}",
        "website" => "",
        "workspace" => %{
          "links" => %{
            "avatar" => %{
              "href" => "https://bitbucket.org/workspaces/milana_stojadinov/avatar/?ts=1543639881"
            },
            "html" => %{"href" => "https://bitbucket.org/milana_stojadinov/"},
            "self" => %{"href" => "https://api.bitbucket.org/2.0/workspaces/milana_stojadinov"}
          },
          "name" => "Milana Stojadinov",
          "slug" => "milana_stojadinov",
          "type" => "workspace",
          "uuid" => "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
        }
      }
    }
  end
end
