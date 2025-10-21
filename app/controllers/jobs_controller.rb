# frozen_string_literal: true

class JobsController < ApplicationController
  before_action :set_job, only: %i[show tailor]

  # GET /jobs
  def index
    @jobs = JobPosting.recent
    @jobs = @jobs.remote if params[:remote] == 'true'
    @jobs = @jobs.by_company(params[:company]) if params[:company].present?
    @jobs = @jobs.page(params[:page]).per(20) if defined?(Kaminari)
  end

  # GET /jobs/:id
  def show
    @scanner = JobWizard::RulesScanner.new
    @scan_results = @scanner.scan(@job.description)
  end

  # POST /jobs/:id/tailor
  def tailor
    # Create an application for this job
    scanner = JobWizard::RulesScanner.new
    scan_results = scanner.scan(@job.description)

    application = Application.create!(
      company: @job.company,
      role: @job.title,
      job_description: @job.description,
      job_posting: @job,
      flags: scan_results,
      status: :draft
    )

    # Generate PDFs synchronously for dashboard (or async with GeneratePdfsJob)
    begin
      builder = JobWizard::ResumeBuilder.new(job_description: application.job_description)
      manager = JobWizard::PdfOutputManager.new(
        company: application.company,
        role: application.role,
        timestamp: Time.current
      )

      manager.ensure_directories!
      resume_pdf = builder.build_resume
      cover_letter_pdf = builder.build_cover_letter

      manager.write_resume(resume_pdf)
      manager.write_cover_letter(cover_letter_pdf)
      manager.update_latest_symlink!

      application.update(output_path: manager.display_path, status: :generated)

      respond_to do |format|
        format.html { redirect_to root_path, notice: "✓ PDFs generated for #{application.company}" }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace("job_#{@job.id}",
              partial: 'dashboard/job_generated',
              locals: { job: @job, application: application }),
            turbo_stream.prepend('recent-applications',
              partial: 'dashboard/application_row',
              locals: { app: application })
          ]
        end
      end
    rescue StandardError => e
      application.update(status: :error)
      redirect_to root_path, alert: "Error: #{e.message}"
    end
  end

  private

  def set_job
    @job = JobPosting.find(params[:id])
  end
end
