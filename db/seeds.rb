# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# JobWizard Seeds
# Run with: rails db:seed

# Example blocked companies (commented out)
# Uncomment and modify as needed

# BlockedCompany.create!(
#   name: 'CyberCoders',
#   pattern: false,
#   reason: 'Spam recruiter'
# )

# BlockedCompany.create!(
#   name: '/.*recruiter.*/i',
#   pattern: true,
#   reason: 'Generic recruiter pattern'
# )

# BlockedCompany.create!(
#   name: 'Robert Half',
#   pattern: false,
#   reason: 'Low quality placements'
# )

Rails.logger.debug 'JobWizard seeds loaded. Uncomment examples in db/seeds.rb to add blocked companies.'
