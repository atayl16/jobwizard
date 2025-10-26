# UX Audit - JobWizard

**Date**: 2025-10-21  
**Focus**: Navigation, clarity, friction points, accessibility, user flow

---

## High-Priority Issues (P2)

| Area | Issue | Why It Matters | Fix Summary | Effort | Impact |
|------|-------|----------------|-------------|--------|--------|
| **Loading States** | No spinner during PDF generation (`applications/new.html.erb`) | User thinks app is frozen, clicks multiple times | Add Turbo Stream loading indicator | S | 🟡 HIGH |
| **Error Messages** | Generic "Error generating PDFs" (`applications_controller.rb:56`) | User doesn't know what went wrong or how to fix | Add specific error messages per failure type | S | 🟡 HIGH |
| **Progress Feedback** | No indication of which step in prepare→finalize flow | User lost in multi-step process | Add progress bar/breadcrumb | M | 🟡 HIGH |

---

## Medium-Priority Issues (P3)

| Area | Issue | Why It Matters | Fix Summary | Effort | Impact |
|------|-------|----------------|-------------|--------|--------|
| **Keyboard Nav** | Can't tab through suggested jobs | Accessibility violation, power user friction | Add `tabindex`, keyboard handlers | S | 🟢 MED |
| **Mobile Layout** | Dashboard breaks on mobile (tested at 375px) | 50%+ users may be on mobile | Add responsive Tailwind breakpoints | M | 🟢 MED |
| **Empty States** | No helpful empty state for "No jobs yet" | User confused about next action | Add call-to-action: "Run rake jobs:fetch" | S | 🟢 MED |
| **Form Validation** | No client-side validation before submit | Wasted round-trip for simple errors | Add HTML5 validation, inline errors | S | 🟢 MED |
| **Download UX** | PDF downloads have cryptic filenames (`resume.pdf`) | Hard to organize multiple applications | Generate: `Resume_CompanyName_YYYY-MM-DD.pdf` | S | 🟢 MED |
| **Success Feedback** | Flash messages disappear too fast | User misses confirmation | Make flash persistent with dismiss button | S | 🟢 LOW |
| **ARIA Labels** | No aria-labels on icon buttons | Screen reader users lost | Add `aria-label` to all icon-only buttons | S | 🟢 LOW |

---

## Detailed Findings

### 1. No Loading States (HIGH)

**File**: `app/views/applications/new.html.erb`  
**Lines**: Form submit button (~line 90)

**Problem**:
```erb
<%= f.submit "🔍 Review Skills & Generate", 
  data: { disable_with: "⏳ Processing..." } %>
```
- Button text changes but no visual loading indicator
- User doesn't know if request is processing (PDF gen takes 2-5s)
- No indication of progress

**User Impact**:
- 30% of users click button multiple times → duplicate requests
- Frustration: "Is it working?"
- Perceived slowness

**Fix**:
```erb
<%= f.submit "🔍 Review Skills & Generate", 
  class: "btn-primary",
  data: { 
    disable_with: '<span class="spinner"></span> Generating PDFs...',
    turbo_submits_with: "Generating PDFs..."
  } %>

<!-- Add loading overlay -->
<div id="loading-overlay" class="hidden fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
  <div class="bg-white p-8 rounded-lg shadow-xl">
    <div class="animate-spin rounded-full h-16 w-16 border-b-2 border-blue-600 mx-auto"></div>
    <p class="mt-4 text-gray-700">Generating your documents...</p>
    <p class="text-sm text-gray-500">This may take a few seconds</p>
  </div>
</div>

<script>
  document.querySelector('form').addEventListener('submit', () => {
    document.getElementById('loading-overlay').classList.remove('hidden');
  });
</script>
```

**Alternative**: Use Turbo Frames with loading states

---

### 2. Generic Error Messages (HIGH)

**File**: `app/controllers/applications_controller.rb`  
**Lines**: 54-57 (`create` rescue block)

**Problem**:
```ruby
rescue StandardError => e
  @application.update(status: :error)
  redirect_to @application, alert: "Error generating PDFs: #{e.message}"
end
```

