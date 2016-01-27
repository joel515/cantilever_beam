class BeamsController < ApplicationController
  before_action :set_beam, only: [:show, :submit, :results, :edit, :update,
    :destroy, :clean, :copy, :embed, :kill]
  before_action :get_displayed_result, only: [:results, :embed]
  before_action :get_last_page, only: [:destroy]

  def index
    if Beam.count > 0
      @beams = Beam.order(:id).page params[:page]
    else
      redirect_to root_url
    end
  end

  # TODO: Materials should be initially seeded.  However, there should be an
  # error check if materials don't exist.
  def new
    @beam = Beam.new
    @beam.material = Material.find(1)
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
    @beam.submit if @beam.ready?
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
    if @beam.editable?
      if @beam.update_attributes(beam_params)
        @beam.delete_staging_directories
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
      @beam.delete_staging_directories
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
      @beam.delete_staging_directories
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
    duplicate_beam = @beam.dup
    duplicate_beam.name = generate_duplicate_name(@beam.name)
    duplicate_beam.ready
    if request.referrer.include? index_path
      redirect_to index_path(page:   Beam.page.num_pages,
                             anchor: duplicate_beam.prefix)
    else
      redirect_to duplicate_beam
    end
  end

  def embed
    render layout: false, file: @beam.graphics_file(@result.to_sym)
  end

  def kill
    if @beam.terminatable?
      @beam.kill
      flash[:success] = "Terminating job for #{@beam.name}."
    else
      flash[:danger] = "Job for #{@beam.name} is not running."
    end

    if request.referrer.include? index_path
      redirect_to request.referrer
    else
      redirect_to @beam
    end
  end

  def update_material
    @material_id = params[:material_id].to_i
  end

  private

    def beam_params
      params.require(:beam).permit(:name, :length, :width, :height, :meshsize,
                                   :load, :length_unit, :width_unit, :material_id,
                                   :height_unit, :meshsize_unit, :load_unit,
                                   :result_unit_system, :cores)
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

    # Generate a new name when copying a beam by adding the suffix "-Copy" and
    # an iterator if necessary.
    def generate_duplicate_name(original_name)
      suffix = "-Copy"
      duplicate_name = original_name
      duplicate_name += suffix unless original_name.include? suffix
      iter = 1
      while Beam.where("lower(name) =?", duplicate_name.downcase).first
        duplicate_name.slice!((0...duplicate_name.length).find_all \
          { |i| duplicate_name[i, suffix.length] == suffix }.last + \
          suffix.length)
        duplicate_name += iter.to_s
        iter += 1
      end
      duplicate_name
    end
end
