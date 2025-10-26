# JobWizard UI/UX Audit & Improvement Plan

**Date**: 2025-10-23  
**Scope**: Comprehensive UI/UX review for better navigation, organization, and user experience

---

## Current State Analysis

### Existing Pages
1. **Dashboard** (`/`) - Quick Apply + Suggested Jobs + Recent Apps
2. **Jobs Board** (`/jobs`) - Full job listings with search/filters
3. **Job Details** (`/jobs/:id`) - Individual job with skill assessment
4. **New Application** (`/applications/new`) - Manual form entry
5. **Application Show** (`/applications/:id`) - Generated PDFs view
6. **Settings** (`/settings/filters`) - Blocklist management
7. **AI Usages** (`/ai/usages`) - Cost tracking ledger

### Current Navigation (Header)
- Logo (links to root)
- Jobs
- New Application
- Settings
- Output folder path (with Open button in dev)

---

## Issues Identified

### 🔴 HIGH PRIORITY

**I1: Confusing Root vs Dashboard**
- `root` points to `applications#new` but there's also `/dashboard`
- Users don't know which is "home"
- **Impact**: Navigation confusion

**I2: No Applications List Page**
- Can only see last 10 on dashboard
- No way to browse all historical applications
- No search/filter for past applications
- **Impact**: Can't find old PDFs

**I3: AI Cost Buried**
- Only visible on dashboard in small section
- No dedicated page (have `/ai/usages` but not linked prominently)
- **Impact**: Hard to monitor costs

**I4: Settings Too Narrow**
- Only has blocklist management
- Should include profile, sources, preferences
- **Impact**: Nowhere to configure the app

**I5: No Job Sources Management UI**
- Must manually edit `sources.yml`
- Can't enable/disable sources from UI
- **Impact**: Technical barrier to configuration

### 🟡 MEDIUM PRIORITY

**I6: Dashboard Overwhelming**
- Three sections on one page
- Quick Apply + Jobs + Recent Apps all competing
- **Impact**: Cognitive overload

