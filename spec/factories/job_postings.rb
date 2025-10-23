FactoryBot.define do
  factory :job_posting do
    company { 'MyString' }
    title { 'MyString' }
    description { 'MyText' }
    location { 'MyString' }
    remote { false }
    posted_at { '2025-10-21 19:18:39' }
    url { 'MyString' }
    source { 'MyString' }
    metadata { '' }
  end
end
