# Justfile - Task runner for Rails projects
# Install: brew install just
# Usage: just <command>

default: test

# Setup project dependencies and database
setup:
  bin/setup

# Run RuboCop linter
lint:
  bundle exec rubocop

# Fix auto-correctable RuboCop issues
lint-fix:
  bundle exec rubocop -a

# Run security scans
sec:
  bundle exec bundler-audit update && bundle exec bundler-audit check
  bundle exec brakeman -q -o reports/brakeman.txt

# Run RSpec test suite
test:
  bundle exec rspec

# Run tests with coverage
test-cov:
  COVERAGE=true bundle exec rspec

# Run Rails server
run:
  bin/rails s

# Open Rails console
console:
  bin/rails c

# Generate ERD diagram
erd:
  bundle exec erd --filename docs/erd --filetype png

# Run database migrations
migrate:
  bin/rails db:migrate

# Rollback last migration
rollback:
  bin/rails db:rollback

# Reset database (drop, create, migrate, seed)
db-reset:
  bin/rails db:reset

# Run full CI checks (lint + security + tests)
ci: lint sec test

