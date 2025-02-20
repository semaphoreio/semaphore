class AddFailFastStrategyToBuilds < ActiveRecord::Migration[5.1]
  def change
    add_column :builds, :fail_fast_strategy, :string
  end
end
