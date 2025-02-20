class Timer
  def initialize(start_time, end_time = nil)
    @start_time = start_time
    @finished = end_time.present?
    @end_time = end_time || Time.now
  end

  def time_elapsed
    return 0 unless @start_time
    @end_time.to_i - @start_time.to_i
  end

  def pretty_time
    Time.at(time_elapsed).utc.strftime("%H:%M:%S").gsub(/^00:/, "")
  end

  def verbose_time
    Time.at(time_elapsed).utc.strftime("%Hh %Mm %Ss").gsub(/^00h /, "")
  end

  def finished?
    @finished
  end
end
