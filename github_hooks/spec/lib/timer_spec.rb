require "spec_helper"

RSpec.describe Timer do
  describe "time elapsed" do
    it "calculate duration if finished" do
      start = Time.parse("Thu, 15 Sep 2016 04:47:13 UTC +00:00")
      finish = Time.parse("Thu, 15 Sep 2016 04:49:58 UTC +00:00")

      @timer = Timer.new(start, finish)

      expect(@timer.time_elapsed).to eql(165)
      expect(@timer.finished?).to eql(true)
      expect(@timer.pretty_time).to eql("02:45")
    end

    it "calculate duration till current time if not finished" do
      Timecop.freeze do
        start = 1.minutes.ago
        @timer = Timer.new(start)
      end
      expect(@timer.time_elapsed).to eql(60)
      expect(@timer.finished?).to eql(false)
      expect(@timer.pretty_time).to eql("01:00")
    end

    it "print duration in hh:mm:ss" do
      start = Time.parse("Thu, 15 Sep 2016 04:47:13 UTC +00:00")
      finish = Time.parse("Thu, 15 Sep 2016 06:49:58 UTC +00:00")

      @timer = Timer.new(start, finish)

      expect(@timer.time_elapsed).to eql(7365)
      expect(@timer.pretty_time).to eql("02:02:45")
    end

    it "does not show hour if zero" do
      start = Time.parse("Thu, 15 Sep 2016 04:47:13 UTC +00:00")
      finish = Time.parse("Thu, 15 Sep 2016 04:49:58 UTC +00:00")

      @timer = Timer.new(start, finish)

      expect(@timer.pretty_time).to eql("02:45")
    end
  end

  describe "verbose_timer" do
    it "pretty prints the verbose time" do
      start = Time.parse("Thu, 15 Sep 2016 04:47:13 UTC +00:00")
      finish = Time.parse("Thu, 15 Sep 2016 06:49:58 UTC +00:00")

      @timer = Timer.new(start, finish)

      expect(@timer.verbose_time).to eql("02h 02m 45s")
    end

    it "does not show hour if 00h" do
      start = Time.parse("Thu, 15 Sep 2016 04:47:13 UTC +00:00")
      finish = Time.parse("Thu, 15 Sep 2016 04:49:58 UTC +00:00")

      @timer = Timer.new(start, finish)

      expect(@timer.verbose_time).to eql("02m 45s")
    end
  end
end
