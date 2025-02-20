class AddInviteEmailToMembers < ActiveRecord::Migration[5.1]
  def change
    add_column :members, :invite_email, :string
  end
end
