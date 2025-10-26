# frozen_string_literal: true

module Ai
  class UsagesController < ApplicationController
    def index
      @month = params[:month] || Time.current.strftime('%Y-%m')
      month_start = Date.parse("#{@month}-01").beginning_of_month
      month_end = month_start.end_of_month

      @stats = AiCost::Stats.month_to_date(month_start..month_end)
      @usages = AiUsage.where(created_at: month_start..month_end).recent
    end
  end
end
