#!/usr/bin/env ruby
# frozen_string_literal: true

# Standalone smoke test for RulesScanner (no database required)
# Run with: ruby test/smoke_test_rules_scanner.rb

require 'pathname'
require 'yaml'

# Load the service
require_relative '../app/services/job_wizard/rules_scanner'

# Mock Rails and JobWizard constants
module Rails
  def self.root
    Pathname.new(File.expand_path('..', __dir__))
  end
end

module JobWizard
  CONFIG_PATH = Rails.root.join('config', 'job_wizard')
end

# Test helpers
def assert(condition, message)
  raise "Assertion failed: #{message}" unless condition
  puts "✓ #{message}"
end

def assert_includes(array, item, message)
  raise "Expected array to include #{item}: #{message}" unless array.include?(item)
  puts "✓ #{message}"
end

def assert_not_includes(array, item, message)
  raise "Expected array not to include #{item}: #{message}" if array.include?(item)
  puts "✓ #{message}"
end

# Run tests
begin
  puts "\n🧪 Starting RulesScanner smoke test...\n\n"
  
  scanner = JobWizard::RulesScanner.new
  
  # Test 1: US citizenship flag
  puts "Test 1: US citizenship detection"
  jd1 = "Must be a US citizen or authorized to work in the United States."
  result1 = scanner.scan(jd1)
  assert result1[:warnings].any? { |w| w[:rule] == 'us_only_role' }, "US citizenship flag detected"
  
  # Test 2: Location restrictions
  puts "\nTest 2: Location restriction detection"
  jd2 = "This is an on-site only position. No remote work."
  result2 = scanner.scan(jd2)
  assert result2[:warnings].any? { |w| w[:rule] == 'location_restricted' }, "Location restriction detected"
  
  # Test 3: Unpaid position (blocking)
  puts "\nTest 3: Unpaid position detection"
  jd3 = "This is an unpaid internship opportunity."
  result3 = scanner.scan(jd3)
  assert result3[:blocking].any? { |b| b[:rule] == 'unpaid' }, "Unpaid position flagged as blocking"
  assert scanner.blocking_flags?(jd3), "blocking_flags? returns true"
  
  # Test 4: Commission only
  puts "\nTest 4: Commission-only detection"
  jd4 = "100% commission based, no base salary."
  result4 = scanner.scan(jd4)
  assert result4[:blocking].any? { |b| b[:rule] == 'commission_only' }, "Commission-only flagged"
  
  # Test 5: Info flags (equity, startup)
  puts "\nTest 5: Info flags detection"
  jd5 = "Fast-paced startup with equity compensation and stock options."
  result5 = scanner.scan(jd5)
  assert result5[:info].any? { |i| i[:rule] == 'equity_mentioned' }, "Equity mention detected"
  assert result5[:info].any? { |i| i[:rule] == 'startup_indicators' }, "Startup indicator detected"
  
  # Test 6: Clean job description
  puts "\nTest 6: Clean job description"
  jd6 = "Remote Senior Rails Developer. Work with PostgreSQL and Redis. Competitive salary and benefits."
  result6 = scanner.scan(jd6)
  assert result6[:warnings].empty?, "No warnings for clean JD"
  assert result6[:blocking].empty?, "No blocking flags for clean JD"
  assert scanner.clean?(jd6), "clean? returns true"
  
  # Test 7: Unverified skills detection
  puts "\nTest 7: Unverified skills detection"
  jd7 = "Need experience with Python, Django, React, and Ruby on Rails."
  result7 = scanner.scan(jd7)
  unverified_skills = result7[:unverified_skills].map { |s| s[:skill] }
  
  if result7[:unverified_skills].any?
    puts "  Found #{unverified_skills.length} unverified skill(s): #{unverified_skills.join(', ')}"
    # Python and Django should be unverified, Rails should be verified
    assert_includes unverified_skills, 'Python', "Python flagged as unverified"
    assert_not_includes unverified_skills, 'Rails', "Rails not flagged (is verified)"
  else
    puts "  No unverified skills detected"
  end
  
  # Test 8: Empty/nil input
  puts "\nTest 8: Empty/nil input handling"
  result_nil = scanner.scan(nil)
  result_empty = scanner.scan("")
  assert result_nil[:warnings].empty?, "Nil input handled gracefully"
  assert result_empty[:warnings].empty?, "Empty string handled gracefully"
  
  # Test 9: Multiple flags
  puts "\nTest 9: Multiple flags detection"
  jd9 = "Unpaid startup internship. Must be US citizen. On-site only in SF."
  result9 = scanner.scan(jd9)
  assert result9[:blocking].length >= 1, "At least one blocking flag"
  assert result9[:warnings].length >= 1, "At least one warning flag"
  puts "  Found #{result9[:blocking].length} blocking flag(s)"
  puts "  Found #{result9[:warnings].length} warning(s)"
  puts "  Found #{result9[:info].length} info flag(s)"
  
  puts "\n✅ All tests passed!\n"
  
  # Summary
  puts "📊 RulesScanner Summary:"
  puts "   - Warnings: Location, citizenship, timezone requirements"
  puts "   - Blocking: Unpaid, commission-only, MLM"
  puts "   - Info: Equity, benefits, startup indicators"
  puts "   - Skill verification: Checks against experience.yml"
  
rescue => e
  puts "\n❌ Test failed: #{e.message}"
  puts e.backtrace.first(5)
  exit 1
end

puts "\n🎉 RulesScanner smoke test complete!"

