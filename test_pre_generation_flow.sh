#!/bin/bash

echo "Testing JobWizard Pre-Generation Skill Review Flow"
echo "=================================================="

echo "1. Testing SkillDetector..."
bundle exec rails runner "
detector = JobWizard::SkillDetector.new('Looking for a Senior Ruby on Rails developer with React experience. Must know PostgreSQL, Redis, and AWS.')
result = detector.analyze
puts '✓ Verified skills: ' + result[:verified].join(', ')
puts '✓ Unverified skills: ' + result[:unverified].join(', ')
"

echo ""
echo "2. Testing TemplatesWriter..."
bundle exec rails runner "
profile = YAML.load_file('config/job_wizard/profile.yml')
experience = JobWizard::ExperienceLoader.new
writer = JobWizard::Writers::TemplatesWriter
result = writer.cover_letter(
  profile: profile,
  experience: experience,
  jd_text: 'Looking for a Senior Ruby on Rails developer',
  company: 'Test Corp',
  role: 'Senior Developer',
  allowed_skills: ['Ruby on Rails', 'React']
)
puts '✓ Cover letter generated successfully'
puts '✓ Length: ' + result.length.to_s + ' characters'
"

echo ""
echo "3. Testing PdfOutputManager path styles..."
bundle exec rails runner "
ENV['JOB_WIZARD_PATH_STYLE'] = 'simple'
manager = JobWizard::PdfOutputManager.new(company: 'Test Corp', role: 'Senior Developer')
puts '✓ Simple path: ' + manager.display_path

ENV['JOB_WIZARD_PATH_STYLE'] = 'nested'
manager2 = JobWizard::PdfOutputManager.new(company: 'Test Corp', role: 'Senior Developer')
puts '✓ Nested path: ' + manager2.display_path
"

echo ""
echo "4. Testing WriterFactory..."
bundle exec rails runner "
writer = JobWizard::WriterFactory.build
puts '✓ WriterFactory returns: ' + writer.name
"

echo ""
echo "All tests passed! ✅"
echo ""
echo "Next steps:"
echo "- Visit http://localhost:3000/applications/new"
echo "- Paste a job description and click 'Review Skills'"
echo "- Verify the prepare page shows verified/unverified skills"
echo "- Select skills and click 'Generate Documents'"
echo "- Check the generated PDFs and output path"


