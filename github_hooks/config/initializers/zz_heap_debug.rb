if ENV["ENABLE_HEAP_DEBUG"] == "true"
  require "objspace"

  begin
    require "rbtrace"
  rescue LoadError => e
    warn("[zz_heap_debug] rbtrace unavailable: #{e.message}")
  end

  if ENV["ENABLE_ALLOC_TRACE"] == "true"
    ObjectSpace.trace_object_allocations_start
  end

  Signal.trap("USR2") do
    Thread.new do
      ts = Time.now.to_i

      File.open("/tmp/gcstat-#{ts}.txt", "w") do |f|
        f.puts("GC.stat=#{GC.stat.inspect}")
        f.puts("memsize_of_all=#{ObjectSpace.memsize_of_all}")
        f.puts("count_objects=#{ObjectSpace.count_objects.inspect}")
      end

      File.open("/tmp/heap-#{ts}.json", "w") do |io|
        ObjectSpace.dump_all(output: io)
      end
    rescue => e
      warn("[zz_heap_debug] dump failed: #{e.class}: #{e.message}")
    end
  end
end
