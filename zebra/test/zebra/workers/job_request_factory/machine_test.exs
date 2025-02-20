defmodule Zebra.Workers.JobRequestFactory.MachineTest do
  use Zebra.DataCase

  @org_id "9878dc83-oooo-4b67-a417-f31f2fa0f105"

  setup do
    GrpcMock.stub(Support.FakeServers.SelfHosted, :list, fn _, _ ->
      InternalApi.SelfHosted.ListResponse.new(
        agent_types: [
          InternalApi.SelfHosted.AgentType.new(
            organization_id: "9878dc83-oooo-4b67-a417-f31f2fa0f105",
            name: "s1-test-1"
          )
        ]
      )
    end)

    :ok
  end

  test "it returns :ok if self-hosted agent type exists" do
    assert Zebra.Workers.JobRequestFactory.Machine.validate(@org_id, %{
             organization_id: @org_id,
             machine_type: "s1-test-1"
           }) == :ok
  end

  test "it returns error if self-hosted agent type does not exist" do
    assert Zebra.Workers.JobRequestFactory.Machine.validate(@org_id, %{
             organization_id: @org_id,
             machine_type: "s1-does-not-exist"
           }) == {
             :stop_job_processing,
             "Unknown self-hosted agent type 's1-does-not-exist'"
           }
  end

  test "it returns :ok for valid a1 machines xcode12" do
    assert Zebra.Workers.JobRequestFactory.Machine.validate(@org_id, %{
             organization_id: @org_id,
             machine_type: "a1-standard-4",
             machine_os_image: "macos-xcode12"
           }) == {
             :stop_job_processing,
             "Machine type 'a1-standard-4' with os image 'macos-xcode12' is obsoleted. Please use 'macos-xcode13' os image for your jobs."
           }
  end

  test "it returns :ok for valid a1 machines xcode13" do
    assert Zebra.Workers.JobRequestFactory.Machine.validate(@org_id, %{
             organization_id: @org_id,
             machine_type: "a1-standard-4",
             machine_os_image: "macos-xcode13"
           }) == :ok
  end

  test "it returns :ok for valid ax1 machines xcode13" do
    assert Zebra.Workers.JobRequestFactory.Machine.validate(@org_id, %{
             organization_id: @org_id,
             machine_type: "ax1-standard-4",
             machine_os_image: "macos-xcode13"
           }) == :ok
  end

  test "it returns :ok for valid e1 machines" do
    assert Zebra.Workers.JobRequestFactory.Machine.validate(@org_id, %{
             organization_id: @org_id,
             machine_type: "e1-standard-2",
             machine_os_image: "ubuntu1804"
           }) == :ok

    assert Zebra.Workers.JobRequestFactory.Machine.validate(@org_id, %{
             organization_id: @org_id,
             machine_type: "e1-standard-4",
             machine_os_image: "ubuntu1804"
           }) == :ok

    assert Zebra.Workers.JobRequestFactory.Machine.validate(@org_id, %{
             organization_id: @org_id,
             machine_type: "e1-standard-8",
             machine_os_image: "ubuntu1804"
           }) == :ok
  end

  test "it returns error for unknown types" do
    assert Zebra.Workers.JobRequestFactory.Machine.validate(@org_id, %{
             organization_id: @org_id,
             machine_type: "w1-standard-2",
             machine_os_image: "windows"
           }) == {
             :stop_job_processing,
             "Unknown machine type 'w1-standard-2' with os image 'windows'"
           }
  end

  test "it returns error for obsolete os image types xcode10" do
    assert Zebra.Workers.JobRequestFactory.Machine.validate(@org_id, %{
             organization_id: @org_id,
             machine_type: "a1-standard-4",
             machine_os_image: "macos-mojave-xcode10"
           }) == {
             :stop_job_processing,
             "Machine type 'a1-standard-4' with os image 'macos-mojave-xcode10' is obsoleted. Please use 'macos-xcode13' os image for your jobs."
           }
  end

  test "it returns error for obsolete os image types xcode11" do
    assert Zebra.Workers.JobRequestFactory.Machine.validate(@org_id, %{
             organization_id: @org_id,
             machine_type: "a1-standard-4",
             machine_os_image: "macos-xcode11"
           }) == {
             :stop_job_processing,
             "Machine type 'a1-standard-4' with os image 'macos-xcode11' is obsoleted. Please use 'macos-xcode13' os image for your jobs."
           }
  end
end
