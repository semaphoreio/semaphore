defmodule Auth.IpFilterTest do
  use ExUnit.Case

  @org_id UUID.uuid4()

  describe "#block?" do
    test "empty ip_allow_list => returns false" do
      refute Auth.IpFilter.block?({172, 14, 101, 99}, %{
               id: @org_id,
               name: "semaphore",
               ip_allow_list: []
             })
    end

    test "single IP => returns false if request comes from the same IP" do
      refute Auth.IpFilter.block?({172, 14, 101, 99}, %{
               id: @org_id,
               name: "semaphore",
               ip_allow_list: ["172.14.101.99"]
             })
    end

    test "single IP => returns true if request does not come from the same IP" do
      assert Auth.IpFilter.block?({211, 191, 11, 4}, %{
               id: @org_id,
               name: "semaphore",
               ip_allow_list: ["172.14.101.99"]
             })
    end

    test "multiple IPs => returns false if request comes from one of the IPs allowed" do
      refute Auth.IpFilter.block?({172, 14, 101, 99}, %{
               id: @org_id,
               name: "semaphore",
               ip_allow_list: ["32.109.221.12", "172.14.101.99"]
             })
    end

    test "multiple IPs => returns true if request comes from none of the IPs allowed" do
      assert Auth.IpFilter.block?({211, 191, 11, 4}, %{
               id: @org_id,
               name: "semaphore",
               ip_allow_list: ["32.109.221.12", "172.14.101.99"]
             })
    end

    test "single bad CIDR => returns false" do
      refute Auth.IpFilter.block?({172, 14, 101, 99}, %{
               id: @org_id,
               name: "semaphore",
               ip_allow_list: ["32.109.221.12/999"]
             })
    end

    test "single CIDR => returns false if request comes from IP inside CIDR" do
      refute Auth.IpFilter.block?({32, 109, 221, 1}, %{
               id: @org_id,
               name: "semaphore",
               ip_allow_list: ["32.109.221.12/28"]
             })
    end

    test "single CIDR => returns true if request comes from IP outside the CIDR" do
      assert Auth.IpFilter.block?({32, 109, 222, 1}, %{
               id: @org_id,
               name: "semaphore",
               ip_allow_list: ["32.109.221.12/28"]
             })
    end

    test "multiple CIDRs => returns false if request comes from IP inside one of the CIDRs" do
      refute Auth.IpFilter.block?({32, 109, 221, 1}, %{
               id: @org_id,
               name: "semaphore",
               ip_allow_list: ["113.51.211.0/16", "32.109.221.12/28"]
             })
    end

    test "multiple CIDRs => returns true if request comes from IP outside all CIDRs" do
      assert Auth.IpFilter.block?({45, 111, 201, 7}, %{
               id: @org_id,
               name: "semaphore",
               ip_allow_list: ["113.51.211.0/16", "32.109.221.12/28"]
             })
    end

    test "IP + CIDR => returns false if request comes from IP inside CIDR" do
      refute Auth.IpFilter.block?({32, 109, 221, 1}, %{
               id: @org_id,
               name: "semaphore",
               ip_allow_list: ["113.51.211.12", "32.109.221.12/28"]
             })
    end

    test "IP + CIDR => returns false if request comes from one of the allowed IPs" do
      refute Auth.IpFilter.block?({113, 51, 211, 12}, %{
               id: @org_id,
               name: "semaphore",
               ip_allow_list: ["113.51.211.12", "32.109.221.12/28"]
             })
    end

    test "IP + CIDR => returns true if request comes from IP not in CIDRs and not in allowed IPs" do
      assert Auth.IpFilter.block?({35, 121, 222, 37}, %{
               id: @org_id,
               name: "semaphore",
               ip_allow_list: ["113.51.211.12", "32.109.221.12/28"]
             })
    end
  end
end
