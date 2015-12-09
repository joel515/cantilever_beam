class Beam < ActiveRecord::Base
  validates :name,     presence: true, uniqueness: { case_sensitive: false }
  validates :length,   presence: true, numericality: { greater_than: 0 }
  validates :width,    presence: true, numericality: { greater_than: 0 }
  validates :height,   presence: true, numericality: { greater_than: 0 }
  validates :meshsize, presence: true, numericality: { greater_than: 0 }
  validates :modulus,  presence: true, numericality: { greater_than: 0 }
  validates :poisson,  presence: true,
                       numericality: { greater_than_or_equal_to: -1,
                                       less_than_or_equal_to: 0.5 }
  validates :density,  presence: true, numericality: { greater_than: 0 }
  validates :material, presence: true
  validates :load,     presence: true,
                       numericality: { greater_than_or_equal_to: 0 }

  attr_accessor :inertia
  attr_accessor :mass
  attr_accessor :weight
  attr_accessor :stiffness
  attr_accessor :theta1
  attr_accessor :d1
  attr_accessor :r_load
  attr_accessor :m_load
  attr_accessor :theta2
  attr_accessor :d2
  attr_accessor :r_grav
  attr_accessor :m_grav
  attr_accessor :theta
  attr_accessor :d
  attr_accessor :r_total
  attr_accessor :m_total
  attr_accessor :sigma_max
  attr_accessor :fem_results
  attr_accessor :d_fem
  attr_accessor :probe_y
  attr_accessor :probe_z
  attr_accessor :factor
  attr_accessor :sigma_fem
  attr_accessor :d_error
  attr_accessor :sigma_error

  def submit
    require "open3"

    #Open3.popen2e("mkdir ~/Scratch/#{name.gsub(/\s+/, "")}")
    file_prefix = name.gsub(/\s+/, "").downcase
    geom_file = "#{file_prefix}.geo"
    mesh_file = "#{file_prefix}.msh"
    fem_file = "#{file_prefix}.sif"
    result_file = "#{file_prefix}.vtu"
    output_file = "#{file_prefix}.result"
    data_file = "#{file_prefix}.dat"
    gravity = 9.81
    layers = (length / meshsize).to_i.to_s

    # Generate the geometry file and mesh params for GMSH.
    File.open(geom_file, 'w') do |f|
      f.puts "Point(1) = {0, 0, 0, #{meshsize}};"
      f.puts "Point(2) = {#{width}, 0, 0, #{meshsize}};"
      f.puts "Point(3) = {#{width}, #{height}, 0, #{meshsize}};"
      f.puts "Point(4) = {0, #{height}, 0, #{meshsize}};"
      f.puts "Line(1) = {1, 2};"
      f.puts "Line(2) = {2, 3};"
      f.puts "Line(3) = {3, 4};"
      f.puts "Line(4) = {4, 1};"
      f.puts "Line Loop(5) = {3, 4, 1, 2};"
      f.puts "Plane Surface(6) = {5};"
      f.puts "Extrude {0, 0, #{length}} {"
      f.puts "  Surface{6}; Layers{#{layers}}; Recombine;"
      f.puts "}"
      f.puts "Surface Loop(29) = {19, 6, 15, 28, 23, 27};"
      f.puts "Volume(30) = {29};"
      f.puts "Transfinite Line \"*\" = 10;"
      f.puts "Transfinite Surface \"*\";"
      f.puts "Recombine Surface \"*\";"
      f.puts "Transfinite Volume \"*\";"
    end

    # Run GMSH and hex mesh the beam.
    Open3.popen2e("/apps/gmsh/gmsh-2.11.0-Linux/bin/gmsh #{geom_file} -3") do |i, oe, t|
      puts "pid #{t.pid}"
      oe.each do |line|
        puts line
        if line.downcase.include? "error"
          Process.kill("KILL", t.pid)
        end
      end
      puts t.value
    end

    # Run ElmerGrid to convert mesh to Elmer format.
    Open3.popen2e("/apps/elmer/bin/ElmerGrid 14 2 #{mesh_file} -autoclean") do |i, oe, t|
      puts "pid #{t.pid}"
      oe.each do |line|
        puts line
      end
      puts t.value
    end

    # Generate the Elmer input deck.
    File.open(fem_file, 'w') do |f|
      f.puts "Header"
      f.puts "  CHECK KEYWORDS Warn"
      f.puts "  Mesh DB \".\" \"#{file_prefix}\""
      f.puts "  Include Path \"\""
      f.puts "  Results Directory \"\""
      f.puts "End"
      f.puts ""
      f.puts "Simulation"
      f.puts "  Max Output Level = 5"
      f.puts "  Coordinate System = Cartesian"
      f.puts "  Coordinate Mapping(3) = 1 2 3"
      f.puts "  Simulation Type = Steady state"
      f.puts "  Steady State Max Iterations = 1"
      f.puts "  Output Intervals = 1"
      f.puts "  Timestepping Method = BDF"
      f.puts "  BDF Order = 1"
      f.puts "  Solver Input File = #{fem_file}"
      f.puts "  Output File = #{output_file}"
      f.puts "  Post File = #{result_file}"
      f.puts "End"
      f.puts ""
      f.puts "Constants"
      f.puts "  Gravity(4) = 0 -1 0 #{gravity.to_s}"
      f.puts "  Stefan Boltzmann = 5.67e-08"
      f.puts "  Permittivity of Vacuum = 8.8542e-12"
      f.puts "  Boltzmann Constant = 1.3807e-23"
      f.puts "  Unit Charge = 1.602e-19"
      f.puts "End"
      f.puts ""
      f.puts "Body 1"
      f.puts "  Target Bodies(1) = 1"
      f.puts "  Name = \"Body 1\""
      f.puts "  Equation = 1"
      f.puts "  Material = 1"
      f.puts "  Body Force = 1"
      f.puts "End"
      f.puts ""
      f.puts "Solver 1"
      f.puts "  Equation = Linear elasticity"
      f.puts "  Procedure = \"StressSolve\" \"StressSolver\""
      f.puts "  Variable = -dofs 3 Displacement"
      f.puts "  Exec Solver = Always"
      f.puts "  Stabilize = True"
      f.puts "  Bubbles = False"
      f.puts "  Lumped Mass Matrix = False"
      f.puts "  Optimize Bandwidth = True"
      f.puts "  Steady State Convergence Tolerance = 1.0e-5"
      f.puts "  Nonlinear System Convergence Tolerance = 1.0e-7"
      f.puts "  Nonlinear System Max Iterations = 1"
      f.puts "  Nonlinear System Newton After Iterations = 3"
      f.puts "  Nonlinear System Newton After Tolerance = 1.0e-3"
      f.puts "  Nonlinear System Relaxation Factor = 1"
      f.puts "  Linear System Solver = Direct"
      f.puts "  Linear System Direct Method = MUMPS"
      f.puts "End"
      f.puts ""
      f.puts "Solver 2"
      f.puts "  Equation = SaveScalars"
      f.puts "  Exec Solver = After Timestep"
      f.puts "  Procedure = File \"SaveData\" \"SaveScalars\""
      f.puts "  Filename = #{file_prefix}.dat"
      f.puts "  File Append = False"
      f.puts "  Variable 1 = Displacement 2"
      f.puts "  Operator 1 = max abs"
      f.puts "  Save Coordinates(1,3) = #{(width.to_f / 2).to_s} #{height}
                  #{(length.to_f / 2).to_s}"
      f.puts "End"
      f.puts ""
      f.puts "Equation 1"
      f.puts "  Name = \"Equation 1\""
      f.puts "  Calculate Stresses = True"
      f.puts "  Active Solvers(1) = 1"
      f.puts "End"
      f.puts ""
      f.puts "Material 1"
      f.puts "  Name = \"#{material}\""
      f.puts "  Youngs modulus = #{modulus}"
      f.puts "  Density = #{density}"
      f.puts "  Poisson ratio = #{poisson}"
      f.puts "End"
      f.puts ""
      f.puts "Body Force 1"
      f.puts "  Name = \"Gravity\""
      f.puts "  Stress Bodyforce 2 = $ -#{gravity.to_s} * #{density}"
      f.puts "End"
      f.puts ""
      f.puts "Boundary Condition 1"
      f.puts "  Target Boundaries(1) = 1"
      f.puts "  Name = \"Wall\""
      f.puts "  Displacement 3 = 0"
      f.puts "  Displacement 2 = 0"
      f.puts "  Displacement 1 = 0"
      f.puts "End"
      f.puts ""
      f.puts "Boundary Condition 2"
      f.puts "  Target Boundaries(1) = 6"
      f.puts "  Name = \"Mass\""
      f.puts "  Force 2 = $ -#{load} / #{width} / #{height}"
      f.puts "End"
    end

    # Run Elmer.
    Open3.popen2e("/apps/elmer/bin/ElmerSolver #{fem_file}") do |i, oe, t|
      puts "pid #{t.pid}"
      oe.each do |line|
        puts line
      end
      puts t.value
    end

    # Calculate beam properties.
    self.inertia = width * height**3 / 12
    self.mass = length * width * height * density
    self.weight = mass * gravity
    self.stiffness = modulus * inertia

    # Calculate end-load results only.
    self.theta1 = load * length**2 / (2 * stiffness) * 180 / Math::PI
    self.d1 = -load * length**3 / (3 * stiffness)
    self.r_load = load
    self.m_load = -load * length

    # Calculate results due to gravity only (distributed load).
    self.theta2 = weight * length**2 / (6 * stiffness) * 180 / Math::PI
    self.d2 = -weight * length**3 / (8 * stiffness)
    self.r_grav = weight
    self.m_grav = -weight * length / 2

    # Calculate the totals.
    self.theta = theta1 + theta2
    self.d = (d1 + d2) * 1000
    self.r_total = r_load + r_grav
    self.m_total = m_load + m_grav

    # Calculate stresses.
    self.sigma_max = m_total.abs * height / (2000000 * inertia)

    # Get FEA results.
    self.fem_results = []
    File.readlines(data_file).map do |line|
      self.fem_results = line.split.map(&:to_f)
    end

    self.d_fem = fem_results[0].abs * -1000
    self.probe_y = fem_results[12]
    self.probe_z = fem_results[13]
    self.factor = length * height / (2 * probe_z * (probe_y - height / 2))
    self.sigma_fem = factor * fem_results[6].abs / 1000000

    self.d_error = (d_fem - d) / d * 100
    self.sigma_error = (sigma_fem - sigma_max) / sigma_max * 100
  end
end