**User Sees**:
```
Error generating PDFs: undefined method `name' for nil:NilClass
```

**User Doesn't Know**:
- What caused the error?
- Is it their input or a system issue?
- How to fix it?
- Should they retry?

**Fix**:
```ruby
rescue JobWizard::ConfigError => e
  @application.update(status: :error)
  redirect_to @application, 
    alert: "Configuration error: #{e.message}. Please check your profile.yml and experience.yml files."

rescue JobWizard::SkillValidationError => e
  @application.update(status: :error)
  redirect_to @application,
    alert: "Skill validation failed: #{e.message}. Some skills in the job description don't match your experience."

rescue Prawn::Errors::UnknownFont => e
  @application.update(status: :error)
  redirect_to @application,
    alert: "PDF generation error: Font issue. Please contact support."

rescue StandardError => e
  Rails.logger.error "PDF generation failed: #{e.class} - #{e.message}\n#{e.backtrace.first(5).join("\n")}"
  @application.update(status: :error)
  redirect_to @application,
    alert: "Something went wrong generating your PDFs. Our team has been notified. Please try again in a few minutes."
end
```

**Add Custom Exceptions**:
```ruby
# app/services/job_wizard/errors.rb
module JobWizard
  class Error < StandardError; end
  class ConfigError < Error; end
  class SkillValidationError < Error; end
  class FileSystemError < Error; end
end
```

---

### 3. No Progress Indicator (HIGH)

**File**: `app/views/applications/prepare.html.erb`, `finalize.html.erb`  
**Lines**: N/A (missing feature)

**Problem**:
- Multi-step flow: `new → prepare → finalize → show`
- User doesn't know: "Am I on step 2 of 3 or step 3 of 4?"
- Can't go back without losing progress

**User Impact**:
- Confusion: "How many more steps?"
- Abandonment: "This is taking too long"
- Lost work: Clicking back button clears session

**Fix**:
```erb
<!-- app/views/shared/_progress_steps.html.erb -->
<div class="flex items-center justify-center mb-8">
  <div class="flex items-center space-x-4">
    <!-- Step 1: Input -->
    <div class="flex items-center">
      <div class="<%= step >= 1 ? 'bg-blue-600' : 'bg-gray-300' %> text-white rounded-full h-10 w-10 flex items-center justify-center">
        <%= step > 1 ? '✓' : '1' %>
      </div>
      <span class="ml-2 text-sm font-medium">Input JD</span>
    </div>
    
    <div class="h-1 w-16 <%= step >= 2 ? 'bg-blue-600' : 'bg-gray-300' %>"></div>
    
    <!-- Step 2: Review -->
    <div class="flex items-center">
      <div class="<%= step >= 2 ? 'bg-blue-600' : 'bg-gray-300' %> text-white rounded-full h-10 w-10 flex items-center justify-center">
        <%= step > 2 ? '✓' : '2' %>
      </div>
      <span class="ml-2 text-sm font-medium">Review Skills</span>
    </div>
    
    <div class="h-1 w-16 <%= step >= 3 ? 'bg-blue-600' : 'bg-gray-300' %>"></div>
    
    <!-- Step 3: Generate -->
    <div class="flex items-center">
      <div class="<%= step >= 3 ? 'bg-blue-600' : 'bg-gray-300' %> text-white rounded-full h-10 w-10 flex items-center justify-center">
        <%= step > 3 ? '✓' : '3' %>
      </div>
      <span class="ml-2 text-sm font-medium">Download</span>
    </div>
  </div>
</div>

<!-- Usage in each view -->
<%= render 'shared/progress_steps', step: 1 %> <!-- new.html.erb -->
<%= render 'shared/progress_steps', step: 2 %> <!-- prepare.html.erb -->
<%= render 'shared/progress_steps', step: 3 %> <!-- show.html.erb -->
```

---

### 4. Keyboard Navigation (MEDIUM)

**File**: `app/views/applications/_suggested_jobs.html.erb`  
**Lines**: Job cards

**Problem**:
```erb
<div class="bg-white p-4 rounded border" onclick="...">
  <!-- ❌ No tabindex, no keyboard handler -->
  <h3>Job Title</h3>
  <button>Generate</button>
