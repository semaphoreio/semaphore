defmodule Zebra.Workers.JobRequestFactory.JobRequestTest do
  use Zebra.DataCase

  alias Zebra.Workers.JobRequestFactory.JobRequest

  describe ".sanitized?/1" do
    test "nil => true" do
      assert JobRequest.sanitized?(nil)
    end

    test "sanitized => false" do
      refute JobRequest.sanitized?(%{
               "env_vars" => [
                 %{"name" => "AWS_KEY", "value" => "bWFzdGVy"},
                 %{"name" => "GCP_KEY", "value" => "bWFzdGVy"},
                 %{"name" => "SEMAPHORE_GIT_BRANCH", "value" => "bWFzdGVy"},
                 %{"name" => "SEMAPHORE_GIT_REF_TYPE", "value" => "YnJhbmNo"}
               ]
             })

      refute JobRequest.sanitized?(%{
               "environment_variables" => [
                 %{
                   "name" => "AWS_KEY",
                   "encoding" => "base64",
                   "unencrypted_content" => "bWFzdGVy"
                 },
                 %{
                   "name" => "GCP_KEY",
                   "encoding" => "base64",
                   "unencrypted_content" => "bWFzdGVy"
                 },
                 %{
                   "name" => "SEMAPHORE_GIT_BRANCH",
                   "encoding" => "base64",
                   "unencrypted_content" => "bWFzdGVy"
                 },
                 %{
                   "name" => "SEMAPHORE_GIT_REF_TYPE",
                   "encoding" => "base64",
                   "unencrypted_content" => "YnJhbmNo"
                 }
               ]
             })
    end

    test "sanitized => true" do
      assert JobRequest.sanitized?(%{
               "env_vars" => [
                 %{"name" => "AWS_KEY", "value" => "{SANITIZED}"},
                 %{"name" => "GCP_KEY", "value" => "{SANITIZED}"},
                 %{"name" => "SEMAPHORE_GIT_BRANCH", "value" => "bWFzdGVy"},
                 %{"name" => "SEMAPHORE_GIT_REF_TYPE", "value" => "YnJhbmNo"}
               ]
             })

      assert JobRequest.sanitized?(%{
               "environment_variables" => [
                 %{
                   "name" => "AWS_KEY",
                   "encoding" => "base64",
                   "unencrypted_content" => "{SANITIZED}"
                 },
                 %{
                   "name" => "GCP_KEY",
                   "encoding" => "base64",
                   "unencrypted_content" => "{SANITIZED}"
                 },
                 %{
                   "name" => "SEMAPHORE_GIT_BRANCH",
                   "encoding" => "base64",
                   "unencrypted_content" => "bWFzdGVy"
                 },
                 %{
                   "name" => "SEMAPHORE_GIT_REF_TYPE",
                   "encoding" => "base64",
                   "unencrypted_content" => "YnJhbmNo"
                 }
               ]
             })

      assert JobRequest.sanitized?(%{})
    end
  end

  describe ".sanitize/1" do
    test "nil => nil" do
      assert is_nil(JobRequest.sanitize(nil))
    end

    test "sanitizes all non SEMAPHORE_* environment variables" do
      request = %{
        "env_vars" => [
          JobRequest.env_var("AWS_KEY", "very-sensitive"),
          JobRequest.env_var("GCP_KEY", "also-very-sensitive"),
          JobRequest.env_var("SEMAPHORE_GIT_BRANCH", "master"),
          JobRequest.env_var("SEMAPHORE_GIT_REF_TYPE", "branch")
        ]
      }

      assert %{
               "env_vars" => [
                 %{"name" => "AWS_KEY", "value" => "{SANITIZED}"},
                 %{"name" => "GCP_KEY", "value" => "{SANITIZED}"},
                 %{"name" => "SEMAPHORE_GIT_BRANCH", "value" => "bWFzdGVy"},
                 %{"name" => "SEMAPHORE_GIT_REF_TYPE", "value" => "YnJhbmNo"}
               ]
             } = JobRequest.sanitize(request)
    end

    test "sanitizes all non SEMAPHORE_* environment variables (old request)" do
      request = %{
        "environment_variables" => [
          %{
            "name" => "AWS_KEY",
            "encoding" => "base64",
            "unencrypted_content" => Base.encode64("very-sensitive")
          },
          %{
            "name" => "GCP_KEY",
            "encoding" => "base64",
            "unencrypted_content" => Base.encode64("also-very-sensitive")
          },
          %{
            "name" => "SEMAPHORE_GIT_BRANCH",
            "encoding" => "base64",
            "unencrypted_content" => Base.encode64("master")
          },
          %{
            "name" => "SEMAPHORE_GIT_REF_TYPE",
            "encoding" => "base64",
            "unencrypted_content" => Base.encode64("branch")
          }
        ]
      }

      assert %{
               "environment_variables" => [
                 %{
                   "name" => "AWS_KEY",
                   "encoding" => "base64",
                   "unencrypted_content" => "{SANITIZED}"
                 },
                 %{
                   "name" => "GCP_KEY",
                   "encoding" => "base64",
                   "unencrypted_content" => "{SANITIZED}"
                 },
                 %{
                   "name" => "SEMAPHORE_GIT_BRANCH",
                   "encoding" => "base64",
                   "unencrypted_content" => "bWFzdGVy"
                 },
                 %{
                   "name" => "SEMAPHORE_GIT_REF_TYPE",
                   "encoding" => "base64",
                   "unencrypted_content" => "YnJhbmNo"
                 }
               ]
             } = JobRequest.sanitize(request)
    end

    test "sanitizing already sanitized request produces same result" do
      request = %{
        "env_vars" => [
          JobRequest.env_var("AWS_KEY", "very-sensitive"),
          JobRequest.env_var("GCP_KEY", "also-very-sensitive"),
          JobRequest.env_var("SEMAPHORE_GIT_BRANCH", "master"),
          JobRequest.env_var("SEMAPHORE_GIT_REF_TYPE", "branch")
        ]
      }

      sanitized = JobRequest.sanitize(request)

      assert %{
               "env_vars" => [
                 %{"name" => "AWS_KEY", "value" => "{SANITIZED}"},
                 %{"name" => "GCP_KEY", "value" => "{SANITIZED}"},
                 %{"name" => "SEMAPHORE_GIT_BRANCH", "value" => "bWFzdGVy"},
                 %{"name" => "SEMAPHORE_GIT_REF_TYPE", "value" => "YnJhbmNo"}
               ]
             } = sanitized

      assert %{
               "env_vars" => [
                 %{"name" => "AWS_KEY", "value" => "{SANITIZED}"},
                 %{"name" => "GCP_KEY", "value" => "{SANITIZED}"},
                 %{"name" => "SEMAPHORE_GIT_BRANCH", "value" => "bWFzdGVy"},
                 %{"name" => "SEMAPHORE_GIT_REF_TYPE", "value" => "YnJhbmNo"}
               ]
             } = JobRequest.sanitize(sanitized)
    end

    test "sanitizes some SEMAPHORE_* environment variables" do
      request = %{
        "env_vars" => [
          JobRequest.env_var("AWS_KEY", "very-sensitive"),
          JobRequest.env_var("GCP_KEY", "also-very-sensitive"),
          JobRequest.env_var("SEMAPHORE_GIT_BRANCH", "master"),
          JobRequest.env_var("SEMAPHORE_GIT_REF_TYPE", "branch"),
          JobRequest.env_var("SEMAPHORE_OIDC_TOKEN", "whatever"),
          JobRequest.env_var("SEMAPHORE_ARTIFACT_TOKEN", "whatever"),
          JobRequest.env_var("SEMAPHORE_CACHE_USERNAME", "whatever")
        ]
      }

      assert %{
               "env_vars" => [
                 %{"name" => "AWS_KEY", "value" => "{SANITIZED}"},
                 %{"name" => "GCP_KEY", "value" => "{SANITIZED}"},
                 %{"name" => "SEMAPHORE_GIT_BRANCH", "value" => "bWFzdGVy"},
                 %{"name" => "SEMAPHORE_GIT_REF_TYPE", "value" => "YnJhbmNo"},
                 %{"name" => "SEMAPHORE_OIDC_TOKEN", "value" => "{SANITIZED}"},
                 %{"name" => "SEMAPHORE_ARTIFACT_TOKEN", "value" => "{SANITIZED}"},
                 %{"name" => "SEMAPHORE_CACHE_USERNAME", "value" => "{SANITIZED}"}
               ]
             } = JobRequest.sanitize(request)
    end

    test "sanitizes some SEMAPHORE_* environment variables (old request)" do
      request = %{
        "environment_variables" => [
          %{
            "name" => "AWS_KEY",
            "encoding" => "base64",
            "unencrypted_content" => Base.encode64("very-sensitive")
          },
          %{
            "name" => "GCP_KEY",
            "encoding" => "base64",
            "unencrypted_content" => Base.encode64("also-very-sensitive")
          },
          %{
            "name" => "SEMAPHORE_GIT_BRANCH",
            "encoding" => "base64",
            "unencrypted_content" => Base.encode64("master")
          },
          %{
            "name" => "SEMAPHORE_GIT_REF_TYPE",
            "encoding" => "base64",
            "unencrypted_content" => Base.encode64("branch")
          },
          %{
            "name" => "SEMAPHORE_ARTIFACT_TOKEN",
            "encoding" => "base64",
            "unencrypted_content" => Base.encode64("whatever")
          },
          %{
            "name" => "SEMAPHORE_CACHE_USERNAME",
            "encoding" => "base64",
            "unencrypted_content" => Base.encode64("whatever")
          }
        ]
      }

      assert %{
               "environment_variables" => [
                 %{
                   "name" => "AWS_KEY",
                   "encoding" => "base64",
                   "unencrypted_content" => "{SANITIZED}"
                 },
                 %{
                   "name" => "GCP_KEY",
                   "encoding" => "base64",
                   "unencrypted_content" => "{SANITIZED}"
                 },
                 %{
                   "name" => "SEMAPHORE_GIT_BRANCH",
                   "encoding" => "base64",
                   "unencrypted_content" => "bWFzdGVy"
                 },
                 %{
                   "name" => "SEMAPHORE_GIT_REF_TYPE",
                   "encoding" => "base64",
                   "unencrypted_content" => "YnJhbmNo"
                 },
                 %{
                   "name" => "SEMAPHORE_ARTIFACT_TOKEN",
                   "encoding" => "base64",
                   "unencrypted_content" => "{SANITIZED}"
                 },
                 %{
                   "name" => "SEMAPHORE_CACHE_USERNAME",
                   "encoding" => "base64",
                   "unencrypted_content" => "{SANITIZED}"
                 }
               ]
             } = JobRequest.sanitize(request)
    end

    test "sanitize all files" do
      request = %{
        "files" => [
          JobRequest.file("/tmp/a", "abc", "0644"),
          JobRequest.file("/opt/b", "def", "0600"),
          JobRequest.file("/home/semaphore/c", "ghi", "0777")
        ]
      }

      assert %{
               "files" => [
                 %{"path" => "/tmp/a", "content" => "{SANITIZED}", "mode" => "0644"},
                 %{"path" => "/opt/b", "content" => "{SANITIZED}", "mode" => "0600"},
                 %{"path" => "/home/semaphore/c", "content" => "{SANITIZED}", "mode" => "0777"}
               ]
             } = JobRequest.sanitize(request)
    end

    test "sanitize all files (old request)" do
      request = %{
        "custom_files" => [
          %{
            "path" => "/tmp/a",
            "unencrypted_content" => Base.encode64("abc"),
            "mode" => "0644",
            "encoding" => "base64"
          },
          %{
            "path" => "/opt/b",
            "unencrypted_content" => Base.encode64("def"),
            "mode" => "0600",
            "encoding" => "base64"
          },
          %{
            "path" => "/home/semaphore/c",
            "unencrypted_content" => Base.encode64("ghi"),
            "mode" => "0777",
            "encoding" => "base64"
          }
        ]
      }

      assert %{
               "custom_files" => [
                 %{
                   "path" => "/tmp/a",
                   "unencrypted_content" => "{SANITIZED}",
                   "mode" => "0644",
                   "encoding" => "base64"
                 },
                 %{
                   "path" => "/opt/b",
                   "unencrypted_content" => "{SANITIZED}",
                   "mode" => "0600",
                   "encoding" => "base64"
                 },
                 %{
                   "path" => "/home/semaphore/c",
                   "unencrypted_content" => "{SANITIZED}",
                   "mode" => "0777",
                   "encoding" => "base64"
                 }
               ]
             } = JobRequest.sanitize(request)

      request = %{
        "custom_files" => [true]
      }

      assert %{
               "custom_files" => [true]
             } = JobRequest.sanitize(request)
    end

    test "sanitize compose" do
      request = %{
        "compose" => %{
          "containers" => [
            %{
              "image" => "registry.semaphoreci.com/ruby",
              "name" => "main",
              "env_vars" => [
                JobRequest.env_var("CONTAINER_SECRET_1", "very-sensitive"),
                JobRequest.env_var("CONTAINER_SECRET_2", "also-very-sensitive")
              ],
              "files" => [
                JobRequest.file("/tmp/container_file", "abc", "0644")
              ]
            }
          ],
          "image_pull_credentials" => [
            %{
              "env_vars" => [
                JobRequest.env_var("AWS_KEY", "very-sensitive"),
                JobRequest.env_var("GCP_KEY", "also-very-sensitive")
              ],
              "files" => [
                JobRequest.file("/tmp/a", "abc", "0644"),
                JobRequest.file("/opt/b", "def", "0600"),
                JobRequest.file("/home/semaphore/c", "ghi", "0777")
              ]
            }
          ]
        }
      }

      assert %{
               "compose" => %{
                 "containers" => [
                   %{
                     "image" => "registry.semaphoreci.com/ruby",
                     "name" => "main",
                     "env_vars" => [
                       %{"name" => "CONTAINER_SECRET_1", "value" => "{SANITIZED}"},
                       %{"name" => "CONTAINER_SECRET_2", "value" => "{SANITIZED}"}
                     ],
                     "files" => [
                       %{
                         "path" => "/tmp/container_file",
                         "content" => "{SANITIZED}",
                         "mode" => "0644"
                       }
                     ]
                   }
                 ],
                 "image_pull_credentials" => [
                   %{
                     "env_vars" => [
                       %{"name" => "AWS_KEY", "value" => "{SANITIZED}"},
                       %{"name" => "GCP_KEY", "value" => "{SANITIZED}"}
                     ],
                     "files" => [
                       %{"path" => "/tmp/a", "content" => "{SANITIZED}", "mode" => "0644"},
                       %{"path" => "/opt/b", "content" => "{SANITIZED}", "mode" => "0600"},
                       %{
                         "path" => "/home/semaphore/c",
                         "content" => "{SANITIZED}",
                         "mode" => "0777"
                       }
                     ]
                   }
                 ]
               }
             } = JobRequest.sanitize(request)
    end

    test "sanitize only push logger" do
      assert %{
               "logger" => %{
                 "method" => "pull"
               }
             } =
               JobRequest.sanitize(%{
                 "logger" => %{
                   "method" => "pull"
                 }
               })

      assert %{
               "logger" => %{
                 "method" => "push",
                 "token" => "{SANITIZED}",
                 "url" => "https://example.com"
               }
             } =
               JobRequest.sanitize(%{
                 "logger" => %{
                   "method" => "push",
                   "token" => "asdasdasdasd",
                   "url" => "https://example.com"
                 }
               })
    end

    test "sanitizes callback token" do
      assert %{
               "callbacks" => %{
                 "finished" => "http://example.com",
                 "teardown_finished" => "http://example.com",
                 "token" => "{SANITIZED}"
               }
             } =
               JobRequest.sanitize(%{
                 "callbacks" => %{
                   "finished" => "http://example.com",
                   "teardown_finished" => "http://example.com",
                   "token" => "very-sensitive"
                 }
               })

      assert %{
               "callbacks" => %{
                 "finished" => "http://example.com",
                 "teardown_finished" => "http://example.com"
               }
             } =
               JobRequest.sanitize(%{
                 "callbacks" => %{
                   "finished" => "http://example.com",
                   "teardown_finished" => "http://example.com"
                 }
               })
    end
  end

  describe "env_var" do
    test "value is nil => encodes using empty string" do
      assert JobRequest.env_var("A", nil) == %{
               "name" => "A",
               "value" => ""
             }
    end

    test "no options are passed => encodes the value to base64" do
      assert JobRequest.env_var("A", "abc") == %{
               "name" => "A",
               "value" => Base.encode64("abc")
             }
    end

    test "when 'encode_to_base64: false' => does not value the content" do
      assert JobRequest.env_var("A", "abc", encode_to_base64: false) == %{
               "name" => "A",
               "value" => "abc"
             }
    end
  end

  describe "file" do
    test "no options are passed => encodes the content to base64" do
      assert JobRequest.file("/tmp/a", "abc", "0644") == %{
               "path" => "/tmp/a",
               "content" => Base.encode64("abc"),
               "mode" => "0644"
             }
    end

    test "when 'encode_to_base64: false' => does not encode the content" do
      assert JobRequest.file("/tmp/a", "abc", "0644", encode_to_base64: false) == %{
               "path" => "/tmp/a",
               "content" => "abc",
               "mode" => "0644"
             }
    end
  end

  test "the format of the payload is suitable for agents" do
    job = %{
      id: Ecto.UUID.generate(),
      name: "Test",
      machine_os_image: "macos-mojave-xcode11",
      machine_type: "e1-standard-2"
    }

    key_parts = [
      "AAAAB3NzaC1yc2EAAAADAQABAAABAQDawUPrnHw317orMJ++TIA3II/WUe",
      "XmYHtzDeKxvTYDCJNXOKlCWQGRDPcXr9ztBasA2kI5TfHf7XFCT1Fr6DBC",
      "XYSQRfEeRUNq3hzPNAgx3QvpfMS4GOACeJ2aQwGYq2upf0iq3qSenPhBhe",
      "jNzTLQfiEsVZ/vb69hdQ4ZLZWmzdBZxRmJJQKVjxxCUd3T7SMs9b4ccMQY",
      "fspOVjMPAyQj2+ASAWBL4uTWp1rit3v/iNFGS+IhXR+VxUdacZp4SGjjMd",
      "xSrI3ewaC4QAToBgWUReuEavQe3E/V4qonOaMrUOaAeg88OfrrnO0tV84F",
      "fmNRc0TGsh22VHsWiMGWqKr"
    ]

    ssh_public_keys =
      JobRequest.ssh_public_keys(%{
        public_key: "ssh-rsa #{Enum.join(key_parts, "")}"
      })

    commands = [
      JobRequest.command("bundle exec rspec")
    ]

    epilogue = %{
      always_commands: [
        JobRequest.command("make upload.artifacts")
      ],
      on_pass: [
        JobRequest.command("make upload.artifacts")
      ],
      on_fail: [
        JobRequest.command("make upload.artifacts")
      ]
    }

    files = [
      JobRequest.file("a.txt", "hello", "0644")
    ]

    env_vars = [
      JobRequest.env_var("AWS_KEY", "kamehameha")
    ]

    agent =
      Semaphore.Jobs.V1alpha.Job.Spec.Agent.new(
        machine:
          Semaphore.Jobs.V1alpha.Job.Spec.Agent.Machine.new(
            type: "e1-standard-2",
            os_image: "ubuntu1804"
          ),
        containers: [
          Semaphore.Jobs.V1alpha.Job.Spec.Agent.Container.new(
            name: "main",
            command: "psql --serve",
            image: "postgres:9.6",
            env_vars: [
              Semaphore.Jobs.V1alpha.Job.Spec.EnvVar.new(name: "A", value: "B")
            ],
            secrets: [
              Semaphore.Jobs.V1alpha.Job.Spec.Secret.new(name: "A")
            ]
          )
        ],
        image_pull_secrets: [
          Semaphore.Jobs.V1alpha.Job.Spec.Agent.ImagePullSecret.new(name: "A")
        ]
      )

    all_secrets = %Zebra.Workers.JobRequestFactory.Secrets{
      image_pull_secrets: [
        %Zebra.Workers.JobRequestFactory.Secrets.Secret{
          name: "A",
          env_vars: [
            JobRequest.env_var("FOO", "BAR")
          ],
          files: [
            JobRequest.file("a.txt", "aaa", "0644")
          ]
        }
      ],
      container_secrets: [
        [
          %Zebra.Workers.JobRequestFactory.Secrets.Secret{
            name: "A",
            env_vars: [
              JobRequest.env_var("FOO", "BAR")
            ],
            files: [
              JobRequest.file("a.txt", "aaa", "0644")
            ]
          }
        ]
      ]
    }

    callback_token = "pretend-this-is-a-jwt"

    payload =
      JobRequest.encode(
        agent,
        ssh_public_keys,
        job,
        commands,
        epilogue,
        env_vars,
        files,
        all_secrets,
        callback_token
      )

    payload = JobRequest.append_logger(payload, job, "", nil)

    assert payload == %{
             "job_id" => job.id,
             "job_name" => "Test",
             "compose" => %{
               "containers" => [
                 %{
                   "command" => "psql --serve",
                   "env_vars" => [
                     %{
                       "name" => "FOO",
                       "value" => "QkFS"
                     },
                     %{
                       "name" => "A",
                       "value" => "Qg=="
                     }
                   ],
                   "files" => [
                     %{
                       "content" => "YWFh",
                       "mode" => "0644",
                       "path" => "a.txt"
                     }
                   ],
                   "image" => "postgres:9.6",
                   "name" => "main"
                 }
               ],
               "host_setup_commands" => [],
               "image_pull_credentials" => [
                 %{
                   "env_vars" => [
                     %{
                       "name" => "FOO",
                       "value" => "QkFS"
                     }
                   ],
                   "files" => [
                     %{
                       "content" => "YWFh",
                       "mode" => "0644",
                       "path" => "a.txt"
                     }
                   ]
                 }
               ]
             },
             "executor" => "dockercompose",
             "ssh_public_keys" => [
               Enum.join(
                 [
                   "c3NoLXJzYSBBQUFBQjNOemFDMXljMkVBQUFBREFRQUJBQUFCQVFEYXdVUHJuSHczMT",
                   "dvck1KKytUSUEzSUkvV1VlWG1ZSHR6RGVLeHZUWURDSk5YT0tsQ1dRR1JEUGNYcjl6",
                   "dEJhc0Eya0k1VGZIZjdYRkNUMUZyNkRCQ1hZU1FSZkVlUlVOcTNoelBOQWd4M1F2cG",
                   "ZNUzRHT0FDZUoyYVF3R1lxMnVwZjBpcTNxU2VuUGhCaGVqTnpUTFFmaUVzVlovdmI2",
                   "OWhkUTRaTFpXbXpkQlp4Um1KSlFLVmp4eENVZDNUN1NNczliNGNjTVFZZnNwT1ZqTV",
                   "BBeVFqMitBU0FXQkw0dVRXcDFyaXQzdi9pTkZHUytJaFhSK1Z4VWRhY1pwNFNHampN",
                   "ZHhTckkzZXdhQzRRQVRvQmdXVVJldUVhdlFlM0UvVjRxb25PYU1yVU9hQWVnODhPZn",
                   "Jybk8wdFY4NEZmbU5SYzBUR3NoMjJWSHNXaU1HV3FLcg=="
                 ],
                 ""
               )
             ],
             "commands" => [
               %{"directive" => "bundle exec rspec"}
             ],
             "env_vars" => [
               %{"name" => "AWS_KEY", "value" => "a2FtZWhhbWVoYQ=="}
             ],
             "files" => [
               %{"content" => "aGVsbG8=", "mode" => "0644", "path" => "a.txt"}
             ],
             "epilogue_always_commands" => [
               %{"directive" => "make upload.artifacts"}
             ],
             "epilogue_on_pass_commands" => [
               %{"directive" => "make upload.artifacts"}
             ],
             "epilogue_on_fail_commands" => [
               %{"directive" => "make upload.artifacts"}
             ],
             "callbacks" => %{
               "finished" => "https://s2-callback.semaphoretest.xyz/finished/#{job.id}",
               "teardown_finished" =>
                 "https://s2-callback.semaphoretest.xyz/teardown_finished/#{job.id}",
               "token" => "pretend-this-is-a-jwt"
             },
             "logger" => %{
               "method" => "pull"
             }
           }
  end

  test "redirect_semaphoreci_convenient_images" do
    input = [
      "semaphoreci/ruby:2.6.3",
      "my-private-image-for-semaphoreci",
      "postgres:9.6"
    ]

    expected_output = [
      "registry.semaphoreci.com/ruby:2.6.3",
      "my-private-image-for-semaphoreci",
      "postgres:9.6"
    ]

    output = Enum.map(input, fn img -> JobRequest.redirect_semaphoreci_convenient_images(img) end)

    assert output == expected_output
  end
end
