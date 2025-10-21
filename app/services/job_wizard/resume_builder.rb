# frozen_string_literal: true

require 'prawn'

module JobWizard
  # Builds resume and cover letter PDFs using profile and experience data
  # Only uses verified information from YAML files - never fabricates
  #
  # Example:
  #   builder = ResumeBuilder.new(job_description: "Senior Rails Developer...")
  #   resume_pdf = builder.build_resume
  #   cover_letter_pdf = builder.build_cover_letter
  class ResumeBuilder
    attr_reader :job_description, :profile, :experience_loader, :claimed_skills, :not_claimed_skills, :allowed_skills

    def initialize(job_description:, allowed_skills: nil)
      @job_description = job_description
      @profile = load_profile
      @experience_loader = ExperienceLoader.new
      @allowed_skills = allowed_skills
      split_claimed_and_not_claimed_skills
    end

    # Build resume PDF as string
    def build_resume
      Prawn::Document.new(page_size: 'LETTER', margin: 50) do |pdf|
        # Header with contact info
        pdf.font 'Helvetica'
        pdf.text profile['name'], size: 24, style: :bold, align: :center
        pdf.move_down 5

        pdf.text format_contact_line, size: 10, align: :center
        pdf.move_down 20

        # Professional Summary
        pdf.text 'PROFESSIONAL SUMMARY', size: 12, style: :bold
        pdf.stroke_horizontal_rule
        pdf.move_down 5
        pdf.text profile['summary'], size: 10, align: :justify
        pdf.move_down 15

        # Skills
        add_skills_section(pdf)

        # Experience
        add_experience_section(pdf)

        # Education
        add_education_section(pdf) if profile['education']
      end.render
    end

    # Build cover letter PDF as string
    def build_cover_letter
      # Generate cover letter text using Writer
      writer = WriterFactory.build
      cover_letter_text = writer.cover_letter(
        profile: profile,
        experience: experience_loader,
        jd_text: job_description,
        company: extract_company_from_jd,
        role: extract_role_from_jd,
        allowed_skills: allowed_skills
      )

      # Render text into PDF
      Prawn::Document.new(page_size: 'LETTER', margin: 50) do |pdf|
        pdf.font 'Helvetica'
        
        # Split text into lines and render
        cover_letter_text.split("\n").each do |line|
          if line.strip.empty?
            pdf.move_down 10
          else
            pdf.text line, size: 10, align: :justify
            pdf.move_down 5
          end
        end
      end.render
    end

    private

    def extract_company_from_jd
      # Try to extract company from JD, fallback to generic
      parser = JdParser.new(job_description)
      parser.company || 'the company'
    end

    def extract_role_from_jd
      # Try to extract role from JD, fallback to generic
      parser = JdParser.new(job_description)
      parser.role || 'this position'
    end

    def load_profile
      profile_path = JobWizard::CONFIG_PATH.join('profile.yml')
      YAML.load_file(profile_path)
    end

    def split_claimed_and_not_claimed_skills
      # Extract skills from job description using RulesScanner logic
      jd_skills = extract_skills_from_jd

      @claimed_skills = []
      @not_claimed_skills = []

      jd_skills.each do |skill|
        # Use alias-aware skill checking
        normalized_skill = experience_loader.normalize_skill_name(skill)
        if experience_loader.has_skill?(normalized_skill) || experience_loader.has_skill_with_alias?(skill)
          @claimed_skills << skill
        else
          @not_claimed_skills << skill
        end
      end
    end

    def extract_skills_from_jd
      # Use similar logic to RulesScanner for skill extraction
      tech_pattern = %r{\b(Ruby on Rails|Rails|Ruby|React|JavaScript|TypeScript|Python|Java|Go|Rust|
                        PostgreSQL|MySQL|MongoDB|Redis|Elasticsearch|
                        AWS|Azure|GCP|Kubernetes|Docker|Terraform|
                        Git|GitHub|GitLab|CI/CD|Jenkins|CircleCI|
                        RSpec|Jest|Pytest|JUnit|
                        HTML|CSS|Sass|Tailwind|Bootstrap|
                        Node\.?js|Express|Django|Flask|Spring|
                        GraphQL|REST|API|Microservices|
                        Agile|Scrum|TDD|BDD|DevOps|
                        Linux|Unix|Bash|Shell|
                        Webpack|Vite|Rollup|Babel|
                        Datadog|Grafana|Prometheus|Sentry|PagerDuty)\b}ix

      job_description.to_s.scan(tech_pattern).flatten.uniq.map(&:strip)
    end

    def format_contact_line
      parts = []
      parts << profile['email'] if profile['email']
      parts << profile['phone'] if profile['phone']
      parts << profile['location'] if profile['location']
      parts << profile['linkedin'] if profile['linkedin']
      parts.join(' • ')
    end

    def add_skills_section(pdf)
      skills_by_level = experience_loader.skills_by_level

      pdf.text 'TECHNICAL SKILLS', size: 12, style: :bold
      pdf.stroke_horizontal_rule
      pdf.move_down 5

      # Filter skills by allowed_skills if provided
      skills_by_level = filter_skills_by_allowed(skills_by_level) if allowed_skills.present?

      # Expert/Core skills - highlight with context
      if skills_by_level[:expert].any?
        expert_phrases = skills_by_level[:expert].first(5).map do |skill|
          skill_phrase(skill)
        end
        pdf.text expert_phrases.join('; '), size: 10
      end

      pdf.move_down 5

      # Intermediate skills - working proficiency
      if skills_by_level[:intermediate].any?
        intermediate_names = skills_by_level[:intermediate].pluck(:name)
        pdf.text "Working proficiency: #{intermediate_names.join(', ')}", size: 10
      end

      pdf.move_down 5

      # Basic skills - familiar with
      if skills_by_level[:basic].any?
        basic_names = skills_by_level[:basic].pluck(:name)
        pdf.text "Also familiar with: #{basic_names.join(', ')}", size: 10
      end

      pdf.move_down 15
    end

    def filter_skills_by_allowed(skills_by_level)
      return skills_by_level if allowed_skills.blank?

      filtered = {}
      skills_by_level.each do |level, skills|
        filtered[level] = skills.select do |skill|
          allowed_skills.any? do |allowed|
            skill[:name].downcase.include?(allowed.downcase) || allowed.downcase.include?(skill[:name].downcase)
          end
        end
      end
      filtered
    end

    def skill_phrase(skill)
      base = case skill[:level]
             when :expert
               "Deep experience with #{skill[:name]}"
             when :intermediate
               "Working proficiency with #{skill[:name]}"
             when :basic
               "Familiar with #{skill[:name]}"
             else
               skill[:name]
             end

      # Add context if present and not too long
      if skill[:context] && skill[:context].length < 120
        "#{base} (#{skill[:context]})"
      else
        base
      end
    end

    def add_experience_section(pdf)
      return unless experience_loader.positions&.any?

      pdf.text 'PROFESSIONAL EXPERIENCE', size: 12, style: :bold
      pdf.stroke_horizontal_rule
      pdf.move_down 10

      experience_loader.positions.each do |position|
        # Company and title
        pdf.text position['company'], size: 11, style: :bold
        pdf.text "#{position['title']} | #{position['dates']}", size: 10, style: :italic
        pdf.move_down 5

        # Achievements as bullet points
        position['achievements']&.each do |achievement|
          pdf.text "• #{achievement}", size: 10
        end

        pdf.move_down 12
      end
    end

    def add_education_section(pdf)
      return unless profile['education']

      pdf.text 'EDUCATION', size: 12, style: :bold
      pdf.stroke_horizontal_rule
      pdf.move_down 5

      Array(profile['education']).each do |edu|
        pdf.text edu['degree'], size: 10, style: :bold
        pdf.text "#{edu['institution']} | #{edu['year']}", size: 10
        pdf.text edu['honors'], size: 10 if edu['honors'] && !edu['honors'].to_s.strip.empty?
        pdf.move_down 5
      end
    end

    def add_cover_letter_body(pdf)
      # Opening paragraph - express interest
      opening = 'I am writing to express my interest in the position described in your job posting. '
      opening += "With my background in #{extract_key_skills[0..2].join(', ')}, "
      opening += 'I am confident I can contribute meaningfully to your team.'

      pdf.text opening, size: 10, align: :justify
      pdf.move_down 12

      # Second paragraph - highlight relevant experience
      current_role = experience_loader.positions&.first
      if current_role
        middle = "In my current role as #{current_role['title']} at #{current_role['company']}, "
        middle += "I have #{current_role['achievements']&.first&.downcase || 'developed key technical skills'}. "
        middle += 'This experience has prepared me well for the challenges outlined in your position.'

        pdf.text middle, size: 10, align: :justify
        pdf.move_down 12
      end

      # Third paragraph - why interested
      closing = 'I am particularly drawn to this opportunity because of my passion for building quality software '
      closing += "and working collaboratively with talented teams. As #{profile['location']}, "
      closing += 'I am well-positioned for this role. I would welcome the opportunity to discuss how my skills '
      closing += 'and experience align with your needs.'

      pdf.text closing, size: 10, align: :justify
    end

    def extract_key_skills
      return [] unless profile['core_skills']

      # Return first few skills that are most relevant
      profile['core_skills'][0..4]
    end
  end
end
