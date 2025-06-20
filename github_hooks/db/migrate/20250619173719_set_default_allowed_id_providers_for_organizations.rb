class SetDefaultAllowedIdProvidersForOrganizations < ActiveRecord::Migration[5.1]
  def up
    # Set existing null values to the default
    execute("UPDATE organizations SET allowed_id_providers = 'api_token,oidc' WHERE allowed_id_providers IS NULL OR allowed_id_providers = ''")
    change_column_default :organizations, :allowed_id_providers, "api_token,oidc"
  end

  def down
    change_column_default :organizations, :allowed_id_providers, nil
  end
end
