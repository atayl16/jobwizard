# frozen_string_literal: true

class GeneratePdfsJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: 5.seconds, attempts: 3

  def perform(job_posting_id)
    job_posting = JobPosting.find(job_posting_id)

    # Create application record
    application = Application.create!(
      job_posting: job_posting,
      company: job_posting.company,
      role: job_posting.title,
      job_description: job_posting.description,
      status: :draft
    )

    # Scan for flags
    scanner = JobWizard::RulesScanner.new
    scan_results = scanner.scan(job_posting.description)
    application.update(flags: scan_results)

    # Generate PDFs
    builder = JobWizard::ResumeBuilder.new(job_description: job_posting.description)
    manager = JobWizard::PdfOutputManager.new(
      company: job_posting.company,
      role: job_posting.title,
      timestamp: Time.current
    )

    manager.ensure_directories!

    resume_pdf = builder.build_resume
    cover_letter_pdf = builder.build_cover_letter

    manager.write_resume(resume_pdf)
    manager.write_cover_letter(cover_letter_pdf)
    manager.update_latest_symlink!

    application.update(output_path: manager.display_path, status: :generated)
  rescue StandardError => e
    application&.update(status: :error)
    raise e
  end
end
