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
      @require_include_match = rules_hash['require_include_match'] || 
                               rules_hash[:require_include_match] ||
                               Rules.current.ranking['require_include_match'] ||
                               true
    end

    # Determines if a job posting should be kept based on title and description
    # Returns true if the job passes all filters, false otherwise
    def keep?(title:, description:)
      # Combine title and description for matching
      text = normalize_text("#{title} #{description}")

      # Rule 1: Reject if ANY exclude keyword is present
      return false if matches_any_exclude?(text)

      # Rule 2: If require_include_match is true, must have at least one include keyword
      return false if @require_include_match && !matches_any_include?(text)

      # Passed all filters
      true
    end

    private

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

