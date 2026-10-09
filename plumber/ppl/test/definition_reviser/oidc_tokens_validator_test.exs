defmodule Ppl.DefinitionReviser.OIDCTokensValidator.Test do
  use ExUnit.Case, async: true
  alias Ppl.DefinitionReviser.OIDCTokensValidator

  describe "validate oidc_tokens block" do
    test "pipeline without any oidc_tokens block passes validation" do
      pipeline = %{
        "blocks" => [
          %{
            "name" => "Block 1",
            "build" => %{
              "jobs" => [
                %{"name" => "Job 1", "commands" => ["true"]}
              ]
            }
          }
        ]
      }

      assert OIDCTokensValidator.validate(pipeline) == {:ok, pipeline}
    end

    test "job with empty oidc_tokens map passes validation" do
      pipeline = %{
        "blocks" => [
          %{
            "name" => "Block 1",
            "build" => %{
              "jobs" => [
                %{"name" => "Job 1", "oidc_tokens" => %{}}
              ]
            }
          }
        ]
      }

      assert OIDCTokensValidator.validate(pipeline) == {:ok, pipeline}
    end

    test "job with valid oidc_tokens map passes validation" do
      pipeline = %{
        "blocks" => [
          %{
            "name" => "Block 1",
            "build" => %{
              "jobs" => [
                %{
                  "name" => "Job 1",
                  "oidc_tokens" => %{
                    "PYPI_OIDC_TOKEN" => %{"aud" => "pypi"},
                    "NPM_TOKEN" => %{"aud" => ["npm-prod"]}
                  }
                }
              ]
            }
          }
        ]
      }

      assert OIDCTokensValidator.validate(pipeline) == {:ok, pipeline}
    end

    test "job using SEMAPHORE_OIDC_TOKEN as a custom token name fails validation" do
      pipeline = %{
        "blocks" => [
          %{
            "name" => "Block 1",
            "build" => %{
              "jobs" => [
                %{
                  "name" => "Job 1",
                  "oidc_tokens" => %{"SEMAPHORE_OIDC_TOKEN" => %{"aud" => "pypi"}}
                }
              ]
            }
          }
        ]
      }

      assert {:error, {:malformed, msg}} = OIDCTokensValidator.validate(pipeline)

      assert msg =~ "SEMAPHORE_OIDC_TOKEN"
      assert msg =~ "reserved"
      assert msg =~ "Block 1"
      assert msg =~ "Job 1"
    end

    test "after_pipeline job using SEMAPHORE_OIDC_TOKEN fails validation" do
      pipeline = %{
        "blocks" => [
          %{
            "name" => "Block 1",
            "build" => %{
              "jobs" => [%{"name" => "Job 1"}]
            }
          }
        ],
        "after_pipeline" => [
          %{
            "build" => %{
              "jobs" => [
                %{
                  "name" => "After Job 1",
                  "oidc_tokens" => %{"SEMAPHORE_OIDC_TOKEN" => %{"aud" => "pypi"}}
                }
              ]
            }
          }
        ]
      }

      assert {:error, {:malformed, msg}} = OIDCTokensValidator.validate(pipeline)

      assert msg =~ "SEMAPHORE_OIDC_TOKEN"
      assert msg =~ "reserved"
      assert msg =~ "after_pipeline"
      assert msg =~ "After Job 1"
    end

    test "valid oidc_tokens alongside another job with reserved name fails validation" do
      pipeline = %{
        "blocks" => [
          %{
            "name" => "Block 1",
            "build" => %{
              "jobs" => [
                %{
                  "name" => "Job 1",
                  "oidc_tokens" => %{"PYPI_OIDC_TOKEN" => %{"aud" => "pypi"}}
                },
                %{
                  "name" => "Job 2",
                  "oidc_tokens" => %{"SEMAPHORE_OIDC_TOKEN" => %{"aud" => "x"}}
                }
              ]
            }
          }
        ]
      }

      assert {:error, {:malformed, msg}} = OIDCTokensValidator.validate(pipeline)

      assert msg =~ "SEMAPHORE_OIDC_TOKEN"
      assert msg =~ "Job 2"
    end
  end
end
