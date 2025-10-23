// Keyboard shortcuts for JobWizard
// j/k: navigate jobs, /: focus search, a: apply, i: ignore, r: reject

document.addEventListener('DOMContentLoaded', () => {
  const shortcuts = {
    '/': (e) => {
      e.preventDefault()
      const searchInput = document.querySelector('input[name="q"]')
      if (searchInput) {
        searchInput.focus()
        searchInput.select()
      }
    },
    'j': (e) => {
      if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') return
      e.preventDefault()
      const nextJob = document.querySelector('.job-card:has(.hover\\:bg-gray-50):hover')
      const jobs = Array.from(document.querySelectorAll('.job-card'))
      const currentIndex = jobs.findIndex(j => j.classList.contains('bg-blue-50'))
      const nextIndex = Math.min(currentIndex + 1, jobs.length - 1)
      if (jobs[nextIndex]) {
        jobs.forEach(j => j.classList.remove('bg-blue-50'))
        jobs[nextIndex].classList.add('bg-blue-50')
        jobs[nextIndex].scrollIntoView({ behavior: 'smooth', block: 'center' })
      }
    },
    'k': (e) => {
      if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') return
      e.preventDefault()
      const jobs = Array.from(document.querySelectorAll('.job-card'))
      const currentIndex = jobs.findIndex(j => j.classList.contains('bg-blue-50'))
      const prevIndex = Math.max(currentIndex - 1, 0)
      if (jobs[prevIndex]) {
        jobs.forEach(j => j.classList.remove('bg-blue-50'))
        jobs[prevIndex].classList.add('bg-blue-50')
        jobs[prevIndex].scrollIntoView({ behavior: 'smooth', block: 'center' })
      }
    },
    'a': (e) => {
      if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') return
      const selectedJob = document.querySelector('.job-card.bg-blue-50')
      if (selectedJob) {
        const applyLink = selectedJob.querySelector('a[href*="/applied"]')
        if (applyLink) {
          e.preventDefault()
          applyLink.click()
        }
      }
    },
    'i': (e) => {
      if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') return
      const selectedJob = document.querySelector('.job-card.bg-blue-50')
      if (selectedJob) {
        const ignoreLink = selectedJob.querySelector('a[href*="/ignore"]')
        if (ignoreLink) {
          e.preventDefault()
          ignoreLink.click()
        }
      }
    },
    'r': (e) => {
      if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') return
      const selectedJob = document.querySelector('.job-card.bg-blue-50')
      if (selectedJob) {
        const rejectLink = selectedJob.querySelector('a[href*="/rejected"]')
        if (rejectLink) {
          e.preventDefault()
          rejectLink.click()
        }
      }
    }
  }

  document.addEventListener('keydown', (e) => {
    const key = e.key.toLowerCase()
    if (shortcuts[key]) {
      shortcuts[key](e)
    }
  })
})

