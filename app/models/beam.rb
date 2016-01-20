class Beam < ActiveRecord::Base
  before_destroy :delete_staging_directories
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
  validates :density,  presence: true,
                       numericality: { greater_than_or_equal_to: 0 }
  validates :material, presence: true
  validates :load,     presence: true,
                       numericality: { greater_than_or_equal_to: 0 }
  validates :length_unit,        presence: true
  validates :width_unit,         presence: true
  validates :height_unit,        presence: true
  validates :meshsize_unit,      presence: true
  validates :modulus_unit,       presence: true
  validates :density_unit,       presence: true
  validates :load_unit,          presence: true
  validates :status,             presence: true
  validates :result_unit_system, presence: true
  validates :cores, presence: true,
                    numericality: { only_integer: true,
                                    greater_than_or_equal_to: 1,
                                    less_than_or_equal_to: 16 }

  SERVER = `hostname`.strip.to_sym

  case SERVER
  when :khaleesi
    GMSH_EXE =        "/apps/gmsh/gmsh-2.11.0-Linux/bin/gmsh"
    ELMERGRID_EXE =   "/apps/elmer/bin/ElmerGrid"
    ELMERSOLVER_EXE = "/apps/elmer/bin/ElmerSolver"
    PARAVIEW_EXE =    "/apps/paraview/bin/pvbatch"
    USE_MUMPS = true
    WITH_PBS =  false
  when :login
    GMSH_EXE =        "/gpfs/apps/gmsh/gmsh-2.8.5-Linux/bin/gmsh"
    # ELMERGRID_EXE =   "/gpfs/apps/elmer/bin/ElmerGrid"
    # ELMERSOLVER_EXE = "/gpfs/apps/elmer/bin/ElmerSolver"
    ELMERGRID_EXE = "/gpfs/admin/setup/elmer/old/install-old/bin/ElmerGrid"
    ELMERSOLVER_EXE = "/gpfs/admin/setup/elmer/old/install-old/bin/ElmerSolver"
    PARAVIEW_EXE =    "/gpfs/home/jkopp/apps/paraview/4.4.0/bin/pvbatch"
    USE_MUMPS = false
    WITH_PBS =  true
  else
    GMSH_EXE =        "gmsh"
    ELMERGRID_EXE =   "ElmerGrid"
    ELMERSOLVER_EXE = "ElmerSolver"
    PARAVIEW_EXE =    "pvbatch"
    USE_MUMPS = false
    WITH_PBS =  false
  end

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
    b: "Submitted",
    m: "Terminated",
    k: "Unknown"
  }

  GRAVITY = 9.80665

  DIMENSIONAL_UNITS = {
    m:  { convert: 1,      text: "m" },
    mm: { convert: 0.001,  text: "mm" },
    cm: { convert: 0.01,   text: "cm" },
    in: { convert: 0.0254, text: "in" },
    ft: { convert: 0.3048, text: "ft" }
  }
  FORCE_UNITS = {
    n:   { convert: 1,                    text: "N" },
    kn:  { convert: 1000,                 text: "kN" },
    kgf: { convert: Beam::GRAVITY,        text: "kgf" },
    lbf: { convert: 4.448221615255,       text: "lbf" },
    kip: { convert: 4448.221615255,       text: "kip" }
  }
  STRESS_UNITS = {
    pa:  { convert: 1,              text: "Pa" },
    kpa: { convert: 1e3,            text: "kPa" },
    mpa: { convert: 1e6,            text: "MPa" },
    gpa: { convert: 1e9,            text: "GPa" },
    psi: { convert: 6894.757293178, text: "psi" },
    ksi: { convert: 6894757.293178, text: "ksi" }
  }
  DENSITY_UNITS = {
    kgm3:     { convert: 1,            text: "kg/m&sup3;".html_safe },
    tonnemm3: { convert: 1e12,         text: "tonne/mm&sup3;".html_safe },
    gcm3:     { convert: 1000,         text: "gm/cm&sup3;".html_safe },
    gm3:      { convert: 0.001,        text: "gm/m&sup3;".html_safe },
    lbin3:    { convert: 27679.90471019, text: "lb/in&sup3;".html_safe },
    lbft3:    { convert: 16.01846337395, text: "lb/ft&sup3;".html_safe }
  }
  INERTIA_UNITS = {
    m4:  { convert: 1,         text: "m<sup>4</sup>".html_safe },
    mm4: { convert: 0.001**4,  text: "mm<sup>4</sup>".html_safe },
    in4: { convert: 0.0254**4, text: "in<sup>4</sup>".html_safe }
  }
  MASS_UNITS = {
    kg:  { convert: 1,           text: "kg" },
    lbm: { convert: 1 / 2.20462, text: "lbm" }
  }
  TORQUE_UNITS = {
    nm:   { convert: 1,                       text: "N-m" },
    nmm:  { convert: 0.001,                   text: "N-mm" },
    inlb: { convert: 4.448221615255 * 0.0254, text: "in-lbf" },
    ftlb: { convert: 4.448221615255 * 0.3048, text: "ft-lbf" }
  }
  UNIT_DESIGNATION = {
    name:     nil,
    length:   DIMENSIONAL_UNITS,
    width:    DIMENSIONAL_UNITS,
    height:   DIMENSIONAL_UNITS,
    meshsize: DIMENSIONAL_UNITS,
    modulus:  STRESS_UNITS,
    poisson:  nil,
    density:  DENSITY_UNITS,
    material: nil,
    load:     FORCE_UNITS,
    inertia:  INERTIA_UNITS,
    mass:     MASS_UNITS,
    torque:   TORQUE_UNITS
  }
  RESULT_UNITS = {
    metric_mpa:   { displacement:     DIMENSIONAL_UNITS[:mm],
                    displacement_fem: DIMENSIONAL_UNITS[:mm],
                    stress:           STRESS_UNITS[:mpa],
                    stress_fem:       STRESS_UNITS[:mpa],
                    force_reaction:   FORCE_UNITS[:n],
                    inertia:          INERTIA_UNITS[:mm4],
                    mass:             MASS_UNITS[:kg],
                    moment_reaction:  TORQUE_UNITS[:nmm],
                    text:             "Metric (MPa)" },
    metric_pa:    { displacement:     DIMENSIONAL_UNITS[:m],
                    displacement_fem: DIMENSIONAL_UNITS[:m],
                    stress:           STRESS_UNITS[:pa],
                    stress_fem:       STRESS_UNITS[:pa],
                    force_reaction:   FORCE_UNITS[:n],
                    inertia:          INERTIA_UNITS[:m4],
                    mass:             MASS_UNITS[:kg],
                    moment_reaction:  TORQUE_UNITS[:nm],
                    text:             "Metric (Pa)" },
    imperial_psi: { displacement:     DIMENSIONAL_UNITS[:in],
                    displacement_fem: DIMENSIONAL_UNITS[:in],
                    stress:           STRESS_UNITS[:psi],
                    stress_fem:       STRESS_UNITS[:psi],
                    force_reaction:   FORCE_UNITS[:lbf],
                    inertia:          INERTIA_UNITS[:in4],
                    mass:             MASS_UNITS[:lbm],
                    moment_reaction:  TORQUE_UNITS[:inlb],
                    text:             "Imperial (psi)" },
    imperial_ksi: { displacement:     DIMENSIONAL_UNITS[:in],
                    displacement_fem: DIMENSIONAL_UNITS[:in],
                    stress:           STRESS_UNITS[:ksi],
                    stress_fem:       STRESS_UNITS[:ksi],
                    force_reaction:   FORCE_UNITS[:kip],
                    inertia:          INERTIA_UNITS[:in4],
                    mass:             MASS_UNITS[:lbm],
                    moment_reaction:  TORQUE_UNITS[:ftlb],
                    text:             "Imperial (ksi)" }
  }

  validates_inclusion_of :length_unit,   in: DIMENSIONAL_UNITS.keys.map(&:to_s)
  validates_inclusion_of :width_unit,    in: DIMENSIONAL_UNITS.keys.map(&:to_s)
  validates_inclusion_of :height_unit,   in: DIMENSIONAL_UNITS.keys.map(&:to_s)
  validates_inclusion_of :meshsize_unit, in: DIMENSIONAL_UNITS.keys.map(&:to_s)
  validates_inclusion_of :modulus_unit,  in: STRESS_UNITS.keys.map(&:to_s)
  validates_inclusion_of :density_unit,  in: DENSITY_UNITS.keys.map(&:to_s)
  validates_inclusion_of :load_unit,     in: FORCE_UNITS.keys.map(&:to_s)
  validates_inclusion_of :status,        in: JOB_STATUS.values

  require 'pathname'
  require 'nokogiri'

  # Job status queries.
  def running?
    [JOB_STATUS[:r]].include? status
  end

  def completed?(state = status)
    [JOB_STATUS[:c]].include? state
  end

  def active?
    [JOB_STATUS[:h], JOB_STATUS[:q], JOB_STATUS[:s], JOB_STATUS[:e],
     JOB_STATUS[:t], JOB_STATUS[:w], JOB_STATUS[:b]].include? status
  end

  def failed?
    [JOB_STATUS[:f], JOB_STATUS[:k], JOB_STATUS[:m]].include? status
  end

  def ready?
    [JOB_STATUS[:u]].include? status
  end

  def ready
    self.jobid = nil
    self.jobdir = nil
    set_status! :u
  end

  def submitted?
    [JOB_STATUS[:b]].include? status
  end

  def terminated?
    [JOB_STATUS[:m], JOB_STATUS[:e]].include? status
  end

  def destroyable?
    !active? & !running?
  end

  def cleanable?
    !active? & !running? & !ready?
  end

  def terminatable?
    active? | running?
  end

  def editable?
    !active? & !running?
  end

  # Formulate a file/directory prefix using the beam's name by removing all
  # spaces and converting to lower case.
  # TODO: Maybe add ID to prefix?  Can then strip name of characters that aren't
  # allowed in GMSH and Elmer, and still ensure some type of uniqueness.
  def prefix
    name.gsub(/\s+/, "").downcase
    # name.gsub(/\W/, "").downcase
  end

  # Submit the job.  Use qsub if using PBS scheduler.  Otherwise run the bash
  # script.  If the latter, capture the group id from the process spawned.
  def submit
    self.jobdir = create_staging_directories
    geom_file = generate_geometry_file
    input_deck = generate_input_deck
    results_script = generate_results_script
    parse_script = generate_parse_script
    generate_start_file(input_deck: input_deck) if use_mpi?

    if !geom_file.nil? && !input_deck.nil? && !results_script.nil? \
      && !parse_script.nil?
      submit_script = generate_submit_script(geom_file:      geom_file,
                                             input_deck:     input_deck,
                                             results_script: results_script,
                                             parse_script:   parse_script)

      if !submit_script.nil?
        Dir.chdir(jobdir) {
          cmd =  "#{WITH_PBS ? 'qsub' : 'bash'} #{prefix}.sh"
          cmd += " > #{prefix}.out 2>&1 &" unless WITH_PBS
          self.jobid = WITH_PBS ? `#{cmd}` : Process.spawn(cmd, pgroup: true)
        }
      end
    end

    # If successful, set the status to "Submitted" and save to database.
    unless jobid.nil? || jobid.empty?
      self.jobid = jobid.strip
      set_status! :b
    else
      self.jobid = nil
      set_status! :f
    end
  end

  # Check the job's status.  Use qstat if submitted via PBS, otherwise check
  # the child PIDs from the submitted group PID.
  def check_status
    return status if jobid.nil?

    pre_status = `#{check_status_command}`
    unless pre_status.nil? || pre_status.empty?
      state = check_process_status(pre_status)
      completed?(state) ? check_completed_status : state
    else
      failed? ? status : check_completed_status
    end
  end

  def set_status(arg)
    if arg.is_a? String
      self.status = JOB_STATUS.has_value?(arg) ? arg : JOB_STATUS[:k]
    elsif arg.is_a? Symbol
      self.status = JOB_STATUS.has_key?(arg) ? JOB_STATUS[arg] : JOB_STATUS[:k]
    else
      self.status = JOB_STATUS[:k]
    end
  end

  def set_status!(arg)
    set_status(arg)
    self.save
  end

  # Kill the job.  If running with scheduler, submit qdel command.  Otherwise,
  # submit a SIGTERM to the process group.
  def kill
    unless jobid.nil?
      WITH_PBS ? `qdel #{jobid}` : Process.kill("TERM", -jobid.to_i)
      set_status! :m
    end
  end

  def unit_text(param, result_units = false)
    if result_units == false
      UNIT_DESIGNATION[param][self.send(param.to_s<<"_unit").to_sym][:text] unless
        UNIT_DESIGNATION[param].nil?
    else
      RESULT_UNITS[result_unit_system.to_sym][param][:text]
    end
  end

  def stress_units
    RESULT_UNITS[result_unit_system.to_sym][:stress]
  end

  def displ_units
    RESULT_UNITS[result_unit_system.to_sym][:displacement]
  end

  def convert(param)
    self.send(param.to_s) * \
      UNIT_DESIGNATION[param][self.send(param.to_s<<"_unit").to_sym][:convert] \
      unless UNIT_DESIGNATION[param].nil?
  end

  def unconvert(param)
    self.send(param.to_s) / \
      RESULT_UNITS[result_unit_system.to_sym][param][:convert]
  end

  # Calculate the beam's bending moment of inertia.
  def inertia
    convert(:width) * convert(:height)**3 / 12
  end

  # Calculate the beam's cross-sectional area.
  def area
    convert(:width) * convert(:height)
  end

  # Calculate the beam's mass.
  def mass
    convert(:length) * area * convert(:density)
  end

  # Calculate the beam's weight.
  def weight
    mass * GRAVITY
  end

  # Calculate the beam's flexural stiffness.
  def stiffness
    convert(:modulus) * inertia
  end

  # Calculate the total force reaction due to load and gravity.
  def force_reaction
    convert(:load) + weight
  end

  # Calculate the total moment reaction due to load and gravity.
  def moment_reaction
    -convert(:load) * convert(:length) + -weight * convert(:length) / 2
  end

  # Calculate the beam end angle due to load and gravity.
  def theta
    p = convert(:load)
    l = convert(:length)
    ei = stiffness
    w = weight

    theta_load = p * l**2 / (2 * ei) * 180 / Math::PI
    theta_grav = w * l**2 / (6 * ei) * 180 / Math::PI
    theta_load + theta_grav
  end

  # Calculate the shear modulus of the material based on the elastic modulus
  # and Poisson's ratio.
  def shear_modulus
    convert(:modulus) / (2 * (1 + poisson))
  end

  # Calculate to total displacement due to load and gravity using Timoshenko
  # theory.
  def displacement
    p = convert(:load)
    l = convert(:length)
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
    moment_reaction.abs * convert(:height) / (2 * inertia)
  end

  # Capture the FEA stats and return the data as a hash.
  def fem_stats
    jobpath = Pathname.new(jobdir)
    std_out = jobpath + (WITH_PBS ? "#{prefix}.o#{jobid.split('.')[0]}" :
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
    jobpath = Pathname.new(jobdir)
    result_file = jobpath + "#{prefix}.#{type.to_s}"

    result_file.exist? ? File.foreach(result_file).first.strip.to_f : nil
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

  # Gets the Paraview generated WebGL file - returns empty string if
  # nonexistant.
  def graphics_file(type=:stress)
    jobpath = Pathname.new(jobdir)
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

  def delete_staging_directories
    if !jobdir.nil?
      jobpath = Pathname.new(jobdir)
      if jobpath.directory?
        jobpath.rmtree
      end
    end
  end

  def debug_info
    debug_file = Pathname.new(jobdir) + "#{prefix}.debug"
    debug_file.exist? ? File.open(debug_file, 'r').read : nil
  end

    private

    def use_mpi?
      cores > 1
    end

    # Create the following directories as job staging in the user's home.
    # $HOME/Scratch/<beam name>
    # TODO: Add error checking if directories cannot be created.
    def create_staging_directories
      homedir = Pathname.new(Dir.home())
      return nil unless homedir.directory?

      scratchdir = homedir + "Scratch"
      Dir.mkdir(scratchdir) unless scratchdir.directory?
      stagedir = scratchdir + prefix
      Dir.mkdir(stagedir) unless stagedir.directory?
      resultdir = stagedir + prefix
      Dir.mkdir(resultdir) unless resultdir.directory?
      stagedir.to_s
    end

    # Write the file used to generate and mesh geometry.  This particular app
    # uses open source GMSH.
    def generate_geometry_file
      geom_file = Pathname.new(jobdir) + "#{prefix}.geo"

      l = convert(:length)
      w = convert(:width)
      h = convert(:height)
      ms = convert(:meshsize)

      numels_l = (l / ms).to_i
      if numels_l.odd?
        numels_l += 1
      end
      numnodes_h = (h / ms).to_i + 1
      numnodes_w = (w / ms).to_i
      if numnodes_w.even?
        numnodes_w += 1
      end

      # Generate the geometry file and mesh params for GMSH.
      File.open(geom_file, 'w') do |f|
        f.puts "Point(1) = {0, 0, 0, #{ms}};"
        f.puts "Point(2) = {#{w}, 0, 0, #{ms}};"
        f.puts "Point(3) = {#{w}, #{h}, 0, #{ms}};"
        f.puts "Point(4) = {0, #{h}, 0, #{ms}};"
        f.puts "Line(1) = {1, 2};"
        f.puts "Line(2) = {2, 3};"
        f.puts "Line(3) = {3, 4};"
        f.puts "Line(4) = {4, 1};"
        f.puts "Line Loop(5) = {3, 4, 1, 2};"
        f.puts "Plane Surface(6) = {5};"
        f.puts "Extrude {0, 0, #{l}} {"
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

      geom_file.exist? ? geom_file : nil
    end

    # Write the input deck utilizing the previously generated mesh.  The input
    # deck is generated for and solved using Elmer, and open source FEA
    # package.  (Note: Elmer was build using MUMPS for direct solving.  If not
    # using MUMPS, comment out the appropriate line below.)
    def generate_input_deck
      input_deck = Pathname.new(jobdir) + "#{prefix}.sif"
      result_file = "#{prefix}.vtu"
      output_file = "#{prefix}.result"

      w = convert(:width)
      h = convert(:height)
      e = convert(:modulus)
      rho = convert(:density)
      p = convert(:load)

      # Generate the Elmer input deck.
      File.open(input_deck, 'w') do |f|
        f.puts "Header"
        f.puts "  CHECK KEYWORDS Warn"
        f.puts "  Mesh DB \"#{jobdir}\" \"#{prefix}\""
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
        f.puts "  Solver Input File = #{input_deck}"
        f.puts "  Output File = #{output_file}"
        f.puts "  Post File = #{result_file}"
        f.puts "End"
        f.puts ""
        f.puts "Constants"
        f.puts "  Gravity(4) = 0 -1 0 #{Beam::GRAVITY}"
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
        f.puts "  Linear System Solver = Direct" if USE_MUMPS
        f.puts "  Linear System Direct Method = MUMPS" if USE_MUMPS
        f.puts "  Parallel Reduce = Logical True" if use_mpi?
        f.puts "End"
        f.puts ""
        f.puts "Solver 2"
        f.puts "  Equation = SaveScalars"
        f.puts "  Exec Solver = After Timestep"
        f.puts "  Procedure = File \"SaveData\" \"SaveScalars\""
        f.puts "  Filename = #{prefix}.dat"
        f.puts "  File Append = False"
        f.puts "  Variable 1 = Displacement 2"
        f.puts "  Operator 1 = max"
        f.puts "  Operator 2 = min"
        f.puts "  Parallel Reduce = Logical True" if use_mpi?
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
        f.puts "  Youngs modulus = #{e}"
        f.puts "  Density = #{rho}"
        f.puts "  Poisson ratio = #{poisson}"
        f.puts "End"
        f.puts ""
        f.puts "Body Force 1"
        f.puts "  Name = \"Gravity\""
        f.puts "  Stress Bodyforce 2 = $ -#{Beam::GRAVITY} * #{rho}"
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
        f.puts "  Force 2 = $ -#{p} / #{w} / #{h}"
        f.puts "End"
      end

      input_deck.exist? ? input_deck : nil
    end

    # Write the Python script used to generate visual contoured plots for
    # post-processing using open source Paraview.  The script creates a plane
    # to represent the wall on one side, and an arrow to represent the load.
    # (Note: Paraview must be built using OSMesa in order to render on the
    # cluster off screen.)
    def generate_results_script
      # TODO: Give a warning when beam reaches nonlinear territory.
      # TODO: At some point create a second job to generate results.  Then FEA
      #       results can be used for scaling.
      jobpath = Pathname.new(jobdir)
      results_dir = jobpath + jobpath.basename
      results_file = use_mpi? ? results_dir + "#{prefix}0001.pvtu" :
        results_dir + "#{prefix}0001.vtu"
      paraview_script = results_dir + "#{prefix}.py"
      webgl_stress_file = results_dir + "#{prefix}_stress.webgl"
      webgl_displ_file = results_dir + "#{prefix}_displ.webgl"

      displ_conversion, displ_units =
        Beam::RESULT_UNITS[result_unit_system.to_sym][:displacement].values
      stress_conversion, stress_units =
        Beam::RESULT_UNITS[result_unit_system.to_sym][:stress].values

      # TODO: Add error checking for displacement and stress values.
      displ_max = displacement / displ_conversion
      displ_max_abs = displacement.abs
      displ_min = 0.0
      if displ_max < 0
        displ_min = displ_max
        displ_max = 0.0
      end

      stress_max = stress / stress_conversion

      l = convert(:length)
      w = convert(:width)
      h = convert(:height)

      # This is a hack.  Need to scale everything for very small dimensions.
      # When exporting a WebGL file in Paraview the z buffer becomes small when
      # fully zoomed (this should be a bug).  Geometry is bisected or not
      # visible at all. Increasing the scale increases the z buffer.  Other
      # option is to zoom out, but geometry will then be small.
      view_scale = 1 / [l, w, h].max

      # TODO: Use FEA displacement results for scale.

      displ_scale = (0.2 * [l, w, h].max / displ_max_abs).abs
      plane_scale = 3.0
      arrow_scale = 0.2 * [l, w, h].max

      # Generate the Paraview batch Python file.
      File.open(paraview_script, 'w') do |f|
        #### import the simple module from the paraview
        f.puts "from paraview.simple import *"
        #### disable automatic camera reset on 'Show'
        f.puts "paraview.simple._DisableFirstRenderCameraReset()"

        # Import the deformed beam geometry and data
        f.puts "beamvtu = " \
          "XML#{'Partitioned' if use_mpi?}UnstructuredGridReader(FileName=" \
          "[\"#{results_file}\"])"
        f.puts "beamvtu.CellArrayStatus = ['GeometryIds']"
        f.puts "beamvtu.PointArrayStatus = ['stress_xx', 'stress_yy', " \
          "'stress_zz', 'stress_xy', 'stress_yz', 'stress_xz', 'vonmises', " \
          "'displacement']"

        # Get active view
        f.puts "renderView1 = GetActiveViewOrCreate('RenderView')"

        # If we ran parallel, the partition ends will show up unless we set the
        # geometry id thresholds to exclude them.
        if use_mpi?
          f.puts "threshold1 = Threshold(Input=beamvtu)"
          f.puts "threshold1.Scalars = ['CELLS', 'GeometryIds']"
          f.puts "threshold1.ThresholdRange = [100.0, 102.0]"
        end

        # Create a new 'Warp By Vector' to display undeformed mesh.  Geometry
        # comes into into Paraview already displaced.  Set scale factor to -1.0
        # to back out undeformed geometry.
        f.puts "warpByVector1 = WarpByVector(Input=" \
          "#{use_mpi? ? 'threshold1' : 'beamvtu'})"
        f.puts "warpByVector1.Vectors = ['POINTS', 'displacement']"
        f.puts "warpByVector1.ScaleFactor = -1.0"
        f.puts "warpByVector1Display = Show(warpByVector1, renderView1)"
        f.puts "warpByVector1Display.ColorArrayName = [None, '']"
        f.puts "warpByVector1Display.ScalarOpacityUnitDistance = " \
          "0.04268484912825877"
        f.puts "warpByVector1Display.SetRepresentationType('Wireframe')"
        f.puts "warpByVector1Display.Scale = [#{view_scale}, #{view_scale}, "\
          "#{view_scale}]"

        # Create a new 'Warp By Vector' to display deformed geometry.  Geometry
        # comes into into Paraview already displaced.  Subtract 1 from scale to
        # get true scale.
        f.puts "warpByVector2 = WarpByVector(Input=" \
          "#{use_mpi? ? 'threshold1' : 'beamvtu'})"
        f.puts "warpByVector2.Vectors = ['POINTS', 'displacement']"
        f.puts "warpByVector2.ScaleFactor = #{displ_scale - 1}"
        f.puts "warpByVector2Display = Show(warpByVector2, renderView1)"
        f.puts "warpByVector2Display.ColorArrayName = [None, '']"
        f.puts "warpByVector2Display.ScalarOpacityUnitDistance = " \
          "0.04268484912825877"
        f.puts "Hide(beamvtu, renderView1)"
        f.puts "Hide(threshold1, renderView1)" if use_mpi?

        # Create a new 'Calculator' to scale results to specified units.
        f.puts "calculator1 = Calculator(Input=warpByVector2)"

        # Scale stress results using the calculator.
        f.puts "calculator1.ResultArrayName = 'stress_zz (#{stress_units})'"
        f.puts "calculator1.Function = 'stress_zz/#{stress_conversion}'"

        # Get and modify the stress color map.
        f.puts "stresszz#{stress_units}LUT = " \
          "GetColorTransferFunction('stresszz#{stress_units}')"
        f.puts "stresszz#{stress_units}LUT.RGBPoints = [-#{stress_max}, " \
          "0.231373, 0.298039, 0.752941, 0.0, 0.865003, 0.865003, 0.865003, " \
          "#{stress_max}, 0.705882, 0.0156863, 0.14902]"
        f.puts "stresszz#{stress_units}LUT.ScalarRangeInitialized = 1.0"
        # f.puts "stresszz#{stress_units}LUT.ApplyPreset('Cool to Warm " \
        #   "(Extended)', True)"
        f.puts "stresszz#{stress_units}LUT.ApplyPreset('jet', True)"
        f.puts "stresszz#{stress_units}LUT.NumberOfTableValues = 8"

        # Show the calculated results on the warped geometry
        f.puts "calculator1Display = Show(calculator1, renderView1)"
        f.puts "calculator1Display.ColorArrayName = ['POINTS', 'stress_zz " \
          "(#{stress_units})']"
        f.puts "calculator1Display.LookupTable = stresszz#{stress_units}LUT"
        f.puts "calculator1Display.ScalarOpacityUnitDistance = " \
          "0.044238274071335064"
        f.puts "calculator1Display.Scale = [#{view_scale}, #{view_scale}, "\
          "#{view_scale}]"
        f.puts "Hide(warpByVector2, renderView1)"

        # Set up and show the legend.
        f.puts "calculator1Display.SetScalarBarVisibility(renderView1, True)"
        # f.puts "stresszz#{stress_units}LUT.RescaleTransferFunction" \
        #   "(-#{stress_max}, #{stress_max})"
        f.puts "stresszz#{stress_units}LUT.RescaleTransferFunction" \
          "(0.0, #{stress_max})"

        # Get and modify the stress opacity map.
        f.puts "stresszz#{stress_units}PWF = " \
          "GetOpacityTransferFunction('stresszz#{stress_units}')"
        # f.puts "stresszz#{stress_units}PWF.Points = [-#{stress_max}, 0.0, " \
        #   "0.5, 0.0, #{stress_max}, 1.0, 0.5, 0.0]"
        f.puts "stresszz#{stress_units}PWF.Points = [0.0, 0.0, " \
          "0.5, 0.0, #{stress_max}, 1.0, 0.5, 0.0]"
        f.puts "stresszz#{stress_units}PWF.ScalarRangeInitialized = 1"
        f.puts "stresszz#{stress_units}PWF.RescaleTransferFunction" \
          "(-#{stress_max}, #{stress_max})"

        # Create a plane to represent the wall bc visually.
        f.puts "plane1 = Plane()"
        f.puts "plane1.Origin = [0.0, 0.0, 0.0]"
        f.puts "plane1.Point1 = [#{w}, 0.0, 0.0]"
        f.puts "plane1.Point2 = [0.0, #{h}, 0.0]"
        f.puts "plane1.XResolution = 1"
        f.puts "plane1.YResolution = 1"

        # Show the plane and modify its properties.
        f.puts "plane1Display = Show(plane1, renderView1)"
        f.puts "plane1Display.Scale = [#{plane_scale * view_scale}, " \
          "#{plane_scale * view_scale}, 1.0]"
        f.puts "plane1Display.Position = " \
          "[#{(1 - plane_scale) * w * view_scale / 2}, " \
          "#{(1 - plane_scale) * h * view_scale / 2}, 0.0]"
        f.puts "plane1Display.DiffuseColor = [0.0, 0.0, 0.682]"

        # Create an arrow to represent the load visually.
        f.puts "arrow1 = Arrow()"
        f.puts "arrow1.TipResolution = 50"
        f.puts "arrow1.TipRadius = 0.1"
        f.puts "arrow1.TipLength = 0.35"
        f.puts "arrow1.ShaftResolution = 50"
        f.puts "arrow1.ShaftRadius = 0.03"
        f.puts "arrow1.Invert = 1"

        # Show the arrow and modify its properties.
        f.puts "arrow1Display = Show(arrow1, renderView1)"
        f.puts "arrow1Display.DiffuseColor = [1.0, 0.0, 0.0]"
        f.puts "arrow1Display.Orientation = [0.0, 0.0, 90.0]"
        # TODO: Use FEA displacement results for scale.
        f.puts "arrow1Display.Position = [#{w * view_scale / 2}, " \
          "#{(h - displ_scale * displ_max_abs) * view_scale}, " \
          "#{l * view_scale}]"
        f.puts "arrow1Display.Scale = [#{arrow_scale * view_scale}, " \
          "#{arrow_scale * view_scale}, #{arrow_scale * view_scale}]"

        # Position the legend on the bottom of the window.
        f.puts "sb = GetScalarBar(stresszz#{stress_units}LUT, GetActiveView())"
        f.puts "sb.Orientation = 'Horizontal'"
        f.puts "sb.Position = [0.3, 0.05]"

        # Reset the view to fit data.
        f.puts "renderView1.ResetCamera()"

        # Save the WebGL file.
        f.puts "ExportView(\"#{webgl_stress_file}\", view=renderView1)"

        # Set the active source and turn the legend off (hack to correctly show
        # the displacement legend).
        f.puts "SetActiveSource(calculator1)"
        f.puts "calculator1Display.SetScalarBarVisibility(renderView1, False)"
        f.puts "Render()"

        # Modify the calculator to scale displacement.
        f.puts "calculator1.ResultArrayName = 'displacement_Y " \
          "(#{displ_units})'"
        f.puts "calculator1.Function = 'displacement_Y/#{displ_conversion}'"

        # Set the scalar coloring.
        f.puts "ColorBy(calculator1Display, ('POINTS', 'displacement_Y " \
          "(#{displ_units})'))"

        # Now reshow the legend.
        f.puts "calculator1Display.SetScalarBarVisibility(renderView1, True)"

        # Get the color transfer function for vertical displacement.
        f.puts "displacementY#{displ_units}LUT = " \
          "GetColorTransferFunction('displacementY#{displ_units}')"
        f.puts "displacementY#{displ_units}LUT.RGBPoints = [#{displ_min}, " \
          "0.231373, 0.298039, 0.752941, #{(displ_max + displ_min) / 2}, " \
          "0.865003, 0.865003, 0.865003, #{displ_max}, 0.705882, 0.0156863, " \
          "0.14902]"
        f.puts "displacementY#{displ_units}LUT.ScalarRangeInitialized = 1.0"
        # f.puts "displacementY#{displ_units}LUT.ApplyPreset('Cool to Warm " \
        #   "(Extended)', True)"
        f.puts "displacementY#{displ_units}LUT.ApplyPreset('jet', True)"
        f.puts "displacementY#{displ_units}LUT.NumberOfTableValues = 8"

        # Get the opacity transfer function for vertical displacement.
        f.puts "displacementY#{displ_units}PWF = " \
          "GetOpacityTransferFunction('displacementY#{displ_units}')"
        f.puts "displacementY#{displ_units}PWF.Points = [#{displ_min}, 0.0, " \
          "0.5, 0.0, #{displ_max}, 1.0, 0.5, 0.0]"
        f.puts "displacementY#{displ_units}PWF.ScalarRangeInitialized = 1"

        # Position the legend on the bottom of the window.
        f.puts "sb = GetScalarBar(displacementY#{displ_units}LUT, " \
          "GetActiveView())"
        f.puts "sb.Orientation = 'Horizontal'"
        f.puts "sb.Position = [0.3, 0.05]"
        f.puts "sb.ComponentTitle = ''"

        # Reset the view to fit data.
        f.puts "renderView1.ResetCamera()"

        # Save the WebGL file.
        f.puts "ExportView(\"#{webgl_displ_file}\", view=renderView1)"
      end

      paraview_script.exist? ? paraview_script : nil
    end

    # Generate a parse script to extract results to be run after the simulation
    # is completed.
    # Displacement - The first entry in the dat file is maximum y displacement,
    # the second is minimum.  Return the greater of the two absolute values.
    # Stress - Stresses are extracted at 3 element lengths from the wall to
    # avoid singularities near the boundary condition.  This probed stress is
    # then linearly interpolated to the wall to determine peak stress.
    def generate_parse_script
      jobpath = Pathname.new(jobdir)
      parse_script = jobpath + "#{prefix}.rb"
      result_file = jobpath + jobpath.basename + "#{prefix}.result"
      stress_file = jobpath + "#{prefix}.stress"
      displacement_file = jobpath + "#{prefix}.displacement"
      debug_file = jobpath + "#{prefix}.debug" if Rails.env.development?
      l = convert(:length)
      w = convert(:width)
      h = convert(:height)
      targetx = w / 2
      targety = h
      targetz = l * convert(:meshsize) * 3

      File.open(parse_script, 'w') do |f|
        f.puts "#!#{`which ruby`}"
        f.puts "stress = nil"
        f.puts "dSum = #{[l, w, h].max}"
        f.puts "x, y, z = nil, nil, nil"
        f.puts "fileid = nil" if use_mpi?
        f.puts "nodeloc = nil"
        if use_mpi?
          f.puts "(1..#{cores}).each do |i|"
          f.puts "  node_file_name = \"#{(jobpath + jobpath.basename).to_s + \
            '/partitioning.' + cores.to_s + '/part.#{i}.nodes'}\""
        else
          f.puts "  node_file_name = \"#{jobpath + jobpath.basename +
            'mesh.nodes'}\""
        end
        f.puts "  if File.exist?(node_file_name)"
        f.puts "    File.foreach(node_file_name) do |line|"
        f.puts "      node = line.split"
        f.puts "      dSumNew = (node[2].to_f - #{targetx}).abs + " \
          "(node[3].to_f - #{targety}).abs + "
        f.puts "        (node[4].to_f - #{targetz}).abs"
        f.puts "      if dSumNew < dSum"
        f.puts "        fileid = i-1" if use_mpi?
        f.puts "        nodeloc = $."
        f.puts "        x = node[2].to_f"
        f.puts "        y = node[3].to_f"
        f.puts "        z = node[4].to_f"
        f.puts "        dSum = dSumNew"
        f.puts "      end"
        f.puts "    end"
        f.puts "  end"
        f.puts "end" if use_mpi?
        f.puts ""
        f.puts "result_file_name = #{'!fileid.nil? && ' * use_mpi?.to_i}" \
          "!nodeloc.nil? && !y.nil? && !z.nil? ?"
        f.puts "  \"#{result_file}#{use_mpi? ? '.#{fileid}' : ''}\" : nil"
        f.puts ""
        f.puts "if !result_file_name.nil? && File.exist?(result_file_name)"
        f.puts "  startparseloc = nil"
        f.puts "  File.foreach(result_file_name) do |line|"
        f.puts "    if line.strip == \"stress_zz\""
        f.puts "      startparseloc = $."
        f.puts "      break"
        f.puts "    end"
        f.puts "  end"
        f.puts ""
        f.puts "  if !startparseloc.nil?"
        f.puts "    stressloc = startparseloc + nodeloc + 1"
        f.puts "    result_file = File.open result_file_name"
        f.puts "    stressloc.times { result_file.gets }"
        f.puts "    factor = #{l} * #{h} / ((#{l} - z) * (2 * y - #{h}))"
        f.puts "    stress = $_.strip.to_f * factor"
        f.puts "    result_file.close"
        f.puts "  end"
        f.puts "end"
        f.puts ""
        f.puts "File.open(\"#{stress_file}\", 'w') { |f|"
        f.puts "  f.puts stress"
        f.puts "} if !stress.nil?"
        f.puts ""
        f.puts "dat_names_file_name = \"#{(jobpath + prefix).to_s +
          '.dat.names'}\""
        f.puts "dat_file_name = \"#{(jobpath + prefix).to_s + '.dat'}\""
        f.puts "displacement = nil"
        f.puts "if File.exist?(dat_names_file_name) && File.exist?" \
          "(dat_file_name)"
        f.puts "  if File.foreach(dat_names_file_name).grep(/1: max: " \
          "displacement 2/).any? &&"
        f.puts "      File.foreach(dat_names_file_name).grep(/2: min: " \
          "displacement 2/).any?"
        f.puts "    File.foreach(dat_file_name) do |line|"
        f.puts "      data = line.strip.split.map(&:to_f)"
        f.puts "      displacement = data[0].abs > data[1].abs ? data[0] : " \
          "data[1] unless"
        f.puts "        data.empty?"
        f.puts "    end"
        f.puts "  end"
        f.puts "end"
        f.puts ""
        f.puts "File.open(\"#{displacement_file}\", 'w') { |f|"
        f.puts "  f.puts displacement"
        f.puts "} if !displacement.nil?"

        if Rails.env.development?
          f.puts "File.open(\"#{debug_file}\", 'w') do |f|"
          f.puts "  f.puts \"File ID: #{'#{fileid}'}\"" if use_mpi?
          f.puts "  f.puts \"Node Location: #{'#{nodeloc}'}\""
          f.puts "  f.puts \"x: #{'#{x}'}\""
          f.puts "  f.puts \"y: #{'#{y}'}\""
          f.puts "  f.puts \"z: #{'#{z}'}\""
          f.puts "  f.puts \"Displacement: #{'#{displacement}'}\""
          f.puts "  f.puts \"Stress Location: #{'#{stressloc}'}\""
          f.puts "  f.puts \"Factor: #{'#{factor}'}\""
          f.puts "  f.puts \"Probed Stress: #{'#{factor != 0 ? stress /
            factor : nil}'}\""
          f.puts "  f.puts \"Calculated Stress: #{'#{stress}'}\""
          f.puts "end"
        end
      end

      parse_script.exist? ? parse_script : nil
    end

    def generate_start_file(args)
      jobpath = Pathname.new(jobdir)
      start_file = jobpath + "ELMERSOLVER_STARTINFO"
      input_deck = Pathname.new(args[:input_deck]).basename
      File.open(start_file, 'w') do |f|
        f.puts input_deck.to_s
        f.puts cores.to_s
      end
    end

    # Write the Bash script used to submit the job to the cluster.  The job
    # first generates the geometry and mesh using GMSH, converts the mesh to
    # Elmer format using ElmerGrid, solves using ElmerSolver, then creates
    # 3D visualization plots of the results using Paraview (batch).
    def generate_submit_script(args)
      jobpath = Pathname.new(jobdir)
      geom_file = Pathname.new(args[:geom_file]).basename
      mesh_file = "#{geom_file.basename(geom_file.extname)}.msh"
      input_deck = Pathname.new(args[:input_deck]).basename
      results_script = Pathname.new(args[:results_script]).basename
      parse_script = Pathname.new(args[:parse_script]).basename
      submit_script = jobpath + "#{prefix}.sh"
      File.open(submit_script, 'w') do |f|
        f.puts "#!#{`which bash`.strip}"

        if WITH_PBS
          f.puts "#PBS -N #{prefix}"
          f.puts "#PBS -l nodes=1:ppn=#{cores}"
          f.puts "#PBS -j oe"
          f.puts "module load elmer"
          f.puts "cd $PBS_O_WORKDIR"
        else
          f.puts "cd #{jobpath}"
        end

        f.puts "#{GMSH_EXE} #{geom_file} -3"
        f.puts "#{ELMERGRID_EXE} 14 2 #{mesh_file} " +
          ("-metis #{cores} 0 " * use_mpi?.to_i) + "-autoclean"
        f.puts "#{`which mpirun`.strip} -np #{cores} " * use_mpi?.to_i +
          "#{ELMERSOLVER_EXE} #{input_deck.to_s * (1 - use_mpi?.to_i)}".strip
        f.puts "#{`which ruby`.strip} #{parse_script}"

        if WITH_PBS
          f.puts "cd $PBS_O_WORKDIR/#{prefix}"
        else
          f.puts "cd #{jobpath + prefix}"
        end

        f.puts "#{PARAVIEW_EXE} #{results_script}"
      end

      submit_script.exist? ? submit_script : nil
    end

    def check_process_status(pre_status)
      if WITH_PBS
        JOB_STATUS[Nokogiri::XML(pre_status).xpath( \
          '//Data/Job/job_state').children.first.content.downcase.to_sym] \
          || JOB_STATUS[:k]
      else
        pids = pre_status.split("\n").count
        if pids == 1
          JOB_STATUS[:c]
        elsif pids > 1
          JOB_STATUS[:r]
        else
          JOB_STATUS[:k]
        end
      end
    end

    def check_status_command
      WITH_PBS ? "qstat #{jobid} -x" : "pgrep -g #{jobid}"
    end

    def check_completed_status
      jobpath = Pathname.new(jobdir)
      result_file = jobpath + jobpath.basename +
        (use_mpi? ? "#{prefix}0001.pvtu" : "#{prefix}0001.vtu")
      std_out = jobpath + (WITH_PBS ? "#{prefix}.o#{jobid.split('.')[0]}" :
        "#{prefix}.out")

      if std_out.exist?
        if File.foreach(std_out).enum_for(:grep, /error|fail/i).first.nil?
          result_file.exist? ? JOB_STATUS[:c] : JOB_STATUS[:f]
        else
          JOB_STATUS[:f]
        end
      else
        JOB_STATUS[:f]
      end
    end
end
