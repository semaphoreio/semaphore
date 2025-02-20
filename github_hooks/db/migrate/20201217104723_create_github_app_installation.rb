class CreateGithubAppInstallation < ActiveRecord::Migration[5.1]
  def change
    create_table :github_app_installations, id: :uuid, default: -> { "uuid_generate_v4()" } do |t|
      t.bigint :installation_id
      t.jsonb :repositories

      t.timestamps null: false
    end
  end
end
