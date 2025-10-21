# frozen_string_literal: true

module JobWizard
  # Loads and provides access to rules from config/job_wizard/rules.yml
  # Prefers primary keys (job_filters, scoring, ranking, ui) but falls back
  # to *_ruby equivalents when primary keys are missing.
  #
  # Example:
  #   rules = JobWizard::Rules.current
  #   filters = rules.job_filters
  #   scoring = rules.scoring
  class Rules
    attr_reader :data

    # Singleton accessor for current rules
    def self.current
      @current ||= new
    end

    # Reset singleton (useful for testing)
    def self.reset!
      @current = nil
    end

    def initialize(path = nil)
      @path = path || Rails.root.join('config/job_wizard/rules.yml')
      @data = load_data
    end

    # Returns job filters configuration
    # Prefers 'job_filters' key, falls back to 'job_filters_ruby'
    def job_filters
      @data['job_filters'] || @data['job_filters_ruby'] || {}
    end

    # Returns scoring configuration
    # Prefers 'scoring' key, falls back to 'scoring_ruby'
    def scoring
      @data['scoring'] || @data['scoring_ruby'] || {}
    end

    # Returns ranking configuration
    # Prefers 'ranking' key, falls back to 'ranking_ruby'
    def ranking
      @data['ranking'] || @data['ranking_ruby'] || {}
    end

    # Returns UI configuration
    # Prefers 'ui' key, falls back to 'ui_ruby'
    def ui
      @data['ui'] || @data['ui_ruby'] || {}
    end

    # Access warnings rules (from existing rules.yml structure)
    def warnings
      @data['warnings'] || {}
    end

    # Access blocking rules (from existing rules.yml structure)
    def blocking
      @data['blocking'] || {}
    end

    # Access info rules (from existing rules.yml structure)
    def info
      @data['info'] || {}
    end

    private

    def load_data
      return {} unless File.exist?(@path)

      YAML.safe_load_file(@path, permitted_classes: [], aliases: true) || {}
    rescue StandardError => e
      Rails.logger.error("Failed to load rules from #{@path}: #{e.message}")
      {}
    end
  end
end
