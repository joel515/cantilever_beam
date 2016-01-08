class BeamsController < ApplicationController
  before_action :set_beam, only: [:show, :submit, :results, :edit, :update,
    :destroy, :clean, :copy, :embed, :kill]
  before_action :get_displayed_result, only: [:results, :embed]

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

  def submit
    @beam.submit
    if @beam.submitted?
      flash[:success] = "Simulation for #{@beam.name} successfully submitted!"
    else
      flash[:danger] = "Submission for #{@beam.name} failed."
    end
    if request.referrer.include? index_path
      redirect_to request.referrer
    else
      redirect_to @beam
    end
  end

  def update
    if @beam.update_attributes(beam_params)
      @beam.clean
      flash[:success] = "Successully updated #{@beam.name}."
      redirect_to @beam
    else
      render 'edit'
    end
  end

  def destroy
    @beam.clean
    @beam.destroy
    flash[:success] = "Beam deleted."
    if request.referrer.include? index_path
      redirect_to request.referrer
    else
      redirect_to index_url
    end
  end

  def clean
    @beam.clean
    flash[:success] = "Job directory successfully deleted."
    if request.referrer.include? results_beam_path
      redirect_to @beam
    else
      redirect_to request.referrer || index_url
    end
  end

  def copy
    duplicate_beam = @beam.dup
    duplicate_beam.name = "#{@beam.name}-Copy"
    duplicate_beam.ready
    if request.referrer.include? index_path
      redirect_to index_path(page:   Beam.page.num_pages,
                             anchor: duplicate_beam.prefix)
    else
      redirect_to duplicate_beam
    end
  end

  def embed
    @beam.generate_results if @beam.graphics_file(@result.to_sym).empty?
    render layout: false, file: @beam.graphics_file(@result.to_sym)
  end

  def kill
    # TODO: Implement kill sequence.
    if request.referrer.include? index_path
      redirect_to index_path(page:   Beam.page.current_page,
                             anchor: @beam.prefix)
    else
      redirect_to @beam
    end
  end

  private

    def beam_params
      params.require(:beam).permit(:name, :length, :width, :height, :meshsize,
                                   :modulus, :poisson, :density, :material,
                                   :load, :length_unit, :width_unit, :height_unit,
                                   :meshsize_unit, :modulus_unit, :density_unit,
                                   :load_unit, :result_unit_system)
    end

    def set_beam
      @beam = Beam.find(params[:id])
    end

    def get_displayed_result
      @result = params[:result].nil? ? "stress" : params[:result]
    end
end
