# PDF Generation Status Indicator - Implementation Summary

## Problem
There was no on-screen indication when PDFs were generated for a job, leading to potential duplicate generations and confusion.

## Solution
Added visual feedback and conditional button disabling based on whether PDFs were generated today.

## Changes Made

### 1. Model Updates (`app/models/job_posting.rb`)

**Added Associations:**
```ruby
has_many :applications, dependent: :nullify
```

**Added Helper Methods:**
```ruby
# Check if PDFs were generated today
def generated_today?
  exported_at&.today? || false
end

# Get the most recent application for this job
def latest_application
  applications.recent.first
end

# Check if any PDFs exist for this job
def has_pdfs?
  applications.exists?(status: :generated)
end
```

### 2. UI Updates (`app/views/jobs/index.html.erb`)

**Before:**
- Always showed "Tailor & Export" button
- No indication if PDFs already existed

**After:**
- **If generated today:**
  - Shows green badge: "✓ Generated X ago"
  - Shows "View PDFs" button (links to application page)
  - Shows "Generate Again" button (gray, secondary action)
- **If not generated yet:**
  - Shows "Tailor & Export" button (blue, primary action)

### 3. Tests (`spec/models/job_posting_status_spec.rb`)

Added comprehensive tests for:
- `#generated_today?` - Returns true/false based on exported_at date
- `#latest_application` - Returns most recent application
- `#has_pdfs?` - Returns true when generated applications exist

**All 8 tests passing ✅**

## User Experience Flow

### Scenario 1: New Job (Not Generated)
```
[Apply →]  [Tailor & Export]
```
- Blue "Tailor & Export" button prominently displayed
- User clicks to generate PDFs

### Scenario 2: Generated Today
```
[Apply →]  [✓ Generated 2 hours ago]
           [View PDFs]
```
- Green badge shows when PDFs were generated
- "View PDFs" button links to application page with download links
- Secondary "Generate Again" option available if needed

### Scenario 3: Generated Yesterday
```
[Apply →]  [Tailor & Export]
```
- Reset to "Tailor & Export" since it's a new day
- Allows re-generation with updated content

## Benefits

1. **Clear Visual Feedback** - Users immediately see if PDFs were generated
2. **Prevents Duplicate Work** - Primary action disabled when already generated
3. **Easy Access** - "View PDFs" button provides quick access to downloads
4. **Flexible** - "Generate Again" option available if needed
5. **Time-Aware** - Resets daily, allowing fresh generations

## Technical Details

- Uses existing `exported_at` timestamp from `mark_exported!` method
- Leverages `Application` association to find related PDFs
- No database migrations required
- No breaking changes to existing functionality

## Files Changed

1. `app/models/job_posting.rb` - Added associations and helper methods
2. `app/views/jobs/index.html.erb` - Updated button logic
3. `spec/models/job_posting_status_spec.rb` - New test file

## Edge Cases Handled

- `exported_at` is nil → Returns false (not generated)
- Multiple applications → Shows most recent
- Generated yesterday → Allows new generation today
- No PDFs yet → Shows primary "Tailor & Export" button

## Future Enhancements

Potential improvements:
- Show total number of times generated
- Add "Regenerate" confirmation dialog
- Track generation count per job
- Show last generation date in tooltip