**I7: No Stats/Analytics Page**
- No overview of activity (# jobs fetched, # PDFs generated, success rate)
- **Impact**: No visibility into system usage

**I8: Jobs Board Missing Context**
- No explanation of how jobs got there
- No link back to sources configuration
- **Impact**: Confusion about where jobs come from

**I9: Application Show Page Basic**
- Just download links
- No activity log, no notes field
- **Impact**: Limited utility

**I10: No Help/Docs In-App**
- README is external
- No tooltips or help text
- **Impact**: Users rely on external docs

### 🟢 LOW PRIORITY

**I11: Mobile Navigation**
- No hamburger menu
- Header gets cramped
- **Impact**: Poor mobile UX

**I12: No Breadcrumbs**
- Hard to know where you are
- **Impact**: Minor navigation confusion

**I13: No Keyboard Shortcuts**
- Could add `/` for search, `n` for new app
- **Impact**: Power user efficiency

---

## Proposed Improvements

### Phase 1: Navigation & Structure (HIGH)

#### **P1.1: Unified Root & Navigation**

**Fix root route conflict:**
```ruby
# config/routes.rb
root 'dashboard#show'  # Make dashboard the true home

# Rename current dashboard to something else or merge
```

**New Primary Navigation:**
```
┌─────────────────────────────────────────────┐
│ 🧙 JobWizard                       [Search] │
│                                              │
│ Dashboard | Jobs | Applications | Settings  │
└─────────────────────────────────────────────┘
```

**Sub-navigation for each section:**
- **Jobs**: Board | Sources | Fetch History
- **Applications**: Recent | All | Analytics
- **Settings**: Profile | Sources | Filters | API Keys

---

#### **P1.2: Applications List Page** ⭐️ NEW PAGE

**Route**: `/applications`

**Purpose**: Browse all historical applications with search/filter

**Features**:
- Table with: Date, Company, Role, Status, Cost, Actions
- Search by company/role
- Filter by date range, status
- Bulk actions (delete old ones)
- Export to CSV
- Pagination

**Layout**:
```
┌────────────────────────────────────────────┐
│ All Applications (245)          [+ New]    │
│ ┌──────────────┬───────────────────────┐  │
│ │ Search       │ Filters:  ▼ Date  ▼ │  │
│ └──────────────┴───────────────────────┘  │
│                                            │
│ Date       Company        Role    Status  │
│ ───────────────────────────────────────── │
│ 2025-10-23 Instacart     Senior  ✓ Ready │
│ 2025-10-22 Figma         Staff   ✓ Ready │
│ 2025-10-21 Netflix       Lead    ✓ Ready │
│ ...                                        │
└────────────────────────────────────────────┘
```

---

#### **P1.3: Settings Hub** ⭐️ EXPANDED

**Route**: `/settings` (index page)

**Sub-pages**:
1. `/settings/profile` - Edit profile.yml visually
2. `/settings/experience` - Edit experience.yml visually
3. `/settings/sources` - Manage job sources (enable/disable)
4. `/settings/filters` - Blocklists (already exists)
5. `/settings/api_keys` - OpenAI key, other integrations
6. `/settings/preferences` - Output path, PDF style, etc.

**Settings Index Layout**:
```
┌────────────────────────────────────────────┐
│ Settings                                    │
│                                             │
│ 👤 Profile & Experience                    │
│    Edit your resume data                   │
│    → /settings/profile                     │
│                                             │
│ 🏢 Job Sources                              │
│    Manage Greenhouse, Lever, etc.          │
│    → /settings/sources                     │
│                                             │
│ 🔑 API Keys                                 │
│    OpenAI and other integrations           │
│    → /settings/api_keys                    │
│                                             │
│ 🚫 Filters & Blocklists                    │
│    Block companies and keywords            │
│    → /settings/filters                     │
└────────────────────────────────────────────┘
```

---

#### **P1.4: Job Sources Management UI** ⭐️ NEW PAGE

**Route**: `/settings/sources`

**Purpose**: Visual editor for `sources.yml`

**Features**:
- List all configured sources
- Toggle active/inactive
- Add new source (form)
- Test fetch (button)
- View last fetch time/results

**Layout**:
```
┌────────────────────────────────────────────┐
│ Job Sources                    [+ Add New] │
│                                             │
│ Active Sources (3)                          │
│ ┌───────────────────────────────────────┐ │
│ │ ✓ Instacart (Greenhouse)              │ │
│ │   Last fetched: 2 hours ago (5 jobs)  │ │
│ │   [Test] [Edit] [Disable]             │ │
│ └───────────────────────────────────────┘ │
│ ┌───────────────────────────────────────┐ │
│ │ ✓ Figma (Lever)                       │ │
│ │   Last fetched: 1 day ago (0 jobs)    │ │
│ │   [Test] [Edit] [Disable]             │ │
│ └───────────────────────────────────────┘ │
│                                             │
│ Inactive Sources (2)                        │
│ ┌───────────────────────────────────────┐ │
│ │ ○ Bosch (SmartRecruiters)             │ │
│ │   [Enable] [Edit] [Delete]            │ │
│ └───────────────────────────────────────┘ │
└────────────────────────────────────────────┘
```

---

### Phase 2: Dashboard Improvements (MEDIUM)

#### **P2.1: Simplified Dashboard**

**Current**: Quick Apply + Jobs + Recent Apps all on one page

**Proposed**: Tab-based or card-based with "View All" links

```
┌────────────────────────────────────────────┐
│ Dashboard                                   │
│                                             │
│ 📊 Overview                                 │
│ ├─ 5 new jobs today                        │
│ ├─ 12 applications this month              │
│ ├─ $0.24 AI cost (MTD)                     │
│ └─ Last fetch: 2 hours ago                 │
│                                             │
│ ⚡ Quick Actions                            │
│ [Generate PDF]  [Check Jobs]  [View All]   │
│                                             │
│ 🎯 Recent Activity (Last 5)                │
│ • Generated PDF for Instacart - Senior...  │
│ • Fetched 3 new jobs from Figma            │
│ • Ignored Acme Corp - Junior...            │
└────────────────────────────────────────────┘
```

---

#### **P2.2: Analytics Page** ⭐️ NEW PAGE

**Route**: `/analytics` or `/dashboard/stats`

**Purpose**: High-level stats and trends

**Features**:
- Jobs fetched over time (chart)
- Applications generated per week
- AI cost trends
- Top companies
- Success rate (applied / generated)
- Average time to generate

---

### Phase 3: Enhanced Pages (MEDIUM)

#### **P3.1: Job Show Page Enhancements**

**Current**: Basic info + skill assessment

**Add**:
- Notes field (save to job_posting.notes)
- Activity log (fetched, viewed, generated, applied)
- Related jobs from same company
- "Why matched" explanation (scoring breakdown)

---

#### **P3.2: Application Show Enhancements**

**Current**: Just download links

**Add**:
- Preview PDFs inline (iframe or PDF.js)
- Edit & regenerate button
- Notes field
- Application timeline (generated → downloaded → applied)
- Email button (mailto: with attachments hint)

---

### Phase 4: Quality of Life (LOW)

#### **P4.1: Breadcrumbs**

Add to all pages:
```
Home > Jobs > Instacart - Senior Engineer
Home > Applications > #123
Home > Settings > Sources
```

---

#### **P4.2: Global Search**

Add search in header:
- Search jobs (title, company)
- Search applications (company, role)
- Jump to page (fuzzy match)

---

#### **P4.3: Keyboard Shortcuts**

- `/` - Focus search
- `n` - New application
- `j/k` - Navigate lists
- `?` - Show shortcuts modal

---

#### **P4.4: Help/Docs Integration**

- `?` icon in header → opens help modal
- Contextual help tooltips
- Inline examples on forms

---

## Implementation Priority

### Immediate (Do Now)
1. ✅ **P1.1**: Fix root route (make dashboard true home)
2. ✅ **P1.2**: Create `/applications` list page
3. ✅ **P1.3**: Expand settings to hub with index
4. ✅ **P1.4**: Job sources management UI

### Short Term (Next Week)
5. **P2.1**: Simplify dashboard
6. **P2.2**: Analytics page
7. **P3.1**: Job show enhancements (notes)
8. **P3.2**: Application show enhancements

### Long Term (Nice to Have)
9. **P4.1**: Breadcrumbs
10. **P4.2**: Global search
11. **P4.3**: Keyboard shortcuts
12. **P4.4**: Help integration

---

## Quick Wins (< 1 hour each)

1. **Fix root route** - 5 min
2. **Add breadcrumbs** - 30 min
3. **Link AI usages in nav** - 5 min
4. **Add "View All Applications" button** - 10 min
5. **Add notes field to jobs** - 20 min

---

## User Flows to Improve

### Current: Generate PDF from Job
```
Jobs Board → Click Job → Tailor & Export → (wait) → Where's my PDF?
```

**Improved**:
```
Jobs Board → Click Job → Tailor & Export → Toast: "Generating..." 
→ Toast: "✓ Ready! View PDFs" (clickable) → Application Show Page
```

### Current: Find Old Application
```
Dashboard → Scroll Recent Apps → If not there, lost forever
```

**Improved**:
```
Applications List → Search "Instacart" → Click → View/Download
```

### Current: Add New Job Source
```
SSH into server → Edit sources.yml → Restart? → Hope it works
```

**Improved**:
```
Settings → Sources → + Add New → Form → Test → Save
```

---

## Mockups Needed

1. Applications list page
2. Settings hub/index
3. Sources management UI
4. Analytics dashboard
5. Enhanced job show (with notes)

---

## Technical Notes

- Use Turbo Frames for live updates
- Keep mobile-first approach
- Use existing Tailwind classes
- Add Stimulus controllers sparingly
- Maintain local-only constraints

---

**Status**: READY FOR IMPLEMENTATION
**Estimated Effort**: 2-3 days for immediate items

---

