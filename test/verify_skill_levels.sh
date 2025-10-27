#!/bin/bash
# Verification script for Skill Levels & Context feature

set -e

echo "🧪 JobWizard Skill Levels Verification"
echo "========================================"
echo ""

echo "1️⃣  Running RuboCop..."
bundle exec rubocop -A app/services/job_wizard/experience_loader.rb \
                        app/services/job_wizard/rules_scanner.rb \
                        app/services/job_wizard/resume_builder.rb \
                        app/controllers/applications_controller.rb \
                        app/views/applications/show.html.erb
echo "✅ RuboCop passed"
echo ""

echo "2️⃣  Running ExperienceLoader specs..."
bundle exec rspec spec/services/job_wizard/experience_loader_spec.rb --format documentation
echo "✅ ExperienceLoader specs passed"
echo ""

echo "3️⃣  Running RulesScanner specs..."
bundle exec rspec spec/services/job_wizard/rules_scanner_spec.rb --format documentation
echo "✅ RulesScanner specs passed"
echo ""

echo "4️⃣  Checking experience.yml format..."
if grep -q "skills:" config/job_wizard/experience.yml; then
  echo "✅ New skills format detected"
else
  echo "⚠️  Warning: skills section not found in experience.yml"
fi
echo ""

echo "📋 Next Steps for Manual Testing:"
echo "=================================="
echo ""
echo "1. Start the server:"
echo "   bin/dev"
echo ""
echo "2. Visit http://localhost:3000"
echo ""
echo "3. Paste this test job description:"
echo ""
cat <<'JD'
Senior Full-Stack Engineer at Zipline

Requirements:
- Expert in Ruby on Rails and React
- PostgreSQL and Elasticsearch experience
- Working knowledge of Docker and Kubernetes
- Familiar with GCP and Azure
- CircleCI or Jenkins for CI/CD

Nice to have:
- Terraform for infrastructure
- Webpack knowledge
JD
echo ""
echo "4. Click 'Generate Documents'"
echo ""
echo "5. On the results page, verify:"
echo "   ✓ Expert skills are phrased as 'Deep experience with...'"
echo "   ✓ Intermediate skills grouped under 'Working proficiency:'"
echo "   ✓ Basic skills under 'Also familiar with:'"
echo "   ✓ PostgreSQL, Elasticsearch, GCP, Azure appear in purple 'Not Claimed' box"
echo "   ✓ Download resume.pdf and check skill phrasing"
echo ""
echo "6. Open ~/Documents/JobWizard/Applications/Zipline/... in Finder"
echo "   ✓ Verify resume.pdf and cover_letter.pdf exist"
echo ""
echo "✨ All automated tests passed! Ready for manual testing."





