class JobSkillAssessmentsController < ApplicationController
  before_action :set_job_posting
  before_action :set_assessment, only: [:update]

  def create
    @assessment = @job_posting.job_skill_assessments.build(assessment_params)

    if @assessment.save
      redirect_to job_path(@job_posting), notice: 'Skill assessment saved'
    else
      redirect_to job_path(@job_posting), alert: 'Failed to save skill assessment'
    end
  end

  def update
    if @assessment.update(assessment_params)
      redirect_to job_path(@job_posting), notice: 'Skill assessment updated'
    else
      redirect_to job_path(@job_posting), alert: 'Failed to update skill assessment'
    end
  end

  private

  def set_job_posting
    @job_posting = JobPosting.find(params[:job_id])
  end

  def set_assessment
    @assessment = @job_posting.job_skill_assessments.find(params[:id])
  end

  def assessment_params
    params.expect(job_skill_assessment: %i[skill_name have proficiency])
  end
end
