class BeamsController < ApplicationController
  before_action :set_beam, only: [:show, :results, :edit, :update, :destroy,
    :clean, :copy, :embed]
  before_action :get_displayed_result, only: [:results, :embed]
  before_action :get_last_page, only: [:destroy]

  def index
    if Beam.count > 0
      @beams = Beam.order(:id).page params[:page]
    else
      redirect_to root_url
    end
  end

  def new
    @beam = Beam.new
  end

  def show
  end

  def edit
  end

  def results
  end

  def create
    @beam = Beam.new(beam_params)
    if @beam.save
      flash[:success] = "Successfully created #{@beam.name}."
      redirect_to @beam
    else
      render 'new'
    end
  end

  def update
    if @beam.editable?
      if @beam.update_attributes(beam_params)
        @beam.job.delete_staging_directories
        @beam.ready
        flash[:success] = "Successully updated #{@beam.name}."
        redirect_to @beam
      else
        render 'edit'
      end
    else
      flash[:danger] = "#{@beam.name} is not editable at this time."
      render 'edit'
    end
  end

  def destroy
    if @beam.destroyable?
      @beam.job.delete_staging_directories
      @beam.destroy
      flash[:success] = "Beam deleted."
    else
      flash[:danger] = "Beam cannot be deleted at this time."
    end

    if request.referrer.include? index_path
      if @last_page > Beam.page.num_pages
        redirect_to index_path(page: Beam.page.num_pages)
      else
        redirect_to request.referrer
      end
    else
      redirect_to index_url
    end
  end

  def clean
    if @beam.cleanable?
      @beam.job.delete_staging_directories
      @beam.ready
      flash[:success] = "Job directory successfully deleted."
    else
      flash[:danger] = "Beam cannot be cleaned at this time."
    end

    if request.referrer.include? results_beam_path
      redirect_to @beam
    else
      redirect_to request.referrer || index_url
    end
  end

  def copy
    duplicate_beam = @beam.duplicate
    if duplicate_beam.save
      if request.referrer.include? index_path
        redirect_to index_path(page:   Beam.page.num_pages,
                               anchor: duplicate_beam.prefix)
      else
        redirect_to duplicate_beam
      end
    else
      flash[:danger] = "Unable to copy #{@beam.name}."
      redirect_to request.referrer
    end
  end

  def embed
    render layout: false, file: @beam.graphics_file(@result.to_sym)
  end

  def update_material
    @material_id = params[:material_id].to_i
  end

  private

    def beam_params
      params.require(:beam).permit(:name, :length, :width, :height, :meshsize,
                                   :load, :length_unit, :width_unit, :material_id,
                                   :height_unit, :meshsize_unit, :load_unit,
                                   :result_unit_system, job_attributes: [:cores,
                                   :machines, :config, :id] )
    end

    def set_beam
      @beam = Beam.find(params[:id])
    end

    def get_displayed_result
      @result = params[:result].nil? ? "stress" : params[:result]
    end

    # Get the last visited paginated index page when destroying beam.  This
    # provides input to handle a redirect to the previous pagination if the
    # beam being deleted is the last one on the page.
    def get_last_page
      query = URI.parse(request.referrer).query
      @last_page = query.nil? ? 0 : CGI.parse(query)["page"].first.to_i
    end
end
