# frozen_string_literal: true

class DashboardController < ApplicationController
  def show
    @job_matcher = JobWizard::JobMatcher.new
    @job_postings = @job_matcher.matching_jobs(limit: 25)
    @recent_apps = Application.order(created_at: :desc).limit(10)
    @output_root = JobWizard::OUTPUT_ROOT
    @matching_stats = @job_matcher.matching_stats

    # AI cost tracking
    @ai_stats = AiCost::Stats.month_to_date
    @ai_enabled = Rails.application.config.job_wizard.ai_enabled
  end
end
