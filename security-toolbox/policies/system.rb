class System
  def self.linux?
    RUBY_PLATFORM =~ /linux/ ? true : false
  end

  def self.mac?
    RUBY_PLATFORM =~ /darwin/ ? true : false
  end

  RunResult = Struct.new(:output, :status)

  def self.run(cmd)
    output = `#{cmd}`
    status = $?.exitstatus

    RunResult.new(output, status)
  end

  def self.has?(program)
    System.run("which #{program}").status == 0
  end

  def self.os_name
    if System.linux?
      @os_name ||= `cat /etc/os-release | awk -F= '$1=="NAME" { print $2 ;}' | sed 's|"||g'`.strip
    elsif System.mac?
      @os_name ||= `sw_vers -productName`.strip
    else
      raise "unknwown os name"
    end
  end

  def self.os_version
    if System.linux?
      @os_version ||= `cat /etc/os-release | awk -F= '$1=="VERSION_ID" { print $2 ;}' | sed 's|"||g'`.strip
    elsif System.mac?
      @os_version ||= `sw_vers -productVersion`.strip.split('.')[0]
    else
      raise "unknwown os version"
    end
  end
end
