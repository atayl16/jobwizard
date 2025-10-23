module JobWizard
  class RulesEngine
    def initialize
      @loader = RulesLoader.new
      @rejection_log = []
    end

    def should_reject?(job_posting)
      reasons = []

      # 1) Company blocklist check
      reasons << "Company '#{job_posting.company}' is blocked" if company_blocked?(job_posting.company)

      # 2) Content blocklist check
      reasons << 'Contains blocked content' if content_blocked?(job_posting.title, job_posting.description)

      # 3) Security clearance check
      if security_clearance_required?(job_posting.title, job_posting.description)
        reasons << 'Requires security clearance'
      end

      # 4) Required keywords check (unless manually added)
      unless manually_added?(job_posting) || has_required_keywords?(job_posting.title, job_posting.description)
        reasons << 'Missing required keywords (Ruby/Rails)'
      end

      # 5) Excluded keywords check
      reasons << 'Contains excluded keywords' if has_excluded_keywords?(job_posting.title, job_posting.description)

      rejected = reasons.any?
      log_rejection(job_posting, reasons) if rejected

      [rejected, reasons]
    end

    def recent_rejections(limit = 10)
      @rejection_log.last(limit)
    end

    private

    def company_blocked?(company_name)
      return false if company_name.blank?

      # Check YAML blocklist
      yaml_blocked = @loader.company_blocklist.any? do |blocked_name|
        if blocked_name.start_with?('/') && blocked_name.end_with?('/')
          regex_pattern = blocked_name[1..-2]
          begin
            Regexp.new(regex_pattern, true).match?(company_name)
          rescue RegexpError
            company_name.downcase.include?(blocked_name.downcase)
          end
        else
          company_name.downcase == blocked_name.downcase
        end
      end

      # Check DB blocklist
      db_blocked = BlockedCompany.matches_company?(company_name)

      yaml_blocked || db_blocked
    end

    def content_blocked?(title, description)
      text = "#{title} #{description}".downcase
      @loader.content_blocklist.any? { |term| text.include?(term.downcase) }
    end

    def security_clearance_required?(title, description)
      return false unless @loader.require_no_security_clearance?

      text = "#{title} #{description}".downcase

      # Check for excluded phrases (security clearance)
      excluded_found = @loader.excluded_phrases.any? { |phrase| text.include?(phrase.downcase) }

      # If background checks are allowed, don't reject for those phrases
      if @loader.allow_background_checks?
        allowed_found = @loader.allowed_phrases.any? { |phrase| text.include?(phrase.downcase) }
        excluded_found && !allowed_found
      else
        excluded_found
      end
    end

    def has_required_keywords?(title, description)
      text = "#{title} #{description}".downcase
      @loader.required_keywords.any? { |keyword| text.include?(keyword.downcase) }
    end

    def has_excluded_keywords?(title, description)
      text = "#{title} #{description}".downcase
      @loader.excluded_keywords.any? { |keyword| text.include?(keyword.downcase) }
    end

    def manually_added?(job_posting)
      # Check if job was manually added (not from fetchers)
      job_posting.source.blank? || job_posting.source == 'manual'
    end

    def log_rejection(job_posting, reasons)
      @rejection_log << {
        job_id: job_posting.id,
        company: job_posting.company,
        title: job_posting.title,
        reasons: reasons,
        timestamp: Time.current
      }

      # Keep only last 100 rejections
      @rejection_log = @rejection_log.last(100)
    end
  end
end
