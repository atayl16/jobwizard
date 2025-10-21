# frozen_string_literal: true

require 'active_support/core_ext/string/inflections'

module JobWizard
  # Matches job postings to user's skills and preferences
  class JobMatcher
    attr_reader :experience_loader

    def initialize
      @experience_loader = ExperienceLoader.new
    end

    # Returns jobs that match user's skills and preferences
    def matching_jobs(limit: 25)
      all_jobs = JobPosting.order(created_at: :desc).limit(limit * 3) # Get more to filter from
      
      scored_jobs = all_jobs.map do |job|
        score = calculate_match_score(job)
        { job: job, score: score }
      end

      # Filter out jobs with score 0 and sort by score (highest first)
      scored_jobs
        .select { |item| item[:score] > 0 }
        .sort_by { |item| -item[:score] }
        .first(limit)
        .map { |item| item[:job] }
    end

    # Calculate how well a job matches user's profile
    def calculate_match_score(job)
      score = 0

      # Must be remote-only (no hybrid/onsite)
      return 0 unless job.remote?

      job_text = "#{job.title} #{job.description}".downcase
      
      # REQUIRED: Must mention Ruby on Rails or Rails
      unless job_text.include?('ruby on rails') || job_text.include?('rails')
        return 0
      end
      
      # Primary skills (Ruby on Rails, React, JavaScript) - high weight
      primary_skills = ['ruby on rails', 'rails', 'react', 'javascript', 'js']
      primary_matches = primary_skills.count { |skill| job_text.include?(skill) }
      score += primary_matches * 15

      # Secondary skills (MySQL, Redis, AWS, etc.) - medium weight  
      secondary_skills = ['mysql', 'redis', 'aws', 'kubernetes', 'sidekiq', 'html', 'css']
      secondary_matches = secondary_skills.count { |skill| job_text.include?(skill) }
      score += secondary_matches * 8

      # Bonus for Rails-specific terms
      rails_terms = ['activerecord', 'action controller', 'erb', 'haml', 'rspec', 'capybara', 'ruby']
      rails_matches = rails_terms.count { |term| job_text.include?(term) }
      score += rails_matches * 5

      # Bonus for full-stack terms
      fullstack_terms = ['full-stack', 'fullstack', 'frontend', 'backend', 'api']
      fullstack_matches = fullstack_terms.count { |term| job_text.include?(term) }
      score += fullstack_matches * 3

      # Penalty for technologies you don't have
      unfamiliar_tech = ['python', 'java', 'c#', '.net', 'php', 'go', 'rust', 'angular', 'vue']
      unfamiliar_matches = unfamiliar_tech.count { |tech| job_text.include?(tech) }
      score -= unfamiliar_matches * 3

      # Bonus for senior/lead positions (matches your experience level)
      senior_terms = ['senior', 'lead', 'principal', 'staff', 'architect']
      senior_matches = senior_terms.count { |term| job_text.include?(term) }
      score += senior_matches * 5

      # Bonus for remote-first companies
      remote_terms = ['remote-first', 'distributed', 'async', 'timezone']
      remote_matches = remote_terms.count { |term| job_text.include?(term) }
      score += remote_matches * 3

      # Extra penalty for non-Rails backend technologies
      non_rails_backend = ['django', 'spring', 'express', 'node.js', 'laravel', 'symfony']
      non_rails_matches = non_rails_backend.count { |tech| job_text.include?(tech) }
      score -= non_rails_matches * 5

      score
    end

    # Get a summary of why a job matched
    def match_reasons(job)
      reasons = []
      job_text = "#{job.title} #{job.description}".downcase

      # Check for Rails
      if job_text.include?('ruby on rails') || job_text.include?('rails')
        reasons << "Ruby on Rails position"
      end

      # Check primary skills
      primary_skills = ['react', 'javascript', 'js']
      matched_primary = primary_skills.select { |skill| job_text.include?(skill) }
      if matched_primary.any?
        reasons << "Uses your skills: #{matched_primary.join(', ')}"
      end

      # Check secondary skills
      secondary_skills = ['mysql', 'redis', 'aws', 'kubernetes', 'sidekiq']
      matched_secondary = secondary_skills.select { |skill| job_text.include?(skill) }
      if matched_secondary.any?
        reasons << "Familiar tech: #{matched_secondary.join(', ')}"
      end

      # Check if it's remote
      reasons << "100% remote position" if job.remote?

      # Check for seniority level
      senior_terms = ['senior', 'lead', 'principal', 'staff']
      if senior_terms.any? { |term| job_text.include?(term) }
        reasons << "Matches your experience level"
      end

      reasons
    end

    # Get stats about the job matching
    def matching_stats
      total_jobs = JobPosting.count
      remote_jobs = JobPosting.where(remote: true).count
      matching_jobs_count = matching_jobs(limit: 1000).count

      {
        total_jobs: total_jobs,
        remote_jobs: remote_jobs,
        matching_jobs: matching_jobs_count,
        match_percentage: total_jobs > 0 ? (matching_jobs_count.to_f / total_jobs * 100).round(1) : 0
      }
    end
  end
end
