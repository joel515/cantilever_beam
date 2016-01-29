class Beam < ActiveRecord::Base
  belongs_to :material
  belongs_to :job, dependent: :destroy
  accepts_nested_attributes_for :material
  accepts_nested_attributes_for :job
  validates :name,     presence: true, uniqueness: { case_sensitive: false }
  # TODO: Check name with a regex for parentheses.
  validates :length,   presence: true, numericality: { greater_than: 0 }
  validates :width,    presence: true, numericality: { greater_than: 0 }
  validates :height,   presence: true, numericality: { greater_than: 0 }
  validates :meshsize, presence: true, numericality: { greater_than: 0 }
  validates :load,     presence: true,
                       numericality: { greater_than_or_equal_to: 0 }
  validates :length_unit,        presence: true
  validates :width_unit,         presence: true
  validates :height_unit,        presence: true
  validates :meshsize_unit,      presence: true
  validates :load_unit,          presence: true
  validates :result_unit_system, presence: true
  validates :material,           presence: true

  include UnitsHelper

  validates_inclusion_of :length_unit,   in: DIMENSIONAL_UNITS.keys.map(&:to_s)
  validates_inclusion_of :width_unit,    in: DIMENSIONAL_UNITS.keys.map(&:to_s)
  validates_inclusion_of :height_unit,   in: DIMENSIONAL_UNITS.keys.map(&:to_s)
  validates_inclusion_of :meshsize_unit, in: DIMENSIONAL_UNITS.keys.map(&:to_s)
  validates_inclusion_of :load_unit,     in: FORCE_UNITS.keys.map(&:to_s)

  # Formulate a file/directory prefix using the beam's name by removing all
  # spaces and converting to lower case.
  # TODO: Maybe add ID to prefix?  Can then strip name of characters that aren't
  # allowed in GMSH and Elmer, and still ensure some type of uniqueness.
  def prefix
    name.gsub(/\s+/, "").downcase
    # name.gsub(/\W/, "").downcase
  end

  def stress_units
    RESULT_UNITS[result_unit_system.to_sym][:stress]
  end

  def displ_units
    RESULT_UNITS[result_unit_system.to_sym][:displacement]
  end

  # Calculate the beam's bending moment of inertia.
  def inertia
    convert(self, :width) * convert(self, :height)**3 / 12
  end

  # Calculate the beam's cross-sectional area.
  def area
    convert(self, :width) * convert(self, :height)
  end

  # Calculate the beam's mass.
  def mass
    convert(self, :length) * area * convert(material, :density)
  end

  # Calculate the beam's weight.
  def weight
    mass * GRAVITY
  end

  # Calculate the beam's flexural stiffness.
  def stiffness
    convert(material, :modulus) * inertia
  end

  # Calculate the total force reaction due to load and gravity.
  def force_reaction
    convert(self, :load) + weight
  end

  # Calculate the total moment reaction due to load and gravity.
  def moment_reaction
    -convert(self, :load) * convert(self, :length) + -weight * convert(self, :length) / 2
  end

  # Calculate the beam end angle due to load and gravity.
  def theta
    p = convert(self, :load)
    l = convert(self, :length)
    ei = stiffness
    w = weight

    theta_load = p * l**2 / (2 * ei) * 180 / Math::PI
    theta_grav = w * l**2 / (6 * ei) * 180 / Math::PI
    theta_load + theta_grav
  end

  # Calculate the shear modulus of the material based on the elastic modulus
  # and Poisson's ratio.
  def shear_modulus
    convert(material, :modulus) / (2 * (1 + material.poisson))
  end

  # Calculate to total displacement due to load and gravity using Timoshenko
  # theory.
  def displacement
    p = convert(self, :load)
    l = convert(self, :length)
    ei = stiffness
    a = area
    w = weight
    g = shear_modulus
    k = 5.0 / 6.0

    d_load = -p * l * (l**2 / (3 * ei) + 1 / (k * a * g))
    d_grav = -w * l * (l**2 / (8 * ei) + 1 / (2 * k * a * g))
    d_load + d_grav
  end

  # Calculate the maximum pricipal stress.
  def stress
    moment_reaction.abs * convert(self, :height) / (2 * inertia)
  end

  # Calulate the simulation error with respect to beam theory prediction.
  def error(type)
    begin
      theory = self.send(type.to_s)
      fem = fem_result(type)
      theory != 0.0 && !fem.nil? ? (fem - theory) / theory * 100 : nil
    rescue
      nil
    end
  end

  def duplicate
    duplicate_beam = self.dup
    duplicate_beam.name = generate_duplicate_name
    duplicate_beam.job = Job.new
    duplicate_beam.job.config = job.config
    duplicate_beam.job.cores = job.cores
    duplicate_beam.job.machines = job.machines
    duplicate_beam.ready
    duplicate_beam
  end

  def delete_staging_directories
    job.delete_staging_directories
  end

  def ready
    job.ready
  end

  def ready?
    job.ready?
  end

  def editable?
    job.editable?
  end

  def destroyable?
    job.destroyable?
  end

  def cleanable?
    job.cleanable?
  end

    # Capture the FEA stats and return the data as a hash.
  def fem_stats
    jobpath = Pathname.new(job.jobdir)
    std_out = jobpath + (Job::WITH_PBS ? "#{prefix}.o#{job.pid.split('.')[0]}" :
      "#{prefix}.out")

    nodes, elements, cputime, walltime = nil
    if std_out.exist?
      File.foreach(std_out) do |line|
        nodes    = line.split[6] if line.include? "Number of nodes"
        elements = line.split[6] if line.include? "Number of elements"
        cputime  = "#{line.split[3]} s" if line.include? "SOLVER TOTAL TIME"
        walltime = "#{line.split[4]} s" if line.include? "SOLVER TOTAL TIME"
      end
    end
    Hash["Number of Nodes" => nodes,
         "Number of Elements" => elements,
         "CPU Time" => cputime,
         "Wall Time" => walltime]
  end

  def displacement_fem
    fem_result(:displacement)
  end

  def stress_fem
    fem_result(:stress)
  end

  # Read the result extracted from the parser submitted with the simulation.
  def fem_result(type)
    jobpath = Pathname.new(job.jobdir)
    result_file = jobpath + "#{prefix}.#{type.to_s}"

    result_file.exist? ? File.foreach(result_file).first.strip.to_f : nil
  end

  # Gets the Paraview generated WebGL file - returns empty string if
  # nonexistant.
  def graphics_file(type=:stress)
    jobpath = Pathname.new(job.jobdir)
    results_dir = jobpath + jobpath.basename
    results_file = lambda { |f| f.exist? ? f : "" }
    if type == :stress
      results_file.call(results_dir + "#{prefix}_stress.html").to_s
    elsif type == :displ
      results_file.call(results_dir + "#{prefix}_displ.html").to_s
    else
      return ""
    end
  end

  def debug_info
    debug_file = Pathname.new(job.jobdir) + "#{prefix}.debug"
    debug_file.exist? ? File.open(debug_file, 'r').read : nil
  end

  private

    # Generate a new name when copying a beam by adding the suffix "-Copy" and
    # an iterator if necessary.
    def generate_duplicate_name
      suffix = "-Copy"
      duplicate_name = name
      duplicate_name += suffix unless name.include? suffix
      iter = 1
      while Beam.where("lower(name) =?", duplicate_name.downcase).first
        duplicate_name.slice!(((0...duplicate_name.length).find_all \
          { |i| duplicate_name[i, suffix.length] == suffix }.last + \
          suffix.length)...(duplicate_name.length))
        duplicate_name += iter.to_s
        iter += 1
      end
      duplicate_name
    end
end
