class EnforceUniqunessOfQuotaOnOrgLevel < ActiveRecord::Migration[5.1]
  def change
    add_index :quotas, [:organization_id, :type], :unique => true
  end
end
