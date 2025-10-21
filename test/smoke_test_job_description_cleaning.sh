#!/bin/bash

echo "🧪 Smoke Test: Job Description HTML Cleaning"
echo "============================================="
echo ""

# Test 1: Verify CGI and ActionView are available
echo "1. Testing HTML entity decoding and sanitization..."
TEST_OUTPUT=$(rails runner "
require 'cgi'
require 'action_view'
test_html = '&lt;div class=&quot;test&quot;&gt;&lt;p&gt;Hello &amp; goodbye&lt;/p&gt;&lt;/div&gt;'
decoded = CGI.unescapeHTML(test_html)
clean = ActionView::Base.full_sanitizer.sanitize(decoded)
final = CGI.unescapeHTML(clean)
puts final
")

if [[ "$TEST_OUTPUT" == *"Hello & goodbye"* ]] && [[ "$TEST_OUTPUT" != *"&amp;"* ]]; then
  echo "   ✅ HTML entities decoded and tags stripped correctly"
else
  echo "   ❌ HTML cleaning failed"
  echo "   Got: $TEST_OUTPUT"
  exit 1
fi

echo ""

# Test 2: Test Greenhouse fetcher logic
echo "2. Testing Greenhouse fetcher extract_description..."
TEST_GREENHOUSE=$(rails runner "
fetcher = JobWizard::Fetchers::Greenhouse.new
job_data = { 'content' => '&lt;div&gt;&lt;p&gt;Software Engineer position&lt;/p&gt;&lt;/div&gt;' }
result = fetcher.send(:extract_description, job_data)
puts result
")

if [[ "$TEST_GREENHOUSE" == *"Software Engineer position"* ]] && [[ "$TEST_GREENHOUSE" != *"&lt;"* ]] && [[ "$TEST_GREENHOUSE" != *"<div>"* ]]; then
  echo "   ✅ Greenhouse fetcher cleans HTML correctly"
else
  echo "   ❌ Greenhouse fetcher failed"
  echo "   Got: $TEST_GREENHOUSE"
  exit 1
fi

echo ""

# Test 3: Test Lever fetcher logic
echo "3. Testing Lever fetcher extract_description..."
TEST_LEVER=$(rails runner "
fetcher = JobWizard::Fetchers::Lever.new
job_data = { 'description' => '&lt;p&gt;Backend Developer&lt;/p&gt;' }
result = fetcher.send(:extract_description, job_data)
puts result
")

if [[ "$TEST_LEVER" == *"Backend Developer"* ]] && [[ "$TEST_LEVER" != *"&lt;"* ]] && [[ "$TEST_LEVER" != *"<p>"* ]]; then
  echo "   ✅ Lever fetcher cleans HTML correctly"
else
  echo "   ❌ Lever fetcher failed"
  echo "   Got: $TEST_LEVER"
  exit 1
fi

echo ""

# Test 4: Check existing database records (optional - will fail if no jobs yet)
echo "4. Checking existing job postings in database (optional)..."
DB_CHECK=$(rails runner "
if JobPosting.any?
  job = JobPosting.last
  if job.description.include?('&lt;') || job.description.include?('&gt;') || job.description.include?('&quot;')
    puts 'CONTAMINATED'
  else
    puts 'CLEAN'
  end
else
  puts 'NO_JOBS'
end
" 2>/dev/null)

if [[ "$DB_CHECK" == "CONTAMINATED" ]]; then
  echo "   ⚠️  Existing jobs have HTML entities - re-fetch to clean them"
  echo "   Run: rake 'jobs:fetch[greenhouse,instacart]' to refresh"
elif [[ "$DB_CHECK" == "CLEAN" ]]; then
  echo "   ✅ Existing jobs have clean descriptions"
elif [[ "$DB_CHECK" == "NO_JOBS" ]]; then
  echo "   ℹ️  No jobs in database yet - fetch some to verify"
else
  echo "   ⚠️  Could not check database: $DB_CHECK"
fi

echo ""
echo "============================================="
echo "✅ All smoke tests passed!"
echo ""
echo "Next steps:"
echo "1. Re-fetch jobs from external APIs to clean existing data:"
echo "   rake 'jobs:fetch[greenhouse,instacart]'"
echo "   rake 'jobs:fetch[lever,netflix]'"
echo ""
echo "2. Verify in browser:"
echo "   Visit http://localhost:3000/jobs/[any-job-id]"
echo "   Job description should show clean text without HTML tags"
echo ""

