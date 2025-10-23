# frozen_string_literal: true

module JobWizard
  # Loads job sources from config/job_wizard/sources.yml
  class SourceLoader
    Source = Struct.new(:provider, :slug, :name, :active, keyword_init: true) do
      def active?
        active == true
      end
    end

    def self.load_sources
      new.load_sources
    end

    def self.active_sources
      new.active_sources
    end

    def load_sources
      sources_data = YAML.load_file(sources_path)
      (sources_data['sources'] || []).map do |source_hash|
        Source.new(
          provider: source_hash['provider'],
          slug: source_hash['slug'],
          name: source_hash['name'] || source_hash['slug'].titleize,
          active: source_hash['active'] != false # Default to true
        )
      end
    rescue Errno::ENOENT
      Rails.logger.warn 'sources.yml not found, returning empty array'
      []
    end

    def active_sources
      load_sources.select(&:active?)
    end

    private

    def sources_path
      Rails.root.join('config/job_wizard/sources.yml')
    end
  end
end
