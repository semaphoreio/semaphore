if ENV["ENABLE_HEAP_DEBUG"] == "true"
  require "objspace"

  begin
    require "rbtrace"
  rescue LoadError => e
    warn("[zz_heap_debug] rbtrace unavailable: #{e.message}")
  end

  # Optional, HEAVY: record allocation file:line for every object so the SIGUSR2
  # heap dumps can attribute leaked objects (e.g. the rooted Procs in #9508) to
  # their source. Off unless ENABLE_ALLOC_TRACE=true (significant CPU + memory).
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
    rescue StandardError => e
      warn("[zz_heap_debug] dump failed: #{e.class}: #{e.message}")
    end
  end

  # SIGUSR1: dump jemalloc allocator stats (allocated/active/resident/retained) via
  # mallctl, run IN-PROCESS so the numbers belong to PID 1 — `kubectl exec ruby` would
  # measure a fresh interpreter. Needs jemalloc preloaded (LD_PRELOAD). `resident -
  # allocated` is the retained/dirty-page gap (the native creep we can't see from
  # ObjectSpace). Pairs with MALLOC_CONF prof_accum (churn-by-function in jeprof dumps).
  Signal.trap("USR1") do
    Thread.new do
      require "fiddle"
      handle = Fiddle.dlopen(nil)
      sym = %w[mallctl je_mallctl].find do |s|
        handle[s]
        true
      rescue Fiddle::DLError
        false
      end
      raise "mallctl symbol not found (jemalloc not preloaded?)" unless sym

      mallctl = Fiddle::Function.new(
        handle[sym],
        [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_SIZE_T],
        Fiddle::TYPE_INT
      )
      mallctl.call("epoch\0", nil, nil, [1].pack("Q"), 8) # refresh cached stats

      read = lambda do |name|
        buf = "\0" * 8
        len = [8].pack("Q")
        mallctl.call("#{name}\0", buf, len, nil, 0).zero? ? buf.unpack1("Q") : nil
      end

      ts = Time.now.to_i
      File.open("/tmp/jestats-#{ts}.txt", "w") do |f|
        %w[stats.allocated stats.active stats.metadata stats.resident stats.mapped stats.retained].each do |name|
          v = read.call(name)
          f.puts("#{name} = #{v} (#{v ? (v / 1048576.0).round(1) : "?"} MB)")
        end
        f.puts("arenas.narenas = #{read.call("arenas.narenas")}")
        f.puts("arenas.dirty_decay_ms = #{read.call("arenas.dirty_decay_ms")}")
        f.puts("arenas.muzzy_decay_ms = #{read.call("arenas.muzzy_decay_ms")}")
        allocated = read.call("stats.allocated")
        resident = read.call("stats.resident")
        if allocated && resident
          f.puts("resident_minus_allocated_MB = #{((resident - allocated) / 1048576.0).round(1)} (retained/dirty/fragmentation)")
        end
      end
    rescue StandardError => e
      warn("[zz_heap_debug] mallctl dump failed: #{e.class}: #{e.message}")
    end
  end
end
