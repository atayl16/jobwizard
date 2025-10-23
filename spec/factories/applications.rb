FactoryBot.define do
  factory :application do
    job_posting { nil }
    company { 'MyString' }
    role { 'MyString' }
    job_description { 'MyText' }
    flags { '' }
    output_path { 'MyString' }
    status { 1 }
  end
end
