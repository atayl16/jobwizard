#!/usr/bin/env ruby
# frozen_string_literal: true

# Standalone smoke test for ResumeBuilder (no database required)
# Run with: ruby test/smoke_test_resume_builder.rb

require 'pathname'
require 'yaml'
require 'date'
require 'prawn'

# Load the service
require_relative '../app/services/job_wizard/resume_builder'

# Mock Rails and JobWizard constants
module Rails
  def self.root
    Pathname.new(File.expand_path('..', __dir__))
  end
end

module JobWizard
  CONFIG_PATH = Rails.root.join('config/job_wizard')
end

# Test helpers
def assert(condition, message)
  raise "Assertion failed: #{message}" unless condition

  puts "✓ #{message}"
end

def assert_kind_of(klass, object, message)
  raise "Expected #{object.class}, got #{klass}: #{message}" unless object.is_a?(klass)

  puts "✓ #{message}"
end

# Run tests
begin
  puts "\n🧪 Starting ResumeBuilder smoke test...\n\n"

  job_description = <<~JD
    Senior Ruby on Rails Developer

    We are seeking an experienced Rails developer to join our remote team.
    You will work with PostgreSQL, Redis, and modern JavaScript frameworks.

    Requirements:
    - 5+ years of Rails experience
    - Strong PostgreSQL skills
    - Experience with testing (RSpec)
    - Excellent communication skills

    Competitive salary and benefits package.
  JD

  builder = JobWizard::ResumeBuilder.new(job_description: job_description)

  # Test 1: Initialization
  puts 'Test 1: Initialization'
  assert_not builder.profile.nil?, 'Profile loaded'
  assert_not builder.experience.nil?, 'Experience loaded'
  assert builder.profile['name'], 'Profile has name'
  assert builder.experience['positions'], 'Experience has positions'

  # Test 2: Resume generation
  puts "\nTest 2: Resume PDF generation"
  resume_pdf = builder.build_resume

  assert_kind_of String, resume_pdf, 'Resume PDF generated as string'
  assert resume_pdf.length > 1000, "Resume PDF has reasonable size (#{resume_pdf.length} bytes)"
  assert resume_pdf.start_with?('%PDF'), 'Resume is valid PDF format'

  # Write to temp file to verify
  resume_path = "/tmp/test_resume_#{Time.now.to_i}.pdf"
  File.write(resume_path, resume_pdf, mode: 'wb')
  assert File.exist?(resume_path), 'Resume PDF written to disk'
  puts "  📄 Resume saved to: #{resume_path}"

  # Test 3: Cover letter generation
  puts "\nTest 3: Cover letter PDF generation"
  cover_pdf = builder.build_cover_letter

  assert_kind_of String, cover_pdf, 'Cover letter PDF generated as string'
  assert cover_pdf.length > 500, "Cover letter PDF has reasonable size (#{cover_pdf.length} bytes)"
  assert cover_pdf.start_with?('%PDF'), 'Cover letter is valid PDF format'

  # Write to temp file to verify
  cover_path = "/tmp/test_cover_letter_#{Time.now.to_i}.pdf"
  File.write(cover_path, cover_pdf, mode: 'wb')
  assert File.exist?(cover_path), 'Cover letter PDF written to disk'
  puts "  📄 Cover letter saved to: #{cover_path}"

  # Test 4: Content verification (basic)
  puts "\nTest 4: Content verification"

  # PDFs should be valid and non-empty
  assert resume_pdf.start_with?('%PDF'), 'Resume is valid PDF'
  assert cover_pdf.start_with?('%PDF'), 'Cover letter is valid PDF'

  # Should have reasonable content size
  assert cover_pdf.length > 1000, 'Cover letter has substantial content'
  assert resume_pdf.length > 1000, 'Resume has substantial content'

  # Test 5: Multiple builds (should be idempotent)
  puts "\nTest 5: Multiple builds"
  resume_pdf2 = builder.build_resume
  cover_pdf2 = builder.build_cover_letter

  assert resume_pdf2.length == resume_pdf.length, 'Resume builds consistently'
  assert cover_pdf2.length == cover_pdf.length, 'Cover letter builds consistently'

  puts "\n✅ All tests passed!\n"

  # Summary
  puts '📊 ResumeBuilder Summary:'
  puts "   - Resume size: #{resume_pdf.length} bytes"
  puts "   - Cover letter size: #{cover_pdf.length} bytes"
  puts "   - Applicant: #{builder.profile['name']}"
  puts "   - Experience entries: #{builder.experience['positions'].length}"
  puts "   - Skills: #{builder.profile['core_skills'].length}"
  puts "\n📁 Test PDFs saved to:"
  puts "   #{resume_path}"
  puts "   #{cover_path}"
  puts "\n💡 Open these PDFs to visually verify formatting and content"
rescue StandardError => e
  puts "\n❌ Test failed: #{e.message}"
  puts e.backtrace.first(10)
  exit 1
end

puts "\n🎉 ResumeBuilder smoke test complete!"
