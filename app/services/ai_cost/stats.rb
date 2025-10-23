# frozen_string_literal: true

module AiCost
  # Provides statistics and queries for AI usage
  class Stats
    def self.month_to_date(range = Time.current.beginning_of_month..Time.current)
      usages = AiUsage.where(created_at: range)

      total_cents = usages.sum(:cost_cents)

      # Group by feature
      by_feature = usages.group(:feature).sum(:cost_cents)

      # Get recent records
      recent = usages.recent.limit(10)

      {
        total_cents: total_cents,
        total_dollars: (total_cents / 100.0),
        by_feature: by_feature,
        count: usages.count,
        recent: recent
      }
    end
  end
end
