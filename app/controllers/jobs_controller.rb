# frozen_string_literal: true

class JobsController < ApplicationController
  before_action :set_job, only: %i[show tailor applied exported ignore]

  # POST /jobs/fetch
  def fetch
    FetchJobsJob.perform_later
    redirect_to jobs_path, notice: 'Job fetch started in background. Refresh in a few moments.'
  end

  # GET /jobs
  def index
    @jobs = JobPosting.board_visible.by_score # Use board_visible scope for defense in depth

    # Apply filters
    @jobs = @jobs.search(params[:q]) if params[:q].present?
    @jobs = @jobs.posted_since(params[:days]) if params[:days].present?
    @jobs = @jobs.min_score(params[:min_score]) if params[:min_score].present?
    @jobs = @jobs.remote if params[:remote] == 'true'
    @jobs = @jobs.by_company(params[:company]) if params[:company].present?
    @jobs = @jobs.page(params[:page]).per(20) if defined?(Kaminari)

    # Load rules for UI banner
    @rules = JobWizard::Rules.current

    # Get source counts for the current filtered query
    @source_counts = @jobs.group(:source).count
  end

  # GET /jobs/:id
  def show
    @scanner = JobWizard::RulesScanner.new
    @scan_results = @scanner.scan(@job.description)
    @effective_skills_service = JobWizard::EffectiveSkillsService.new(@job)
    @skill_summary = @effective_skills_service.skill_summary
    @extracted_skills = extract_skills_from_description(@job.description)
    @existing_assessments = @job.job_skill_assessments.index_by(&:skill_name)
  end

  # POST /jobs/:id/tailor
  def tailor
    # Check if PDFs were already generated recently
    if @job.generated_today?
      redirect_to jobs_path, notice: 'PDFs were already generated today. Check your recent applications.'
      return
    end

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

    # Generate PDFs synchronously using centralized service
    begin
      JobWizard::ApplicationPdfGenerator.new(application, job_posting: @job).generate!

      # Mark job as exported after successful PDF generation
      @job.mark_exported!

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
      Rails.logger.error "PDF generation failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      redirect_to jobs_path, alert: "Error generating PDFs: #{e.message}"
    end
  end

  # PATCH /jobs/:id/applied
  def applied
    @job.mark_applied!
    redirect_to jobs_path, notice: 'Job marked as applied'
  end

  # PATCH /jobs/:id/exported
  def exported
    @job.mark_exported!
    redirect_to jobs_path, notice: 'Job marked as exported and hidden from suggestions'
  end

  # PATCH /jobs/:id/ignore
  def ignore
    @job.mark_ignored!
    redirect_to jobs_path, notice: 'Job ignored'
  end

  private

  def extract_skills_from_description(description)
    # Simple skill extraction - you can enhance this
    common_skills = %w[ruby rails javascript react python java sql postgresql mysql redis docker kubernetes aws azure
                       git github]

    text = description.downcase
    found_skills = common_skills.select { |skill| text.include?(skill) }
    found_skills.uniq.sort
  end

  def set_job
    @job = JobPosting.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to jobs_path, alert: 'Job posting not found or has been removed'
  end
end
