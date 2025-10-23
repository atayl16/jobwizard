# frozen_string_literal: true

module JobWizard
  # Service to safely update rules.yml file
  # Only updates specific allowed fields to prevent accidental corruption
  class SafeRulesWriter
    attr_reader :rules_path, :errors

    def initialize(path = nil)
      @rules_path = path || Rails.root.join('config/job_wizard/rules.yml')
      @errors = []
    end

    # Update blocklist/allowlist entries
    # @param updates [Hash] with keys like :company_blocklist, :exclude_keywords, etc.
    def update_blocklist_updates!(updates)
      unless File.exist?(@rules_path)
        @errors << "Rules file not found: #{@rules_path}"
        return false
      end

      # Load existing rules
      existing_rules = YAML.load_file(@rules_path) || {}

      # Apply updates (only to allowed fields)
      if updates[:exclude_keywords]
        existing_rules['job_filters_ruby'] ||= {}
        existing_rules['job_filters_ruby']['exclude_keywords'] = updates[:exclude_keywords]
      end

      # Write back atomically
      write_rules(existing_rules)
    rescue StandardError => e
      @errors << "Failed to update rules: #{e.message}"
      Rails.logger.error "SafeRulesWriter error: #{e.message}"
      false
    end

    # Add a keyword to exclude list
    def add_exclude_keyword!(keyword)
      return false if keyword.blank?

      rules = load_rules
      filters = rules['job_filters_ruby'] || {}
      exclude_keywords = Array(filters['exclude_keywords'])

      unless exclude_keywords.include?(keyword)
        exclude_keywords << keyword
        filters['exclude_keywords'] = exclude_keywords
        rules['job_filters_ruby'] = filters
        write_rules(rules)
      end

      true
    rescue StandardError => e
      @errors << "Failed to add keyword: #{e.message}"
      false
    end

    # Remove a keyword from exclude list
    def remove_exclude_keyword!(keyword)
      rules = load_rules
      filters = rules['job_filters_ruby'] || {}
      exclude_keywords = Array(filters['exclude_keywords'])

      exclude_keywords.delete(keyword)
      filters['exclude_keywords'] = exclude_keywords
      rules['job_filters_ruby'] = filters
      write_rules(rules)

      true
    rescue StandardError => e
      @errors << "Failed to remove keyword: #{e.message}"
      false
    end

    private

    def load_rules
      return {} unless File.exist?(@rules_path)
      YAML.load_file(@rules_path) || {}
    end

    def write_rules(rules)
      # Create backup
      backup_path = "#{@rules_path}.backup.#{Time.current.to_i}"
      FileUtils.cp(@rules_path, backup_path) if File.exist?(@rules_path)

      # Write new rules
      File.write(@rules_path, YAML.dump(rules))

      # Clean up old backups (keep last 5)
      cleanup_old_backups

      true
    rescue StandardError => e
      # Restore from backup on error
      if File.exist?(backup_path)
        FileUtils.cp(backup_path, @rules_path)
      end
      raise e
    end

    def cleanup_old_backups
      backups = Dir.glob("#{@rules_path}.backup.*").sort.reverse
      backups.drop(5).each { |backup| File.delete(backup) }
    end
  end
end

