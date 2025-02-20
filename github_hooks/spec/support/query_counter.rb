def count_queries_while
  query_count = 0

  subscriber = ActiveSupport::Notifications.subscribe "sql.active_record" do |_name, _started, _finished, _id, data|
    # ignore rollbacks at the end of a test case
    # and schema loads
    query_count += 1 if data[:sql] != "ROLLBACK" && data[:name] != "SCHEMA"
  end

  yield

  ActiveSupport::Notifications.unsubscribe(subscriber)

  query_count
end