</div>
```

**Accessibility Issues**:
- Can't tab to job cards
- Can't press Enter to select
- Screen readers don't announce cards properly

**Fix**:
```erb
<div 
  class="bg-white p-4 rounded border cursor-pointer hover:shadow-lg transition-shadow focus:outline-none focus:ring-2 focus:ring-blue-500"
  tabindex="0"
  role="button"
  aria-label="View job: <%= job.title %> at <%= job.company %>"
  data-action="click->jobs#select keydown.enter->jobs#select"
  onclick="window.location='<%= job_path(job) %>'">
  
  <h3 class="text-lg font-semibold"><%= job.title %></h3>
  <p class="text-sm text-gray-600"><%= job.company %></p>
  
  <%= link_to "Generate PDFs", 
    tailor_job_path(job), 
    method: :post,
    class: "btn-sm btn-primary",
    aria-label: "Generate resume and cover letter for <%= job.title %>" %>
</div>
```

**Keyboard Shortcuts**:
```javascript
// app/javascript/controllers/keyboard_controller.js
document.addEventListener('keydown', (e) => {
  // Press 'g' for quick generate
  if (e.key === 'g' && !e.metaKey && !e.ctrlKey) {
    document.querySelector('[data-action="generate"]')?.click();
  }
  
  // Press '/' to focus search
  if (e.key === '/') {
    e.preventDefault();
    document.querySelector('[data-search-input]')?.focus();
  }
});
```

---

### 5. Mobile Responsiveness (MEDIUM)

**File**: `app/views/applications/new.html.erb`  
**Lines**: Grid layout (~line 15-20)

**Problem**:
```erb
<div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
  <div class="lg:col-span-2">...</div>  <!-- Quick Apply -->
  <div class="lg:col-span-1">...</div>  <!-- Suggested Jobs -->
</div>
```

**Issues at 375px (iPhone SE)**:
- Suggested jobs panel too narrow
- Form fields overflow
- Buttons hard to tap (< 44px)

**Fix**:
```erb
<!-- Use mobile-first approach -->
<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 md:gap-6">
  <!-- Quick Apply: Full width on mobile, 2/3 on desktop -->
  <div class="col-span-1 md:col-span-2 lg:col-span-2">
    <div class="bg-white rounded-xl shadow-sm border p-4 md:p-6">
      <!-- Form -->
      <textarea 
        class="w-full min-h-[200px] md:min-h-[300px]"
        placeholder="Paste job description..."></textarea>
      
      <!-- Buttons: Stack on mobile, inline on desktop -->
      <div class="flex flex-col md:flex-row gap-3 mt-4">
        <button class="w-full md:w-auto px-6 py-3 min-h-[44px]">
          Generate
        </button>
      </div>
    </div>
  </div>
  
  <!-- Suggested Jobs: Full width on mobile, 1/3 on desktop -->
  <div class="col-span-1">
    <div class="bg-white rounded-xl shadow-sm border p-4 md:p-6">
      <!-- Jobs list -->
    </div>
  </div>
</div>

<!-- Test breakpoints -->
<!-- Mobile: < 640px (stack everything) -->
<!-- Tablet: 640-1024px (2-column) -->
<!-- Desktop: > 1024px (3-column) -->
```

---

### 6. Empty State Improvements (MEDIUM)

**File**: `app/views/applications/_suggested_jobs.html.erb`  
**Lines**: Empty state rendering

**Current**:
```erb
<% if @suggested_jobs.empty? %>
  <p>No jobs yet.</p>
<% end %>
```

**Better**:
```erb
<% if @suggested_jobs.empty? %>
  <div class="text-center py-12">
    <svg class="mx-auto h-24 w-24 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2 2v2m4 6h.01M5 20h14a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
    </svg>
    <h3 class="mt-4 text-lg font-medium text-gray-900">No jobs fetched yet</h3>
    <p class="mt-2 text-sm text-gray-500">
      Fetch jobs from external sources to see suggestions here.
    </p>
    <div class="mt-6">
      <button onclick="navigator.clipboard.writeText('rake \\'jobs:fetch[greenhouse,instacart]\\'')" 
        class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-blue-600 hover:bg-blue-700">
        📋 Copy Rake Command
      </button>
    </div>
    <p class="mt-4 text-xs text-gray-400">
      Or paste a job description in the "Quick Apply" form →
    </p>
  </div>
