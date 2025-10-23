# frozen_string_literal: true

module JobWizard
  # Scans job descriptions against rules.yml to identify flags, warnings, and requirements
  #
  # Example:
  #   scanner = RulesScanner.new
  #   flags = scanner.scan(job_description_text)
  #   # => { warnings: [...], blocking: [...], info: [...], unverified_skills: [...] }
  class RulesScanner
    attr_reader :rules, :experience_loader

    def initialize
      @rules = load_rules
      @experience_loader = ExperienceLoader.new
    end

    # Scan job description and return categorized flags
    # Returns hash with keys: :warnings, :blocking, :info, :unverified_skills, :not_claimed_skills
    def scan(job_description)
      return empty_result if job_description.nil? || job_description.to_s.strip.empty?

      result = {
        warnings: [],
        blocking: [],
        info: [],
        unverified_skills: [],
        not_claimed_skills: []
      }

      # Scan each category
      scan_category(job_description, :warnings, result)
      scan_category(job_description, :blocking, result)
      scan_category(job_description, :info, result)

      # Check for unverified skills if enabled
      categorize_skills(job_description, result) if rules.dig('skill_verification', 'flag_unverified')

      result
    end

    # Check if job description has any blocking flags
    def blocking_flags?(job_description)
      scan(job_description)[:blocking].any?
    end

    # Check if job description is clean (no warnings or blocking)
    def clean?(job_description)
      result = scan(job_description)
      result[:warnings].empty? && result[:blocking].empty?
    end

    private

    def load_rules
      rules_path = JobWizard::CONFIG_PATH.join('rules.yml')
      return {} unless File.exist?(rules_path)

      YAML.load_file(rules_path) || {}
    end

    def scan_category(text, category, result)
      category_rules = rules[category.to_s]
      return unless category_rules

      category_rules.each do |rule_name, rule_data|
        next unless matches_any_pattern?(text, rule_data)

        result[category] << build_flag(rule_name, rule_data)
      end
    end

    def matches_any_pattern?(text, rule_data)
      patterns = Array(rule_data['patterns'] || rule_data['pattern'])
      patterns.any? { |pattern| text.match?(Regexp.new(pattern, Regexp::IGNORECASE)) }
    end

    def build_flag(rule_name, rule_data)
      {
        rule: rule_name,
        message: rule_data['message'],
        note: rule_data['note'],
        severity: rule_data['severity']
      }
    end

    def categorize_skills(text, result)
      # Extract potential skills from job description
      potential_skills = extract_potential_skills(text)

      # Categorize each skill:
      # 1. Verified: in skills[].name (with alias normalization)
      # 2. Not Claimed: in not_claimed_skills (exposure only)
      # 3. Unverified: neither verified nor not_claimed

      potential_skills.each do |skill|
        # Normalize skill using aliases before checking
        normalized_skill = experience_loader.normalize_skill_name(skill)

        if experience_loader.has_skill?(normalized_skill) || experience_loader.has_skill_with_alias?(skill)
          # Verified - skip, this is OK
          next
        elsif experience_loader.not_claimed_skill?(skill)
          # Not claimed - flag as exposure only
          result[:not_claimed_skills] << {
            skill: skill,
            message: 'Skill mentioned but marked as exposure-only (not core competency)',
            action: 'mention_as_exposure'
          }
        else
          # Unverified - flag as unverified
          result[:unverified_skills] << {
            skill: skill,
            message: rules.dig('skill_verification', 'message') || 'Skill not in verified experience',
            action: rules.dig('skill_verification', 'action') || 'mark_as_not_claimed'
          }
        end
      end
    end

    def extract_potential_skills(text)
      # Common tech keywords and patterns
      tech_patterns = [
        # Languages
        /\b(Ruby|Python|JavaScript|TypeScript|Java|Go|Rust|PHP|C\+\+|C#|Swift|Kotlin|Elixir|Zig)\b/i,
        # Frameworks
        /\b(Rails|Django|React|Vue|Angular|Node\.js|Express|Flask|Laravel|Spring|Phoenix)\b/i,
        # Databases
        /\b(PostgreSQL|MySQL|MongoDB|Redis|Elasticsearch|DynamoDB|SQLite)\b/i,
        # Cloud/DevOps
        /\b(AWS|Azure|GCP|Docker|Kubernetes|Terraform|Jenkins|CircleCI|GitHub Actions)\b/i,
        # Tools & Messaging
        /\b(Git|Webpack|Babel|Jest|RSpec|Sidekiq|GraphQL|REST|Kafka|RabbitMQ)\b/i
      ]

      skills = []
      tech_patterns.each do |pattern|
        matches = text.scan(pattern).flatten.uniq
        skills.concat(matches)
      end

      skills.uniq
    end

    def empty_result
      {
        warnings: [],
        blocking: [],
        info: [],
        unverified_skills: [],
        not_claimed_skills: []
      }
    end
  end
end
