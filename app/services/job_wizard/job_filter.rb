# frozen_string_literal: true

module JobWizard
  # Filters job postings to keep only developer roles centered on Ruby/Rails
  #
  # Example:
  #   rules = JobWizard::Rules.current
  #   filter = JobWizard::JobFilter.new(rules.job_filters)
  #   filter.keep?(title: "Rails Engineer", description: "Build with Rails") # => true
  #   filter.keep?(title: "Tax Analyst", description: "Process returns") # => false
  class JobFilter
    attr_reader :include_keywords, :exclude_keywords, :require_include_match

    def initialize(rules_hash)
      @include_keywords = normalize_keywords(rules_hash['include_keywords'] || rules_hash[:include_keywords] || [])
      @exclude_keywords = normalize_keywords(rules_hash['exclude_keywords'] || rules_hash[:exclude_keywords] || [])

      # Check ranking rules for require_include_match (may be passed in rules_hash or need to get from Rules.current.ranking)
      @require_include_match = if rules_hash.key?('require_include_match') || rules_hash.key?(:require_include_match)
                                 rules_hash['require_include_match'] || rules_hash[:require_include_match]
                               else
                                 Rules.current.ranking['require_include_match'] || true
                               end
    end

    # Determines if a job posting should be kept based on title, description, and optionally location
    # Returns true if the job passes all filters, false otherwise
    def keep?(title:, description:, location: nil)
      # Rule 1: Check location restrictions FIRST - reject country-specific jobs (unless US)
      return false if location_restricted?(location)

      # Combine title, description, and location for matching
      text = normalize_text("#{title} #{description} #{location}")

      # Rule 2: Reject if ANY exclude keyword is present
      return false if matches_any_exclude?(text)

      # Rule 3: If require_include_match is true, must have at least one include keyword
      return false if @require_include_match && !matches_any_include?(text)

      # Passed all filters
      true
    end

    private

    def location_restricted?(location)
      return false if location.blank?

      loc = normalize_text(location)

      # Allow if explicitly US-related
      return false if loc.match?(/\b(usa|us|united states|america)\b/)

      # Allow if explicitly open/remote without country restriction
      return false if loc.match?(/\b(remote|anywhere|worldwide|global|flexible|world wide)\b/i) && !loc.match?(/\b(country|countries)\b/)

      # List of common countries (non-US) - if location contains ONLY these, reject
      non_us_countries = %w[
        afghanistan albania algeria argentina australia austria bangladesh belgium
        brazil bulgaria cambodia canada chile china colombia croatia cuba denmark
        egypt estonia finland france germany ghana greece hungary iceland india
        indonesia iran iraq ireland israel italy japan jordan kenya korea kuwait
        latvia lebanon lithuania luxembourg malaysia mexico morocco myanmar
        netherlands new zealand nigeria norway pakistan philippines poland portugal
        qatar romania russia saudi arabia singapore slovakia south africa spain
        sri lanka sweden switzerland taiwan thailand turkey ukraine united kingdom
        uk venezuela vietnam yemen zimbabwe
      ]

      # Check if location contains ONLY non-US countries
      non_us_countries.each do |country|
        # If location is just the country name or country + remote, reject it
        if loc == country || loc == "#{country} remote" || loc == "remote #{country}"
          return true
        end
      end

      false
    end

    def normalize_keywords(keywords)
      Array(keywords).map { |k| normalize_text(k) }
    end

    def normalize_text(text)
      return '' if text.nil?

      # Convert to lowercase, normalize punctuation/hyphens, and whitespace
      text.to_s
          .downcase
          .gsub(/[-_]/, ' ')        # Convert hyphens/underscores to spaces
          .gsub(/[[:punct:]]/, ' ') # Remove other punctuation
          .gsub(/\s+/, ' ')         # Normalize whitespace
          .strip
    end

    def matches_any_exclude?(text)
      @exclude_keywords.any? do |keyword|
        # Word-aware matching: ensure keyword is surrounded by word boundaries
        text.match?(/\b#{Regexp.escape(keyword)}\b/)
      end
    end

    def matches_any_include?(text)
      @include_keywords.any? do |keyword|
        # Word-aware matching: ensure keyword is surrounded by word boundaries
        text.match?(/\b#{Regexp.escape(keyword)}\b/)
      end
    end
  end
end
