class JobsController < ApplicationController
  def submit
    @job.submit if @job.ready?
    if @job.submitted?
      flash[:success] = "Simulation for #{@job.beam.name} successfully submitted!"
    else
      flash[:danger] = "Submission for #{@job.beam.name} failed."
    end

    if request.referrer.include? index_path
      redirect_to request.referrer
    else
      redirect_to @job.beam
    end
  end

  def kill
    if @job.terminatable?
      @job.kill
      flash[:success] = "Terminating job for #{@job.beam.name}."
    else
      flash[:danger] = "Job for #{@job.beam.name} is not running."
    end

    if request.referrer.include? index_path
      redirect_to request.referrer
    else
      redirect_to @job.beam
    end
  end
end
