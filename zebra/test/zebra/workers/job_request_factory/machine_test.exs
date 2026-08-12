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

  describe "brownouts" do
    @project_id "b2f0f5c1-1111-4b67-a417-f31f2fa0f105"

    setup do
      [
        job: %{
          organization_id: @org_id,
          project_id: @project_id,
          machine_type: "a1-standard-4",
          machine_os_image: "macos-xcode13"
        }
      ]
    end

    test "it stops the job and counts it when the organization is in a brownout", %{job: job} do
      with_mock Zebra.Machines.Brownout, [:passthrough], status: fn _, _, _ -> :in_brownout end do
        with_mock Watchman, [:passthrough], increment: fn _ -> nil end do
          assert {:stop_job_processing, message} =
                   Zebra.Workers.JobRequestFactory.Machine.validate(@org_id, job)

          assert message =~ "is currently in a brownout phase"

          assert_called(
            Watchman.increment({"brownout.job_stopped", ["macos-xcode13", @org_id, @project_id]})
          )
        end
      end
    end

    test "it lets the job through but counts it when the organization is excluded", %{job: job} do
      with_mock Zebra.Machines.Brownout, [:passthrough], status: fn _, _, _ -> :excluded end do
        with_mock Watchman, [:passthrough], increment: fn _ -> nil end do
          assert Zebra.Workers.JobRequestFactory.Machine.validate(@org_id, job) == :ok

          assert_called(
            Watchman.increment({"brownout.job_excluded", ["macos-xcode13", @org_id, @project_id]})
          )
        end
      end
    end

    test "it counts nothing outside a brownout window", %{job: job} do
      with_mock Zebra.Machines.Brownout,
                [:passthrough],
                status: fn _, _, _ -> :not_in_brownout end do
        with_mock Watchman, [:passthrough], increment: fn _ -> nil end do
          assert Zebra.Workers.JobRequestFactory.Machine.validate(@org_id, job) == :ok

          refute called(
                   Watchman.increment(
                     {"brownout.job_excluded", ["macos-xcode13", @org_id, @project_id]}
                   )
                 )
        end
      end
    end
  end
end
