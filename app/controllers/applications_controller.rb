# frozen_string_literal: true

class ApplicationsController < ApplicationController
  before_action :set_application, only: %i[show download_resume download_cover_letter]

  # GET /applications
  def index
    @applications = Application.order(created_at: :desc)

    # Search
    if params[:q].present?
      query = params[:q]
      @applications = @applications.where(
        'company LIKE ? OR role LIKE ?',
        "%#{query}%", "%#{query}%"
      )
    end

    # Filter by status
    @applications = @applications.where(status: params[:status]) if params[:status].present?

    # Filter by date range
    @applications = @applications.where(created_at: (params[:date_from])..) if params[:date_from].present?
    @applications = @applications.where(created_at: ..(params[:date_to])) if params[:date_to].present?

    # Pagination (25 per page)
    @applications = @applications.page(params[:page]).per(25)
  end

  # GET /applications/:id
  def show
    @flags = {
      warnings: @application.warnings,
      blocking: @application.blocking_flags,
      info: @application.info_flags,
      unverified_skills: @application.unverified_skills
    }

    # Get not_claimed skills from ResumeBuilder
    builder = JobWizard::ResumeBuilder.new(job_description: @application.job_description)
    @not_claimed_skills = builder.not_claimed_skills
  end

  # GET /applications/new
  def new
    @application = Application.new
    @suggested_jobs = JobPosting.order(created_at: :desc).limit(5)
    @recent_applications = Application.order(created_at: :desc).limit(6)
  end

  # POST /applications
  def create
    job_description = extract_job_description

    # Extract company and role from params or description
    company = application_params[:company].presence || 'Unknown Company'
    role = application_params[:role].presence || 'Position'

    # Scan for flags
    scanner = JobWizard::RulesScanner.new
    scan_results = scanner.scan(job_description)

    # Create application record
    @application = Application.new(
      company: company,
      role: role,
      job_description: job_description,
      flags: scan_results,
      status: :draft
    )

    if @application.save
      # Generate PDFs using centralized service
      begin
        result = JobWizard::ApplicationPdfGenerator.new(@application).generate!

        # Store AI-generated unverified skills in flags if any
        if result[:unverified_skills]&.any?
          current_flags = @application.flags || {}
          current_flags['unverified_skills'] ||= []
          result[:unverified_skills].each do |skill|
            current_flags['unverified_skills'] << { 'skill' => skill, 'source' => 'ai_writer' }
          end
          @application.update(flags: current_flags)
        end

        redirect_to @application, notice: 'Application documents generated successfully!'
      rescue StandardError => e
        redirect_to @application, alert: "Error generating PDFs: #{e.message}"
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  # POST /applications/prepare
  def prepare
    job_description = extract_job_description
    company = params[:company].presence || 'Unknown Company'
    role = params[:role].presence || 'Position'

    # Detect skills using SkillDetector
    detector = JobWizard::SkillDetector.new(job_description)
    skill_analysis = detector.analyze

    # Store in session for finalize step
    session[:application_prepare] = {
      company: company,
      role: role,
      job_description: job_description,
      verified_skills: skill_analysis[:verified],
      unverified_skills: skill_analysis[:unverified]
    }

    @company = company
    @role = role
    @verified_skills = skill_analysis[:verified]
    @unverified_skills = skill_analysis[:unverified]
    @job_description = job_description

    render :prepare
  end

  # POST /applications/finalize
  def finalize
    prepare_data = session[:application_prepare]

    if prepare_data.blank?
      redirect_to new_application_path, alert: 'Session expired. Please start over.'
      return
    end

    # Get user's skill selections
    selected_verified = params[:verified_skills] || []
    selected_unverified = params[:unverified_skills] || []

    # Build final skill list
    included_skills = selected_verified + selected_unverified
    prepare_data[:verified_skills]
    prepare_data[:unverified_skills]

    # Scan for flags
    scanner = JobWizard::RulesScanner.new
    scan_results = scanner.scan(prepare_data[:job_description])

    # Create application record
    @application = Application.new(
      company: prepare_data[:company],
      role: prepare_data[:role],
      job_description: prepare_data[:job_description],
      flags: scan_results,
      status: :draft
    )

    if @application.save
      # Generate PDFs with skill filtering using centralized service
      begin
        result = JobWizard::ApplicationPdfGenerator.new(@application, allowed_skills: included_skills).generate!

        # Store AI-generated unverified skills in flags if any
        if result[:unverified_skills]&.any?
          current_flags = @application.flags || {}
          current_flags['unverified_skills'] ||= []
          result[:unverified_skills].each do |skill|
            current_flags['unverified_skills'] << { 'skill' => skill, 'source' => 'ai_writer' }
          end
          @application.update(flags: current_flags)
        end

        # Clear session
        session.delete(:application_prepare)

        redirect_to @application, notice: 'Application documents generated successfully!'
      rescue StandardError => e
        redirect_to @application, alert: "Error generating PDFs: #{e.message}"
      end
    else
      render :prepare, status: :unprocessable_entity
    end
  end

  # POST /applications/quick_create (from dashboard)
  def quick_create
    job_description = extract_job_description

    # Extract company and role from params or use parser fallback
    company = params[:company].presence
    role = params[:role].presence

    # If not provided, try to parse from JD
    if company.blank? || role.blank?
      parser = JobWizard::JdParser.new(job_description)
      company ||= parser.company || 'Unknown Company'
      role ||= parser.role || 'Position'
    end

    # Scan for flags
    scanner = JobWizard::RulesScanner.new
    scan_results = scanner.scan(job_description)

    # Create application record
    @application = Application.new(
      company: company,
      role: role,
      job_description: job_description,
      flags: scan_results,
      status: :draft
    )

    if @application.save
      # Generate PDFs using centralized service
      begin
        result = JobWizard::ApplicationPdfGenerator.new(@application).generate!

        # Store AI-generated unverified skills in flags if any
        if result[:unverified_skills]&.any?
          current_flags = @application.flags || {}
          current_flags['unverified_skills'] ||= []
          result[:unverified_skills].each do |skill|
            current_flags['unverified_skills'] << { 'skill' => skill, 'source' => 'ai_writer' }
          end
          @application.update(flags: current_flags)
        end

        respond_to do |format|
          format.html { redirect_to root_path, notice: "✓ PDFs generated for #{company} - #{role}" }
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.prepend('recent-applications',
                                   partial: 'dashboard/application_row',
                                   locals: { app: @application }),
              turbo_stream.update('flash-messages',
                                  partial: 'shared/flash',
                                  locals: { notice: "✓ PDFs generated for #{company} - #{role}" })
            ]
          end
        end
      rescue StandardError => e
        redirect_to root_path, alert: "Error generating PDFs: #{e.message}"
      end
    else
      redirect_to root_path, alert: "Error: #{@application.errors.full_messages.join(', ')}"
    end
  end

  # GET /applications/:id/resume
  def download_resume
    send_pdf(:resume)
  end

  # GET /applications/:id/cover_letter
  def download_cover_letter
    send_pdf(:cover_letter)
  end

  private

  def set_application
    @application = Application.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to applications_path, alert: 'Application not found'
  end

  def application_params
    params.expect(application: %i[company role job_description job_description_file])
  end

  def extract_job_description
    # Handle both formats: params[:application] (old) and direct params (quick_create)
    if params[:application].present?
      if params[:application][:job_description_file].present?
        file = params[:application][:job_description_file]
        file.read
      else
        application_params[:job_description]
      end
    elsif params[:job_description_file].present?
      file = params[:job_description_file]
      file.read
    else
      params[:job_description].to_s
    end
  end

  def send_pdf(type)
    return redirect_to @application, alert: 'PDFs not yet generated' unless @application.pdfs_ready?

    manager = JobWizard::PdfOutputManager.new(
      company: @application.company,
      role: @application.role,
      timestamp: @application.created_at
    )

    file_path = type == :resume ? manager.tmp_resume_path : manager.tmp_cover_letter_path
    filename = type == :resume ? 'resume.pdf' : 'cover_letter.pdf'

    send_file file_path, type: 'application/pdf', disposition: 'attachment', filename: filename
  end
end
