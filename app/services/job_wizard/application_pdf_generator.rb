# frozen_string_literal: true

module JobWizard
  # Centralized service for generating PDFs for applications
  # Eliminates duplication across controllers and background jobs
  class ApplicationPdfGenerator
    attr_reader :application, :allowed_skills, :job_posting

    def initialize(application, allowed_skills: nil, job_posting: nil)
      @application = application
      @allowed_skills = allowed_skills
      @job_posting = job_posting || application.job_posting
    end

    def generate!
      # Validate YAML configuration before generating
      validate_yaml_config!

      # Build PDFs
      builder = ResumeBuilder.new(
        job_description: application.job_description,
        allowed_skills: allowed_skills,
        job_posting: job_posting
      )

      # Setup output manager
      manager = PdfOutputManager.new(
        company: application.company,
        role: application.role,
        timestamp: application.created_at || Time.current
      )

      # Create directories and write PDFs
      manager.ensure_directories!
      manager.write_resume(builder.build_resume)
      manager.write_cover_letter(builder.build_cover_letter)
      manager.update_latest_symlink!

      # Capture unverified skills from AI generation (if any)
      unverified_skills = builder.unverified_skills

      # Update application status
      application.update!(
        output_path: manager.display_path,
        status: :generated
      )

      # Return paths and unverified skills for convenience
      {
        resume: manager.resume_path,
        cover_letter: manager.cover_letter_path,
        directory: manager.display_path,
        unverified_skills: unverified_skills
      }
    rescue StandardError => e
      application.update(status: :error)
      raise e
    end

    private

    def validate_yaml_config!
      # Validate YAML files are properly configured
      # This catches configuration errors early
      validator = YamlValidator.new
      validator.validate_profile!
      validator.validate_experience!

      if validator.errors.any?
        raise YamlValidator::ValidationError, "Configuration errors: #{validator.errors.join(', ')}"
      end
    rescue YamlValidator::ValidationError
      raise
    rescue StandardError => e
      Rails.logger.warn "YAML validation check failed: #{e.message}"
      # Don't fail PDF generation for validation warnings
    end
  end
end
