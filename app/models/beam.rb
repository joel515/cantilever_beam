class Beam < ActiveRecord::Base
  validates :name,     presence: true, uniqueness: { case_sensitive: false }
  # TODO: Check name with a regex for parentheses.
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

  require 'open3'
  require 'pathname'

  JOB_STATUS = {
    u: "Unsubmitted",
    e: "Exiting",
    h: "Held",
    q: "Queued",
    r: "Running",
    t: "Moving",
    w: "Waiting",
    s: "Suspended",
    c: "Completed",
    f: "Failed",
    b: "Submitted"
  }

  GRAVITY = 9.81

  def running?
    [JOB_STATUS[:e], JOB_STATUS[:r]].include? status
  end

  def completed?
    [JOB_STATUS[:c]].include? status
  end

  def active?
    [JOB_STATUS[:h], JOB_STATUS[:q],
     JOB_STATUS[:t], JOB_STATUS[:w], JOB_STATUS[:b]].include? status
  end

  def failed?
    [JOB_STATUS[:s], JOB_STATUS[:f]].include? status
  end

  def ready?
    [JOB_STATUS[:u]].include? status
  end

  def ready
    self.status = JOB_STATUS[:u]
    self.save
  end

  def submitted?
    [JOB_STATUS[:b]].include? status
  end

  def check_status
    # Temporary implementation hack until PBS/Torque is implemented.
    if jobdir.nil? || jobdir.empty?
      if submitted? || active? || running?
          self.status = JOB_STATUS[:f]
      else
        status
      end
    else
      jobpath = Pathname.new(jobdir)
      result_file = jobpath + jobpath.basename + "#{prefix}0001.vtu"
      fem_out = jobpath + "debug/#{prefix}.sif.o"

      if !jobpath.directory?
        if submitted? || active? || running?
          self.status = JOB_STATUS[:f]
        else
          self.status = JOB_STATUS[:u]
        end
        self.save
        status
      elsif submitted? || running?
        if result_file.exist?
          self.status = JOB_STATUS[:c]
        elsif fem_out.exist?
          if fem_out.read.include?("Error:")
            self.status = JOB_STATUS[:f]
          else
            self.status = JOB_STATUS[:r]
          end
        else
          self.status = JOB_STATUS[:r]
        end
        self.save
        status
      else
        status
      end
    end
  end

  def prefix
    name.gsub(/\s+/, "").downcase
  end

  def clean
    jobpath = Pathname.new(jobdir)
    if jobpath.directory?
      jobpath.rmtree
      self.jobdir = ""
      self.status = JOB_STATUS[:u]
    end
  end

  def inertia
    width * height**3 / 12
  end

  def mass
    length * width * height * density
  end

  def weight
    mass * GRAVITY
  end

  def stiffness
    modulus * inertia
  end

  def r_total
    load + weight
  end

  def m_total
    -load * length + -weight * length / 2
  end

  def theta
    theta1 = load * length**2 / (2 * stiffness) * 180 / Math::PI
    theta2 = weight * length**2 / (6 * stiffness) * 180 / Math::PI
    theta1 + theta2
  end

  def d
    d1 = -load * length**3 / (3 * stiffness)
    d2 = -weight * length**3 / (8 * stiffness)
    (d1 + d2) * 1000
  end

  def sigma_max
    sig = m_total.abs * height / (2000000 * inertia)
    puts sig
    sig
  end

  def fem_results
    jobpath = Pathname.new(jobdir)
    data_file = jobpath + "#{prefix}.dat"

    results = []
    File.readlines(data_file).map do |line|
      results = line.split.map(&:to_f)
    end

    d_fem = results[0].abs * -1000
    probe_y = results[12]
    probe_z = results[13]
    #factor = length * height / (2 * probe_z * (probe_y - height / 2))
    factor = length * height / ((length - probe_z) * (2 * probe_y - height))
    sigma_fem = factor * results[6].abs / 1000000

    Hash[d_fem: d_fem, sigma_fem: sigma_fem]
  end

  def error
    d_error = (fem_results[:d_fem] - d) / d * 100
    sigma_error = (fem_results[:sigma_fem] - sigma_max) / sigma_max * 100

    Hash[d_error: d_error, sigma_error: sigma_error]
  end

  def submit
    file_prefix = prefix
    home_dir = Dir.home()
    self.jobdir = "#{home_dir}/Scratch/#{file_prefix}"
    scratch_dir = Pathname.new(jobdir)
    Dir.mkdir(scratch_dir) unless scratch_dir.directory?
    debug_dir = scratch_dir + "debug"
    Dir.mkdir(debug_dir) unless debug_dir.directory?
    geom_file = scratch_dir + "#{file_prefix}.geo"
    mesh_file = scratch_dir + "#{file_prefix}.msh"
    fem_file = scratch_dir + "#{file_prefix}.sif"
    geom_out = debug_dir + "#{file_prefix}.geo.o"
    mesh_out = debug_dir + "#{file_prefix}.msh.o"
    fem_out = debug_dir + "#{file_prefix}.sif.o"
    result_file = "#{file_prefix}.vtu"
    output_file = "#{file_prefix}.result"

    numels_l = (length / meshsize).to_i
    if numels_l.odd?
      numels_l += 1
    end
    numnodes_h = (height / meshsize).to_i + 1
    numnodes_w = (width / meshsize).to_i
    if numnodes_w.even?
      numnodes_w += 1
    end

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
      f.puts "  Surface{6}; Layers{#{numels_l}}; Recombine;"
      f.puts "}"
      f.puts "Surface Loop(29) = {19, 6, 15, 28, 23, 27};"
      f.puts "Volume(30) = {29};"
      f.puts "Transfinite Line {1, 3} = #{numnodes_w};"
      f.puts "Transfinite Line {2, 4} = #{numnodes_h};"
      f.puts "Transfinite Surface \"*\";"
      f.puts "Recombine Surface \"*\";"
      f.puts "Transfinite Volume \"*\";"
    end

    # Run GMSH and hex mesh the beam.
    Dir.chdir(scratch_dir) {
      Open3.popen2e("/apps/gmsh/gmsh-2.11.0-Linux/bin/gmsh #{geom_file} -3") do |i, oe, t|
        File.open(geom_out, 'w') do |f|
          f.puts "pid #{t.pid}"
          oe.each do |line|
            f.puts line
            if line.downcase.include? "error"
              Process.kill("KILL", t.pid)
            end
          end
          f.puts t.value

          if t.value.to_s.split[-1].to_i != 0
            self.status = JOB_STATUS[:f]
            self.save
            return
          end
        end
      end
    }

    # Run ElmerGrid to convert mesh to Elmer format.
    Dir.chdir(scratch_dir) {
      Open3.popen2e("/apps/elmer/bin/ElmerGrid 14 2 #{mesh_file} -autoclean") do |i, oe, t|
        File.open(mesh_out, 'w') do |f|
          f.puts "pid #{t.pid}"
          oe.each do |line|
            f.puts line
          end
          f.puts t.value

          if t.value.to_s.split[-1].to_i != 0
            self.status = JOB_STATUS[:f]
            self.save
            return
          end
        end
      end
    }

    # Generate the Elmer input deck.
    File.open(fem_file, 'w') do |f|
      f.puts "Header"
      f.puts "  CHECK KEYWORDS Warn"
      f.puts "  Mesh DB \"#{scratch_dir}\" \"#{file_prefix}\""
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
      f.puts "  Gravity(4) = 0 -1 0 #{GRAVITY.to_s}"
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
      f.puts "  Save Coordinates(1,3) = #{(width.to_f / 2).to_s} #{height} "\
        "#{(length.to_f / 2).to_s}"
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
      f.puts "  Stress Bodyforce 2 = $ -#{GRAVITY.to_s} * #{density}"
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
    Dir.chdir(scratch_dir) {
      cmd = "/apps/elmer/bin/ElmerSolver #{fem_file} > #{fem_out} 2>&1 &"
      `#{cmd}`
    }

    self.status = JOB_STATUS[:b]
    self.save
  end
end
