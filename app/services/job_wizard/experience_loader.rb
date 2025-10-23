# frozen_string_literal: true

module JobWizard
  # Loads and normalizes experience.yml to support multiple skill schema formats
  # Provides backward compatibility for old flat/tiered structures
  #
  # Supported formats:
  # 1. New: skills: [{ name: "Rails", level: "expert", context: "..." }]
  # 2. Old tiered: skills: { proficient: [...], working_knowledge: [...], familiar: [...] }
  # 3. Old flat: skills: ["Rails", "PostgreSQL", ...]
  class ExperienceLoader
    VALID_LEVELS = %i[expert intermediate basic].freeze

    # Skill aliases for normalization (common variations → canonical names)
    SKILL_ALIASES = {
      'rails' => 'Ruby on Rails',
      'rspec' => 'RSpec',
      'jest' => 'Jest',
      'aws' => 'AWS',
      'gcp' => 'GCP',
      'k8s' => 'Kubernetes',
      'postgres' => 'PostgreSQL',
      'postgresql' => 'PostgreSQL',
      'mysql' => 'MySQL',
      'redis' => 'Redis',
      'js' => 'JavaScript',
      'javascript' => 'JavaScript',
      'ts' => 'TypeScript',
      'typescript' => 'TypeScript',
      'html' => 'HTML/CSS',
      'css' => 'HTML/CSS',
      'html/css' => 'HTML/CSS'
    }.freeze

    attr_reader :normalized_skills, :positions, :projects, :not_claimed_skills

    def initialize(experience_path = nil)
      @experience_path = experience_path || JobWizard::CONFIG_PATH.join('experience.yml')
      @raw_data = load_yaml
      @normalized_skills = normalize_skills
      @positions = @raw_data['positions'] || []
      @projects = @raw_data['projects'] || []
      @not_claimed_skills = @raw_data['not_claimed_skills'] || []
    end

    # Returns set of all skill names (downcased for matching)
    def all_skill_names
      @all_skill_names ||= Set.new(normalized_skills.map { |s| s[:name].downcase })
    end

    # Get level for a specific skill (case-insensitive)
    def level_for(skill_name)
      skill = normalized_skills.find { |s| s[:name].downcase == skill_name.downcase }
      skill&.dig(:level)
    end

    # Get context for a specific skill (case-insensitive)
    def context_for(skill_name)
      skill = normalized_skills.find { |s| s[:name].downcase == skill_name.downcase }
      skill&.dig(:context)
    end

    # Check if skill exists (case-insensitive)
    def skill?(skill_name)
      all_skill_names.include?(skill_name.downcase)
    end

    # Alias for backward compatibility
    alias has_skill? skill?

    # Get skills grouped by level
    def skills_by_level
      {
        expert: normalized_skills.select { |s| s[:level] == :expert },
        intermediate: normalized_skills.select { |s| s[:level] == :intermediate },
        basic: normalized_skills.select { |s| s[:level] == :basic }
      }
    end

    # Normalize a skill name using aliases (e.g., "Rails" → "Ruby on Rails")
    # Returns the canonical name if alias exists, otherwise returns original name
    def normalize_skill_name(skill_name)
      return skill_name if skill_name.blank?

      normalized = skill_name.to_s.strip
      SKILL_ALIASES[normalized.downcase] || normalized
    end

    # Check if a skill is in the not_claimed_skills list (case-insensitive)
    def not_claimed_skill?(skill_name)
      normalized = normalize_skill_name(skill_name)
      not_claimed_skills.any? { |nc| nc.downcase.include?(normalized.downcase) }
    end

    # Enhanced skill check that uses aliases
    def has_skill_with_alias?(skill_name)
      normalized = normalize_skill_name(skill_name)
      skill?(normalized)
    end

    private

    def load_yaml
      return {} unless File.exist?(@experience_path)

      YAML.load_file(@experience_path) || {}
    end

    def normalize_skills
      raw_skills = @raw_data['skills']
      return [] unless raw_skills

      case raw_skills
      when Array
        # Format 1 (new) or Format 3 (old flat)
        normalize_array_format(raw_skills)
      when Hash
        # Format 2 (old tiered)
        normalize_tiered_format(raw_skills)
      else
        []
      end
    end

    def normalize_array_format(skills_array)
      skills_array.map do |skill|
        if skill.is_a?(Hash)
          # New format: { name: "Rails", level: "expert", context: "..." }
          normalize_skill_hash(skill)
        else
          # Old flat format: just a string
          {
            name: skill.to_s,
            level: :intermediate, # Default for old flat format
            context: nil
          }
        end
      end.compact
    end

    def normalize_tiered_format(skills_hash)
      # proficient → expert
      result = (skills_hash['proficient'] || []).map do |skill|
        { name: skill, level: :expert, context: nil }
      end

      # working_knowledge → intermediate
      (skills_hash['working_knowledge'] || []).each do |skill|
        result << { name: skill, level: :intermediate, context: nil }
      end

      # familiar → basic
      (skills_hash['familiar'] || []).each do |skill|
        result << { name: skill, level: :basic, context: nil }
      end

      result
    end

    def normalize_skill_hash(skill_hash)
      # Handle both string and symbol keys
      name = skill_hash['name'] || skill_hash[:name]
      level = skill_hash['level'] || skill_hash[:level]
      context = skill_hash['context'] || skill_hash[:context]

      return nil unless name

      # Normalize level to symbol
      level_sym = case level.to_s.downcase
                  when 'expert', 'proficient', 'advanced'
                    :expert
                  when 'intermediate', 'working_knowledge', 'working'
                    :intermediate
                  when 'basic', 'familiar', 'beginner'
                    :basic
                  else
                    :intermediate # Default
                  end

      {
        name: name.to_s,
        level: level_sym,
        context: context&.to_s
      }
    end
  end
end
