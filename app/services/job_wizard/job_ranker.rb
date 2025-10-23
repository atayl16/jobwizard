# frozen_string_literal: true

module JobWizard
  # Scores job postings based on keyword boosts and penalties
  # Returns 0.0 for jobs that would be filtered out
  #
  # Example:
  #   rules = JobWizard::Rules.current
  #   ranker = JobWizard::JobRanker.new(rules.scoring, rules.ranking)
  #   score = ranker.score(title: "Rails Engineer", description: "Ruby, RSpec, Sidekiq")
  #   # => 15.0 (ruby: 5.0 + rails: 5.0 + rspec: 2.5 + sidekiq: 2.0)
  class JobRanker
    attr_reader :boosts, :penalties, :min_keep_score, :filter

    def initialize(scoring_hash, ranking_hash)
      @boosts = normalize_keywords_hash(scoring_hash['boosts'] || scoring_hash[:boosts] || {})
      @penalties = normalize_keywords_hash(scoring_hash['penalties'] || scoring_hash[:penalties] || {})
      @neutral_or_low = normalize_keywords_hash(scoring_hash['neutral_or_low'] || scoring_hash[:neutral_or_low] || {})

      @min_keep_score = (ranking_hash['min_keep_score'] || ranking_hash[:min_keep_score] || 1.0).to_f

      # Create a filter instance to check if job would be filtered out
      @filter = JobFilter.new(Rules.current.job_filters.merge(ranking_hash))
    end

    # Calculates score for a job posting based on title, description, and optionally location
    # Returns 0.0 if the job would be filtered out
    def score(title:, description:, location: nil)
      # If filter would drop this job, return 0.0
      return 0.0 unless @filter.keep?(title: title, description: description, location: location)

      # Combine title and description for scoring
      text = normalize_text("#{title} #{description}")

      # Calculate base score from boosts
      calculated_score = calculate_boosts(text)

      # Add neutral/low value keywords
      calculated_score += calculate_neutral(text)

      # Subtract penalties
      calculated_score -= calculate_penalties(text)

      # Return 0.0 if below minimum threshold, otherwise return calculated score
      calculated_score >= @min_keep_score ? calculated_score : 0.0
    end

    private

    def normalize_keywords_hash(hash)
      hash.to_h { |k, v| [normalize_text(k), v.to_f] }
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

    def calculate_boosts(text)
      @boosts.sum do |keyword, points|
        # Count occurrences of this keyword (word-aware matching)
        count = text.scan(/\b#{Regexp.escape(keyword)}\b/).count
        count * points
      end
    end

    def calculate_neutral(text)
      @neutral_or_low.sum do |keyword, points|
        # Count occurrences of this keyword (word-aware matching)
        count = text.scan(/\b#{Regexp.escape(keyword)}\b/).count
        count * points
      end
    end

    def calculate_penalties(text)
      @penalties.sum do |keyword, points|
        # Count occurrences of this keyword (word-aware matching)
        # Note: points are already negative in config, but we're using abs here for clarity
        count = text.scan(/\b#{Regexp.escape(keyword)}\b/).count
        count * points.abs
      end
    end
  end
end
