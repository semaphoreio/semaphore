require_relative "system"

class Policy
  def initialize(args)
    if deps_available?
      return
    end

    install = args[:install_dependencies] || false

    output_dir = args[:output_dir] || "out"
    # Prepare the output directory for reports
    System.prepare_directory(output_dir)

    if install
      puts "Installing dependencies #{dependency_names} for '#{self.class.name}'..."
      install_dependencies
    else
      raise "Some dependencies are missing: #{dependency_names}"
    end
  end

  # By default, policies have no dependencies
  def dependencies
    []
  end

  def dependency_names
    dependencies.map { |d| d[:name] }
  end

  def deps_available?
    dependency_names.all? do |dep|
      dep_available?(dep)
    end
  end

  def dep_available?(name)
    `which #{name}`
    $?.success?
  end

  def printable?
    false
  end

  def install_dependencies
    for dependency in dependencies do
        dependency_name = dependency[:name]
      if not dep_available?(dependency_name)
        puts "Installing #{dependency_name}..."
        exitstatus = dependency[:install].call
        if exitstatus != 0
          raise "Error installing #{dependency_name}"
        end

        puts "Installed #{dependency_name}."
      end
    end
  end

  def self.run_all(args, policies)
    success = true
    policies.each do |policy|
      begin
        instance = policy.new(args)
      rescue RuntimeError => e
        puts "Error constructing #{policy.name}: #{e}"
        exit 1
      end

      if instance.test
        puts "\e[32mOK   --- #{policy.name}\e[0m"
        if instance.printable?
          puts instance.reason
        end
      else
        puts "\e[31mFAIL --- #{policy.name}\e[0m"
        puts instance.reason
        success = false
      end
    end

    # If any of the policies failed, the exit code should be non-zero
    if !success
      exit 1
    end
  end
end
