class CreateArrayDiffFunction < ActiveRecord::Migration[5.1]
  def up
    sql = <<-SQL
    create or replace function array_diff(array1 anyarray, array2 anyarray)
    returns anyarray language sql immutable as $$
    select coalesce(array_agg(elem), '{}')
    from unnest(array1) elem
    where elem <> all(array2)
    $$;
    SQL

    ActiveRecord::Base.connection.execute(sql)
  end

  def down
    sql = <<-SQL
    drop function if EXISTS array_diff(anyarray, anyarray)
    SQL

    ActiveRecord::Base.connection.execute(sql)
  end
end
