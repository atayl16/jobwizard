# frozen_string_literal: true

module Ai
  class JobsController < ApplicationController
    before_action :set_job

    def summarize
      return head :forbidden unless feature_enabled?

      result = Jd::Summarizer.summarize(text: @job.description, job_posting_id: @job.id)

      render json: result
    rescue StandardError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def skills
      return head :forbidden unless feature_enabled?

      result = Jd::SkillExtractor.extract(text: @job.description, job_posting_id: @job.id)

      render json: result
    rescue StandardError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    private

    def feature_enabled?
      ENV['ENABLE_AI_ENHANCERS'] == 'true'
    end

    def set_job
      @job = JobPosting.find(params[:id])
    end
  end
end
