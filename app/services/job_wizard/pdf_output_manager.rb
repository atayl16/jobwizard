# frozen_string_literal: true

module JobWizard
  # Manages filesystem output for generated PDFs
  # Creates structured directories and maintains "Latest" symlink
  #
  # Example:
  #   manager = PdfOutputManager.new(company: "Acme Corp", role: "Senior Engineer")
  #   manager.ensure_directories!
  #   manager.write_resume(resume_pdf.render)
  #   manager.write_cover_letter(cover_letter_pdf.render)
  #   manager.update_latest_symlink!
  #
  # Output structure:
  #   ~/Documents/JobWizard/
  #     Applications/
  #       AcmeCorp/
  #         SeniorEngineer/
  #           2025-01-15/
  #             resume.pdf
  #             cover_letter.pdf
  #     Latest -> Applications/AcmeCorp/SeniorEngineer/2025-01-15/
  class PdfOutputManager
    attr_reader :company, :role, :timestamp, :output_path, :tmp_path

    def initialize(company:, role:, timestamp: Time.current)
      @company = company
      @role = role
      @timestamp = timestamp
      @company_slug = slugify(company)
      @role_slug = slugify(role)
      @date_slug = timestamp.strftime('%Y-%m-%d')
      @path_style = ENV['JOB_WIZARD_PATH_STYLE']&.downcase || 'simple'
      @output_path = build_output_path
      @tmp_path = build_tmp_path
    end

    # Create all necessary directories
    def ensure_directories!
      FileUtils.mkdir_p(output_path)
      FileUtils.mkdir_p(tmp_path)
      self
    end

    # Write resume PDF to both output and tmp locations
    def write_resume(pdf_content)
      write_file('resume.pdf', pdf_content)
    end

    # Write cover letter PDF to both output and tmp locations
    def write_cover_letter(pdf_content)
      write_file('cover_letter.pdf', pdf_content)
    end

    # Update the "Latest" symlink to point to this application folder
    def update_latest_symlink!
      latest_path = JobWizard::OUTPUT_ROOT.join('Latest')

      # Remove existing symlink if present
      FileUtils.rm_f(latest_path) if File.symlink?(latest_path) || File.exist?(latest_path)

      # Create new symlink
      FileUtils.ln_s(output_path, latest_path)

      self
    end

    # Full path to resume file
    def resume_path
      output_path.join('resume.pdf')
    end

    # Full path to cover letter file
    def cover_letter_path
      output_path.join('cover_letter.pdf')
    end

    # Tmp paths for Rails download
    def tmp_resume_path
      tmp_path.join('resume.pdf')
    end

    def tmp_cover_letter_path
      tmp_path.join('cover_letter.pdf')
    end

    # Human-readable path for UI display
    def display_path
      output_path.to_s
    end

    # Check if PDFs exist
    def pdfs_exist?
      File.exist?(resume_path) && File.exist?(cover_letter_path)
    end

    private

    # Build output path based on style preference
    def build_output_path
      case @path_style
      when 'simple'
        # Simple: ~/Documents/JobWizard/Company - Role - YYYY-MM-DD/
        folder_name = "#{@company} - #{@role} - #{@date_slug}"
        JobWizard::OUTPUT_ROOT.join(folder_name)
      else
        # Nested: ~/Documents/JobWizard/Applications/Company/Role/YYYY-MM-DD/
        JobWizard::OUTPUT_ROOT.join('Applications', @company_slug, @role_slug, @date_slug)
      end
    end

    # Build tmp path for Rails downloads (always nested for consistency)
    def build_tmp_path
      JobWizard::TMP_OUTPUT_ROOT.join('Applications', @company_slug, @role_slug, @date_slug)
    end

    # Convert string to filesystem-safe slug
    # "Acme Corp & Co." => "AcmeCorp"
    # "Senior Engineer (Remote)" => "SeniorEngineerRemote"
    # SECURITY: Rejects path traversal patterns
    def slugify(text)
      # Reject dangerous patterns FIRST (before any transformations)
      text_str = text.to_s
      if text_str =~ /\.\./ || text_str =~ %r{[/\\]}
        raise ArgumentError, "Invalid path characters detected: #{text_str.inspect}"
      end

      text_str
        .gsub(/[^\w\s-]/, '') # Remove special characters
        .gsub(/\s+/, '')       # Remove spaces
        .gsub(/-+/, '')        # Remove hyphens
        .strip
        .slice(0, 100)         # Limit length
    end

    # Write file to both output and tmp locations
    def write_file(filename, content)
      # Write to main output directory
      File.write(output_path.join(filename), content, mode: 'wb')

      # Write to tmp directory for Rails downloads
      File.write(tmp_path.join(filename), content, mode: 'wb')

      output_path.join(filename)
    end
  end
end
