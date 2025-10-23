#!/usr/bin/env ruby
# frozen_string_literal: true

# Standalone smoke test for PdfOutputManager (no database required)
# Run with: ruby test/smoke_test_pdf_output_manager.rb

require 'pathname'
require 'fileutils'
require 'time'

# Load the service
require_relative '../app/services/job_wizard/pdf_output_manager'

# Mock JobWizard constants
module JobWizard
  OUTPUT_ROOT = Pathname.new("/tmp/job_wizard_test_#{Time.now.to_i}")
  TMP_OUTPUT_ROOT = OUTPUT_ROOT.join('tmp')
end

# Test helpers
def assert(condition, message)
  raise "Assertion failed: #{message}" unless condition

  puts "✓ #{message}"
end

def assert_equal(expected, actual, message)
  raise "Expected #{expected.inspect}, got #{actual.inspect}: #{message}" unless expected == actual

  puts "✓ #{message}"
end

# Cleanup function
def cleanup!
  FileUtils.rm_rf(JobWizard::OUTPUT_ROOT)
  puts "\n🧹 Cleaned up test directory"
end

# Run tests
begin
  puts "\n🧪 Starting PdfOutputManager smoke test...\n\n"

  # Test 1: Initialization
  puts 'Test 1: Initialization'
  manager = JobWizard::PdfOutputManager.new(
    company: 'Acme Corp & Co.',
    role: 'Senior Engineer (Remote)',
    timestamp: Time.zone.parse('2025-01-15 10:30:00')
  )

  assert manager.output_path.to_s.include?('AcmeCorp'), 'Company slug created'
  assert manager.output_path.to_s.include?('SeniorEngineerRemote'), 'Role slug created'
  assert manager.output_path.to_s.include?('2025-01-15'), 'Date slug created'
  assert manager.tmp_path.to_s.include?('tmp'), 'Tmp path created'

  # Test 2: Directory creation
  puts "\nTest 2: Directory creation"
  manager.ensure_directories!

  assert File.directory?(manager.output_path), 'Output directory exists'
  assert File.directory?(manager.tmp_path), 'Tmp directory exists'

  # Test 3: Resume writing
  puts "\nTest 3: Resume writing"
  resume_content = 'Fake resume PDF content'
  manager.write_resume(resume_content)

  assert File.exist?(manager.resume_path), 'Resume file exists in output'
  assert File.exist?(manager.tmp_resume_path), 'Resume file exists in tmp'
  assert_equal resume_content, File.read(manager.resume_path), 'Resume content correct'

  # Test 4: Cover letter writing
  puts "\nTest 4: Cover letter writing"
  cover_content = 'Fake cover letter PDF content'
  manager.write_cover_letter(cover_content)

  assert File.exist?(manager.cover_letter_path), 'Cover letter exists in output'
  assert File.exist?(manager.tmp_cover_letter_path), 'Cover letter exists in tmp'
  assert_equal cover_content, File.read(manager.cover_letter_path), 'Cover letter content correct'

  # Test 5: PDFs exist check
  puts "\nTest 5: PDFs existence check"
  assert manager.pdfs_exist?, 'Both PDFs exist'

  # Test 6: Latest symlink
  puts "\nTest 6: Latest symlink"
  manager.update_latest_symlink!

  latest_path = JobWizard::OUTPUT_ROOT.join('Latest')
  assert File.symlink?(latest_path), 'Latest symlink created'
  assert_equal manager.output_path.to_s, File.readlink(latest_path), 'Latest points to correct path'

  # Test 7: Symlink updates
  puts "\nTest 7: Symlink updates with new application"
  manager2 = JobWizard::PdfOutputManager.new(
    company: 'New Company',
    role: 'Developer',
    timestamp: Time.zone.parse('2025-01-16 14:00:00')
  )
  manager2.ensure_directories!
  manager2.write_resume('New resume')
  manager2.write_cover_letter('New cover')
  manager2.update_latest_symlink!

  assert_equal manager2.output_path.to_s, File.readlink(latest_path), 'Latest updated to newest application'

  # Test 8: Special character handling
  puts "\nTest 8: Special character handling"
  manager3 = JobWizard::PdfOutputManager.new(
    company: "O'Reilly & Associates!",
    role: 'Dev/Ops (24/7)',
    timestamp: Time.zone.parse('2025-01-17')
  )
  manager3.ensure_directories!

  assert manager3.output_path.to_s.include?('OReillyAssociates'), 'Special chars removed from company'
  assert manager3.output_path.to_s.include?('DevOps247'), 'Special chars removed from role'
  assert File.directory?(manager3.output_path), 'Directory with cleaned name exists'

  # Test 9: Display path
  puts "\nTest 9: Display path"
  display = manager.display_path
  assert display.include?('Applications'), 'Display path includes Applications'
  assert display.include?('AcmeCorp'), 'Display path includes company'
  assert display.include?('SeniorEngineerRemote'), 'Display path includes role'

  puts "\n✅ All tests passed!\n"
  puts "📁 Test output location: #{JobWizard::OUTPUT_ROOT}"
  puts "📂 Sample application path: #{manager.display_path}"
  puts "🔗 Latest symlink: #{latest_path} → #{File.readlink(latest_path)}"
rescue StandardError => e
  puts "\n❌ Test failed: #{e.message}"
  puts e.backtrace.first(5)
  cleanup!
  exit 1
ensure
  cleanup!
end

puts "\n🎉 PdfOutputManager smoke test complete!"
