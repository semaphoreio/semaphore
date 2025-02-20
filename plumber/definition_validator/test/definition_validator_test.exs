defmodule DefinitionValidator.Test do
  use ExUnit.Case
  doctest DefinitionValidator

  test "valid definition - no 'dependencies' property" do
    yaml_string = """
    version: v1.0
    agent:
      machine:
        type: foo
        os_image: bar

    blocks:
      - task:
          jobs:
            - name: single job
              commands:
                - docker-compose up
    promotions:
      - name: Production
        pipeline_file: deploy.yml
    """
    {:ok, ppl_def} = DefinitionValidator.validate_yaml_string(yaml_string)
    assert ppl_def ==
        %{"blocks" =>
            [
              %{"task" =>
                %{"jobs" =>
                  [%{"name" => "single job", "commands" => ["docker-compose up"]}]
                }
              }
             ],
           "agent" => %{"machine" => %{"type" => "foo", "os_image" => "bar"}},
           "promotions" => [%{"name" => "Production", "pipeline_file" => "deploy.yml"}],
           "version" => "v1.0"
          }
  end

  test "valid definition - with 'dependencies' property" do
    yaml_string = """
    version: v1.0
    agent:
      machine:
        type: foo
        os_image: bar

    blocks:
      - name: First block
        dependencies: []
        task:
          jobs:
            - name: single job
              commands:
                - docker-compose up
      - name: Second block
        dependencies: [First block]
        task:
          jobs:
            - name: single job
              commands:
                - docker-compose up
    """
    {:ok, ppl_def} = DefinitionValidator.validate_yaml_string(yaml_string)
    assert ppl_def ==
        %{"blocks" =>
            [
              %{"name" => "First block",
                "dependencies" => [],
                "task" =>
                %{"jobs" =>
                  [%{"name" => "single job", "commands" => ["docker-compose up"]}]
                }
              },
              %{"name" => "Second block",
                "dependencies" => ["First block"],
                "task" =>
                %{"jobs" =>
                  [%{"name" => "single job", "commands" => ["docker-compose up"]}]
                }
              }
             ],
           "agent" => %{"machine" => %{"type" => "foo", "os_image" => "bar"}},
           "version" => "v1.0"
          }
  end

  test "malformed definition - mixed implicit and explicit 'dependencies'" do
    yaml_string = """
    version: v1.0
    agent:
      machine:
        type: foo
        os_image: bar

    blocks:
      - name: First block
        task:
          jobs:
            - name: single job
              commands:
                - docker-compose up
      - name: Second block
        dependencies: [First block]
        task:
          jobs:
            - name: single job
              commands:
                - docker-compose up
    """
    assert({:error, {:malformed, msg}} =
      DefinitionValidator.validate_yaml_string(yaml_string))
    assert msg ==
      """
      There are blocks with both explicitly and implicitly defined dependencies.
      This is not allowed, please use only one of this formats.
      """
  end

  test "empty definition" do
    assert {:error, {:malformed, reason}} = DefinitionValidator.validate_yaml_string("")
    assert String.contains?(reason, "version")
  end

  test "peculiar yaml definition" do
    assert {:error, {:malformed, reason}} = DefinitionValidator.validate_yaml_string("foo")
    assert {:expected_map, ppl_def} = reason
    assert ppl_def == "foo"
  end

  test "invalid type of version property: number, should be string" do
    yaml_string = """
    version: 1.0
    agent:
      machine:
        type: foo
        os_image: bar

    blocks:
      - task:
          jobs:
            - name: single job
              commands:
                - docker-compose up
    """
    assert {:error, ppl_def} = DefinitionValidator.validate_yaml_string(yaml_string)
    assert {:malformed, message} = ppl_def
    assert String.contains?(message, "missing or not string")
  end

  test "wrong version: 'v1', should be 'v1.0'" do
    yaml_string = """
    version: v1
    agent:
      machine:
        type: foo
        os_image: bar

    blocks:
      - task:
          jobs:
            - name: single job
              commands:
                - docker-compose up
    """
    assert {:error, ppl_def} = DefinitionValidator.validate_yaml_string(yaml_string)
    assert {:malformed, message} = ppl_def
    assert String.contains?(message, "not supported")
  end

  describe "when SKIP_PROMOTIONS flag is set to true" do
    setup do
      System.put_env("SKIP_PROMOTIONS", "true")
      on_exit(fn -> System.delete_env("SKIP_PROMOTIONS") end)
    end

    test "definition with promotions malformed" do
      yaml_string = """
      version: v1.0
      agent:
        machine:
          type: foo
          os_image: bar

      blocks:
        - task:
            jobs:
              - name: single job
                commands:
                  - docker-compose up
      promotions:
        - name: Production
          pipeline_file: deploy.yml
      """

      assert {:error, ppl_def} = DefinitionValidator.validate_yaml_string(yaml_string)
      assert {:malformed, "Promotions are not available in the Comunity edition of Semaphore."} == ppl_def
    end
  end
end
