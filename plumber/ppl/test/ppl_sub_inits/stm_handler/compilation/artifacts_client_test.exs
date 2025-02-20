defmodule Ppl.PplSubInits.STMHandler.Compilation.AtifactsClient.Test do
  use ExUnit.Case, async: false

  import Mock

  alias Ppl.PplSubInits.STMHandler.Compilation.AtifactsClient
  alias InternalApi.Artifacthub.GetSignedURLResponse
  alias Util.Proto

  @url_env_name "INTERNAL_API_URL_ARTIFACTHUB"

  setup_all do
    Test.Support.GrpcServerHelper.start_server_with_cleanup(ArtifactServiceMock)
  end

  setup %{port: port} do
    Test.Support.GrpcServerHelper.setup_service_url(@url_env_name, port)
    :ok
  end


  test "when ARTIFACTHUB URL is invalid in get_signed_url call => timeout occures" do
    System.put_env(@url_env_name, "invalid_url:12345")

    path = ".semaphore/semaphore.yml"
    wf_id = UUID.uuid4()
    art_id = "artifact_id_1"

    assert {:error, message} = AtifactsClient.get_url(art_id, wf_id, path)
    assert {:timeout, _time_to_wait} = message
  end

  test "when time-out occures in get_signed_url call => error is returned" do
    ArtifactServiceMock
    |> GrpcMock.expect(:get_signed_url, fn _req, _ ->
        :timer.sleep(5_100)
        GetSignedURLResponse.new()
      end)

    path = ".semaphore/semaphore.yml"
    wf_id = UUID.uuid4()
    art_id = "artifact_id_1"

    assert {:error, message} = AtifactsClient.get_url(art_id, wf_id, path)
    assert {:timeout, _time_to_wait} = message

    GrpcMock.verify!(ArtifactServiceMock)
  end

  test "when get_signed_url is called => ArtifactHub's response is processed correctly" do
    ArtifactServiceMock
    |> GrpcMock.expect(:get_signed_url, fn _req, _ ->
        %{url: "test_url_value"}
        |> Proto.deep_new!(GetSignedURLResponse)
      end)

    path = ".semaphore/semaphore.yml"
    wf_id = UUID.uuid4()
    art_id = "artifact_id_1"

    assert {:ok, %{url: url}} = AtifactsClient.get_url(art_id, wf_id, path)
    assert url == "test_url_value"

    GrpcMock.verify!(ArtifactServiceMock)
  end

  test "when YAML file is fetched correctly => acquire_file() returns definition file as string" do
    ArtifactServiceMock
    |> GrpcMock.expect(:get_signed_url, fn _req, _ ->
        %{url: "test_url_value"}
        |> Proto.deep_new!(GetSignedURLResponse)
      end)

    path = ".semaphore/semaphore.yml"
    wf_id = UUID.uuid4()
    art_id = "artifact_id_1"

    with_mock HTTPoison, [get: &(mocked_get(&1))] do
      assert {:ok, definition} = AtifactsClient.acquire_file(art_id, wf_id, path)
      assert definition == expected_definition()
    end

    GrpcMock.verify!(ArtifactServiceMock)
  end

  test "when file is not present {:error, {:not_found, msg}} is returned" do
    ArtifactServiceMock
    |> GrpcMock.expect(:get_signed_url, fn _req, _ ->
        %{url: "respond_404"}
        |> Proto.deep_new!(GetSignedURLResponse)
      end)

    path = ".semaphore/semaphore.yml"
    wf_id = UUID.uuid4()
    art_id = "artifact_id_1"

    with_mock HTTPoison, [get: &(mocked_get(&1))] do
      assert {:error, {:not_found, msg}} = AtifactsClient.acquire_file(art_id, wf_id, path)
      assert msg == expected_error_message()
    end

    GrpcMock.verify!(ArtifactServiceMock)
  end

  def mocked_get("test_url_value") do
    {:ok,
      %HTTPoison.Response{
        status_code: 200,
        body:
         "version: v1.0\nname: Test pipeline\nagent:\n  machine:\n    "
         <> "type: e1-standard-2\n    os_image: ubuntu2004\nblocks:\n  "
         <> "- name: Test Block\n    dependencies: []\n    task:\n      jobs:\n"
         <> "        - name: Test job\n          commands:\n            - echo test\n"
      }
    }
  end
  def mocked_get("respond_404") do
    {:ok,
      %HTTPoison.Response{
        status_code: 404,
        body:
          "<?xml version='1.0' encoding='UTF-8'?><Error><Code>NoSuchKey</Code>"
          <> "<Message>The specified key does not exist.</Message><Details>"
          <> "No such object: /artifacts/workflows/<wf_id>/compilation/semaphore.yml"
          <> "</Details></Error>"
      }
    }
  end

  defp expected_error_message() do
    "<?xml version='1.0' encoding='UTF-8'?><Error><Code>NoSuchKey</Code>"
    <> "<Message>The specified key does not exist.</Message><Details>"
    <> "No such object: /artifacts/workflows/<wf_id>/compilation/semaphore.yml"
    <> "</Details></Error>"
  end

  defp expected_definition() do
    "version: v1.0\nname: Test pipeline\nagent:\n  machine:\n    "
    <> "type: e1-standard-2\n    os_image: ubuntu2004\nblocks:\n  "
    <> "- name: Test Block\n    dependencies: []\n    task:\n      jobs:\n"
    <> "        - name: Test job\n          commands:\n            - echo test\n"
  end
end
