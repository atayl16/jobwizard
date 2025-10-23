# frozen_string_literal: true

class GeneratePdfsJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: 5.seconds, attempts: 3

  def perform(job_posting_id)
    job_posting = JobPosting.find(job_posting_id)

    # Scan for flags
    scanner = JobWizard::RulesScanner.new
    scan_results = scanner.scan(job_posting.description)

    # Create application record
    application = Application.create!(
      job_posting: job_posting,
      company: job_posting.company,
      role: job_posting.title,
      job_description: job_posting.description,
      flags: scan_results,
      status: :draft
    )

    # Generate PDFs using centralized service
    JobWizard::ApplicationPdfGenerator.new(application, job_posting: job_posting).generate!
  end
end
