defmodule Secrethub.Utils.Test do
  use ExUnit.Case

  alias Secrethub.Utils

  describe ".permissions_from_org_config" do
    test "empty permissions return nil" do
      permissions = Utils.permissions_from_org_config(nil)

      assert permissions.all_projects == nil
      assert permissions.project_ids == nil
      assert permissions.job_debug == nil
      assert permissions.job_attach == nil
    end

    test "without job_debug and job_attach in request" do
      org_config = InternalApi.Secrethub.Secret.OrgConfig.new(projects_access: :ALL)

      permissions = Utils.permissions_from_org_config(org_config)

      assert permissions.all_projects == true
      assert permissions.project_ids == []

      assert permissions.job_debug ==
               InternalApi.Secrethub.Secret.OrgConfig.JobDebugAccess.value(:JOB_DEBUG_YES)

      assert permissions.job_attach ==
               InternalApi.Secrethub.Secret.OrgConfig.JobAttachAccess.value(:JOB_ATTACH_YES)
    end
  end

  describe ".to_org_config_params" do
    test "without job_debug => return default values" do
      raw_secret = %Secrethub.Secret{
        all_projects: false,
        project_ids: []
      }

      params = Utils.to_org_config_params(raw_secret)

      assert Keyword.get(params, :debug_access) == nil
      assert Keyword.get(params, :attach_access) == nil

      org_cfg = InternalApi.Secrethub.Secret.OrgConfig.new(params)
      assert org_cfg.projects_access == :NONE
      assert org_cfg.project_ids == []
      assert org_cfg.debug_access == :JOB_DEBUG_YES
    end

    test "default values => return default values" do
      raw_secret = %Secrethub.Secret{
        all_projects: false,
        project_ids: [],
        job_debug: 0,
        job_attach: 0
      }

      params = Utils.to_org_config_params(raw_secret)

      assert Keyword.get(params, :debug_access) == :JOB_DEBUG_YES
      assert Keyword.get(params, :attach_access) == :JOB_ATTACH_YES

      org_cfg = InternalApi.Secrethub.Secret.OrgConfig.new(params)
      assert org_cfg.projects_access == :NONE
      assert org_cfg.project_ids == []
      assert org_cfg.debug_access == :JOB_DEBUG_YES
    end
  end
end
