require_relative "system"
require "cgi"
require "time"

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

  # Policies that emit their own JUnit report should override this.
  def produces_junit?
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
    output_dir = args[:output_dir] || "out"
    System.prepare_directory(output_dir)
    fallback_junit_path = File.join(output_dir, "test-reports.xml")
    File.delete(fallback_junit_path) if File.exist?(fallback_junit_path)

    success = true
    fallback_failures = []

    policies.each do |policy|
      begin
        instance = policy.new(args)
      rescue RuntimeError => e
        puts "Error constructing #{policy.name}: #{e}"
        write_fallback_junit_report(
          fallback_junit_path,
          [{ name: policy.name, reason: "Error constructing policy: #{e}" }]
        )
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
        if !instance.produces_junit?
          fallback_failures << { name: policy.name, reason: instance.reason.to_s }
        end
        success = false
      end
    end

    if fallback_failures.any?
      write_fallback_junit_report(fallback_junit_path, fallback_failures)
    end

    # If any of the policies failed, the exit code should be non-zero
    if !success
      exit 1
    end
  end

  def self.write_fallback_junit_report(path, failures)
    timestamp = Time.now.utc.iso8601
    xml = []
    xml << %(<?xml version="1.0" encoding="UTF-8"?>)
    xml << %(<testsuites>)
    xml << %(<testsuite name="Security Toolbox Policy Failures" tests="#{failures.length}" failures="#{failures.length}" errors="0" skipped="0" timestamp="#{timestamp}">)

    failures.each do |failure|
      testcase_name = CGI.escapeHTML(failure[:name].to_s)
      message = CGI.escapeHTML(failure[:reason].to_s)
      xml << %(<testcase classname="security-toolbox.code" name="#{testcase_name}">)
      xml << %(<failure message="Policy failed">#{message}</failure>)
      xml << %(</testcase>)
    end

    xml << %(</testsuite>)
    xml << %(</testsuites>)

    File.write(path, xml.join("\n"))
  end
end