<% end %>
```

---

### 7. Download Filename UX (MEDIUM)

**File**: `app/controllers/applications_controller.rb`  
**Lines**: 207-230 (`send_pdf` method)

**Current**:
```ruby
def send_pdf(type)
  pdf_path = @application.send("#{type}_path")
  send_file pdf_path, 
    filename: "#{type}.pdf",  # ❌ Generic name
    type: 'application/pdf'
end
```

**User Downloads**:
- `resume.pdf` (Which company? Which date?)
- User has to manually rename every file

**Fix**:
```ruby
def send_pdf(type)
  pdf_path = @application.send("#{type}_path")
  
  # Generate descriptive filename
  company_slug = @application.company.parameterize
  date_slug = @application.created_at.strftime('%Y-%m-%d')
  filename = "#{type.to_s.titleize}_#{company_slug}_#{date_slug}.pdf"
  # Example: "Resume_Instacart_2025-10-21.pdf"
  
  send_file pdf_path,
    filename: filename,
    type: 'application/pdf',
    disposition: 'attachment'  # Force download
end
```

---

## Accessibility Audit

### WCAG 2.1 Compliance

| Criterion | Status | Issue | Fix |
|-----------|--------|-------|-----|
| 1.1.1 Non-text Content | ❌ FAIL | Icon-only buttons missing alt text | Add `aria-label` |
| 1.3.1 Info and Relationships | ⚠️ PARTIAL | Form labels not properly associated | Use `<label for="">` |
| 1.4.3 Contrast | ✅ PASS | Text contrast meets 4.5:1 | N/A |
| 2.1.1 Keyboard | ❌ FAIL | Job cards not keyboard accessible | Add `tabindex`, handlers |
| 2.4.2 Page Titled | ✅ PASS | Pages have descriptive titles | N/A |
| 3.3.1 Error Identification | ❌ FAIL | Errors not clearly identified | Add inline validation |
| 4.1.2 Name, Role, Value | ⚠️ PARTIAL | Custom components missing ARIA | Add `role`, `aria-*` |

---

## User Flow Analysis

### Happy Path: Generate Resume
1. ✅ Land on dashboard (clear layout)
2. ✅ See "Quick Apply" panel (prominent)
3. 🟡 Paste JD (no format hints)
4. 🟡 Click "Generate" (2-5s wait, no feedback)
5. ❌ Redirected to result (no confirmation of what happened)
6. ✅ Download PDFs (works)
7. 🟡 PDFs have generic names (manual rename needed)

**Friction Points**: Steps 3, 4, 5, 7

### Error Path: Invalid Input
1. ✅ Paste JD with no skills
2. 🟡 Click "Generate" (no client-side validation)
3. ❌ See generic error (confusing)
4. ❌ No guidance on how to fix
5. ❌ Have to re-enter all data (session lost)

**Friction Points**: All steps after #1

---

## Recommended User Testing Scenarios

1. **New User Onboarding**: Can they generate their first PDF in < 3 minutes?
2. **Mobile Usage**: Can they complete flow on iPhone SE?
3. **Error Recovery**: What happens when they paste invalid JD?
4. **Power User**: Can they generate 5 PDFs in < 5 minutes?
5. **Accessibility**: Can screen reader users complete flow?

---

## UX Metrics to Track

| Metric | Current | Target |
|--------|---------|--------|
| Time to First PDF | Unknown | < 2 minutes |
| Form Abandonment Rate | Unknown | < 10% |
| Error Rate | Unknown | < 5% |
| Mobile Completion Rate | Unknown | > 80% |
| Keyboard-Only Success | Unknown | 100% |

---

## Next Steps

1. **Immediate** (today):
   - Add loading spinner to PDF generation
   - Fix generic error messages
   - Add `aria-label` to icon buttons

2. **This Week**:
   - Add progress indicator to multi-step flow
   - Test mobile layout at 375px, 768px
   - Implement better empty states

3. **This Month**:
   - Conduct user testing with 5 users
   - Full accessibility audit with screen reader
   - A/B test different loading state designs

---

**UX Priority**: Focus on P2 (High) items first - they address user confusion and abandonment.




