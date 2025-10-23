#!/usr/bin/env ruby
# frozen_string_literal: true

# Sanity check script to test Ruby/Rails job filtering
# Run with: rails runner test_ruby_rails_filter.rb

require_relative 'config/environment'

puts "\n#{'=' * 80}"
puts 'Ruby/Rails Job Board Filter Sanity Check'
puts "#{'=' * 80}\n"

# Initialize services
rules = JobWizard::Rules.current
filter = JobWizard::JobFilter.new(rules.job_filters)
ranker = JobWizard::JobRanker.new(rules.scoring, rules.ranking)

# Test samples
samples = [
  ['Software Engineer (Ruby on Rails)', 'ActiveRecord RSpec Sidekiq'],
  ['Senior Tax Technology Analyst', 'tax, accounting, compliance'],
  ['React Frontend Developer', 'React JS Typescript'],
  ['Backend Ruby Engineer', 'Ruby APIs Postgres Sidekiq'],
  ['Full Stack Rails Developer', 'Rails React Hotwire Turbo RSpec'],
  ['Project Manager', 'Coordinate agile teams PMO'],
  ['Ruby on Rails Staff Engineer', 'Lead Rails team, mentor, RSpec, Sidekiq, Redis'],
  ['Financial Analyst', 'Excel, financial modeling, reports']
]

puts 'Job Title                                          |  KEEP? |    Score | Decision'
puts '-' * 80

samples.each do |title, description|
  keep = filter.keep?(title: title, description: description)
  score = ranker.score(title: title, description: description)
  decision = keep && score.positive? ? 'KEEP' : 'DROP'

  keep_str = keep ? 'YES' : 'NO'

  # Truncate title if too long
  display_title = title.length > 45 ? "#{title[0..42]}..." : title

  puts format('%-50s | %6s | %8.2f | %s', display_title, keep_str, score, decision)
end

puts "\n#{'=' * 80}"
puts 'Configuration Summary:'
puts '=' * 80
puts "Include keywords: #{rules.job_filters['include_keywords']&.join(', ')}"
puts "Exclude keywords: #{rules.job_filters['exclude_keywords']&.first(5)&.join(', ')}..."
puts "Require include match: #{rules.ranking['require_include_match']}"
puts "Min keep score: #{rules.ranking['min_keep_score']}"
puts "UI label: #{rules.ui['active_filter_label']}"
puts "\n"
