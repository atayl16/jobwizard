# frozen_string_literal: true

module JobWizard
  # Validates YAML configuration files for proper structure
  # Ensures profile.yml and experience.yml have required fields
  class YamlValidator
    REQUIRED_PROFILE_KEYS = %w[name email summary].freeze
    REQUIRED_EXPERIENCE_KEYS = %w[skills positions].freeze
    REQUIRED_SKILL_KEYS = %w[name].freeze

    def initialize
      @errors = []
    end

    def validate_all!
      validate_profile!
      validate_experience!
      validate_rules!

      raise ValidationError, "YAML validation failed:\n#{@errors.join("\n")}" if @errors.any?

      true
    end

    def validate_profile!
      data = load_yaml('profile.yml')

      REQUIRED_PROFILE_KEYS.each do |key|
        @errors << "profile.yml: Missing required key '#{key}'" if data[key].blank?
      end

      # Validate email format
      if data['email'].present? && !data['email'].match?(URI::MailTo::EMAIL_REGEXP)
        @errors << 'profile.yml: Invalid email format'
      end

      true
    rescue StandardError => e
      @errors << "profile.yml: #{e.message}"
      false
    end

    def validate_experience!
      data = load_yaml('experience.yml')

      REQUIRED_EXPERIENCE_KEYS.each do |key|
        @errors << "experience.yml: Missing required key '#{key}'" unless data.key?(key)
      end

      # Validate skills structure
      validate_skills(data['skills']) if data['skills'].present?

      true
    rescue StandardError => e
      @errors << "experience.yml: #{e.message}"
      false
    end

    def validate_rules!
      data = load_yaml('rules.yml')

      # Just check that it's parseable YAML
      @errors << 'rules.yml: Must be a valid YAML hash' unless data.is_a?(Hash)

      true
    rescue StandardError => e
      @errors << "rules.yml: #{e.message}"
      false
    end

    attr_reader :errors

    private

    def validate_skills(skills)
      case skills
      when Array
        skills.each_with_index do |skill, index|
          case skill
          when Hash
            # New format: { name: "Ruby", level: "expert", context: "..." }
            REQUIRED_SKILL_KEYS.each do |key|
              unless skill[key].present? || skill[key.to_sym].present?
                @errors << "experience.yml: Skill at index #{index} missing '#{key}'"
              end
            end
          when String
            # Old format: simple string array (valid)
            next
          else
            @errors << "experience.yml: Invalid skill format at index #{index}"
          end
        end
      when Hash
        # Tiered format: { proficient: [...], working_knowledge: [...] }
        skills.each do |level, skill_list|
          @errors << "experience.yml: Skills under '#{level}' must be an array" unless skill_list.is_a?(Array)
        end
      else
        @errors << 'experience.yml: Skills must be an array or hash'
      end
    end

    def load_yaml(filename)
      path = JobWizard::CONFIG_PATH.join(filename)

      raise "File not found: #{path}" unless File.exist?(path)

      YAML.safe_load_file(path) || {}
    end

    class ValidationError < StandardError; end
  end
end
