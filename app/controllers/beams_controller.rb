class BeamsController < ApplicationController
  before_action :set_beam, only: [:show, :submit, :results, :edit, :update,
    :destroy, :clean, :copy, :embed]

  def index
    if Beam.count > 0
      @beams = Beam.paginate(page: params[:page])
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
    redirect_to index_url
  end

  def update
    if @beam.update_attributes(beam_params)
      flash[:success] = "Successully updated #{@beam.name}."
      redirect_to @beam
    else
      flash[:danger] = "Problem updating #{@beam.name}."
      render 'edit'
    end
  end

  def destroy
    @beam.clean
    @beam.destroy
    flash[:success] = "Beam deleted."
    redirect_to index_url
  end

  def clean
    @beam.clean
    flash[:success] = "Job directory successfully deleted"
    # TODO: get the previous url and redirect to that
    redirect_to index_url
  end

  def copy
    duplicate_beam = @beam.dup
    duplicate_beam.name = "#{@beam.name}-Copy"
    duplicate_beam.ready
    # TODO: get the previous url and redirect to that
    redirect_to duplicate_beam
  end

  def embed
    @beam.generate_results if @beam.graphics_file.empty?
    render layout: false, file: @beam.graphics_file
  end

  private

    def beam_params
      params.require(:beam).permit(:name, :length, :width, :height, :meshsize,
                                   :modulus, :poisson, :density, :material,
                                   :load)
    end

    def set_beam
      @beam = Beam.find(params[:id])
    end
end
