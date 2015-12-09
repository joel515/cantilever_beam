class BeamsController < ApplicationController
  before_action :set_beam, only: [:show, :submit, :results]

  def index
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
    flash[:success] = "Simulation for #{@beam.name} successful!"
    render 'results'
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
