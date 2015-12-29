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
  validates :length_unit,   presence: true
  validates :width_unit,    presence: true
  validates :height_unit,   presence: true
  validates :meshsize_unit, presence: true
  validates :modulus_unit,  presence: true
  validates :density_unit,  presence: true
  validates :load_unit,     presence: true
  validates :status,        presence: true

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

  require 'open3'
  require 'pathname'

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
      file_prefix = prefix
      jobpath = Pathname.new(jobdir)
      result_file = jobpath + jobpath.basename + "#{file_prefix}0001.vtu"
      fem_out = jobpath + "debug/#{file_prefix}.sif.o"

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

  # Formulate a file/directory prefix using the beam's name by removing all
  # spaces and converting to lower case.
  # TODO: Maybe add ID to prefix?  Can then strip name of characters that aren't
  # allowed in GMSH and Elmer, and still ensure some type of uniqueness.
  def prefix
    name.gsub(/\s+/, "").downcase
    # name.gsub(/\W/, "").downcase
  end

  def clean
    if !jobdir.nil?
      jobpath = Pathname.new(jobdir)
      if jobpath.directory?
        jobpath.rmtree
        self.jobdir = ""
        self.status = JOB_STATUS[:u]
      end
    end
  end

  # Calculate the beam's bending moment of inertia.
  def inertia
    convert(:width) * convert(:height)**3 / 12
  end

  # Calculate the beam's mass.
  def mass
    convert(:length) * convert(:width) * convert(:height) * convert(:density)
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
    theta_load = convert(:load) * convert(:length)**2 / (2 * stiffness) * 180 / Math::PI
    theta_grav = weight * convert(:length)**2 / (6 * stiffness) * 180 / Math::PI
    theta_load + theta_grav
  end

  # Calculate to total displacement due to load and gravity.
  def displacement
    d_load = -convert(:load) * convert(:length)**3 / (3 * stiffness)
    d_grav = -weight * convert(:length)**3 / (8 * stiffness)
    d_load + d_grav
  end

  # Calculate the maximum pricipal stress.
  def stress
    moment_reaction.abs * convert(:height) / (2 * inertia)
  end

  # Check if the .dat.names file has the 'stress_zz' keyword.
  def displacement_results_ok?
    jobpath = Pathname.new(jobdir)
    data_name_file = jobpath + "#{prefix}.dat.names"

    if data_name_file.exist?
      File.foreach(data_name_file).grep(/max abs: displacement 2/).any?
    else
      false
    end
  end

  # Check if the .dat.names file has the 'stress_zz' keyword.
  def stress_results_ok?
    jobpath = Pathname.new(jobdir)
    data_name_file = jobpath + "#{prefix}.dat.names"

    if data_name_file.exist?
      File.foreach(data_name_file).grep(/stress_zz/).any?
    else
      false
    end
  end

  # Read the FEM results file and return the data as an array.
  def fem_results
    jobpath = Pathname.new(jobdir)
    data_file = jobpath + "#{prefix}.dat"

    if data_file.exist?
      results = File.readlines(data_file).map { |line| line.split.map(&:to_f) }
      results[0] unless results.empty? | nil
    else
      nil
    end
  end

  # Extract the displacement results from the results file.
  def displacement_fem
    results = fem_results
    (displacement_results_ok? && !results.nil?) ? results[0].abs : nil
  end

  # Extract the stress results from the results file.
  # Stresses are extracted at the beam midpoint due to singularities at the
  # wall and boundary condition effects.  This probed stress is then linearly
  # interpolated to the wall to determine peak stress.
  def stress_fem
    results = fem_results
    if stress_results_ok? && !results.nil?
      probe_y = results[12]
      probe_z = results[13]
      factor = convert(:length) * convert(:height) / \
        ((convert(:length) - probe_z) * (2 * probe_y - convert(:height)))
      factor * results[6].abs
    else
      nil
    end
  end

  # Calcaulte the FEM displacement error as a percentage of theory value.
  # TODO: Remove negative sign - grab unmodified displacement from Elmer.
  def displacement_error
    d = displacement
    (-displacement_fem - d) / d * 100 if (displacement_results_ok? &&
      !displacement_fem.nil?)
  end

  # Calcaulte the FEM stress error as a percentage of theory value.
  def stress_error
    s = stress
    (stress_fem - s) / s * 100 if (stress_results_ok? && !stress_fem.nil?)
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

    l = convert(:length)
    w = convert(:width)
    h = convert(:height)
    ms = convert(:meshsize)
    e = convert(:modulus)
    rho = convert(:density)
    p = convert(:load)

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

          # If cannot find a successful error code, set status to "Failed" and
          # exit.
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

          # If cannot find a successful error code, set status to "Failed" and
          # exit.
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
      f.puts "  Save Coordinates(1,3) = #{(w.to_f / 2).to_s} #{h} "\
        "#{(l.to_f / 2).to_s}"
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
      f.puts "  Stress Bodyforce 2 = $ -#{GRAVITY.to_s} * #{rho}"
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

    # Run Elmer.
    Dir.chdir(scratch_dir) {
      cmd = "/apps/elmer/bin/ElmerSolver #{fem_file} > #{fem_out} 2>&1 &"
      `#{cmd}`
    }

    # Set the status to "Submitted" and save to database.
    self.status = JOB_STATUS[:b]
    self.save
  end

  def generate_results
    # TODO: Give a warning when beam reaches nonlinear territory.
    # TODO: Create a separate PBS job for this.
    # TODO: Create another webgl/html file to displace von Mises and displ.
    # TODO: Implement buttons to choose between principal, von Mises, and displ.
    file_prefix = prefix
    jobpath = Pathname.new(jobdir)
    results_dir = jobpath + jobpath.basename
    result_file = results_dir + "#{file_prefix}0001.vtu"
    pv_script = results_dir + "#{file_prefix}.py"
    webgl_stress_file = results_dir + "#{file_prefix}_stress.webgl"
    webgl_displ_file = results_dir + "#{file_prefix}_displ.webgl"

    d_conv, d_units = displ_units.values
    s_conv, s_units = stress_units.values

    d_fem = displacement_fem
    d_max = displacement / d_conv
    d_min = 0.0
    if d_max < 0
      d_min = d_max
      d_max = 0.0
    end

    s_max = stress / s_conv

    l = convert(:length)
    w = convert(:width)
    h = convert(:height)

    displ_scale = (0.2 * [l, w, h].max / d_fem).abs
    plane_scale = 3.0
    arrow_scale = 0.2 * [l, w, h].max

    # Generate the Paraview batch Python file.
    File.open(pv_script, 'w') do |f|
      #### import the simple module from the paraview
      f.puts "from paraview.simple import *"
      #### disable automatic camera reset on 'Show'
      f.puts "paraview.simple._DisableFirstRenderCameraReset()"

      # Import the deformed beam geometry and data
      f.puts "beamvtu = XMLUnstructuredGridReader(FileName=[\"#{result_file}\"])"
      f.puts "beamvtu.CellArrayStatus = ['GeometryIds']"
      f.puts "beamvtu.PointArrayStatus = ['stress_xx', 'stress_yy', 'stress_zz', 'stress_xy', 'stress_yz', 'stress_xz', 'vonmises', 'displacement']"

      # get active view
      f.puts "renderView1 = GetActiveViewOrCreate('RenderView')"

      # Create a new 'Warp By Vector' to display undeformed mesh.  Geometry comes
      # into into Paraview already displaced.  Set scale factor to -1.0 to back
      # out undeformed geometry.
      f.puts "warpByVector1 = WarpByVector(Input=beamvtu)"
      f.puts "warpByVector1.Vectors = ['POINTS', 'displacement']"
      f.puts "warpByVector1.ScaleFactor = -1.0"
      f.puts "warpByVector1Display = Show(warpByVector1, renderView1)"
      f.puts "warpByVector1Display.ColorArrayName = [None, '']"
      f.puts "warpByVector1Display.ScalarOpacityUnitDistance = 0.04268484912825877"
      f.puts "warpByVector1Display.SetRepresentationType('Wireframe')"

      # Create a new 'Warp By Vector' to display deformed geometry.  Geometry comes
      # into into Paraview already displaced.  Subtract 1 from scale to get true
      # scale.
      f.puts "warpByVector2 = WarpByVector(Input=beamvtu)"
      f.puts "warpByVector2.Vectors = ['POINTS', 'displacement']"
      f.puts "warpByVector2.ScaleFactor = #{displ_scale - 1}"
      f.puts "warpByVector2Display = Show(warpByVector2, renderView1)"
      f.puts "warpByVector2Display.ColorArrayName = [None, '']"
      f.puts "warpByVector2Display.ScalarOpacityUnitDistance = 0.04268484912825877"
      f.puts "Hide(beamvtu, renderView1)"

      # Create a new 'Calculator' to scale results to specified units.
      f.puts "calculator1 = Calculator(Input=warpByVector2)"

      # Scale stress results using the calculator.
      f.puts "calculator1.ResultArrayName = 'stress_zz (#{s_units})'"
      f.puts "calculator1.Function = 'stress_zz/#{s_conv}'"

      # Get and modify the stress color map.
      f.puts "stresszz#{s_units}LUT = GetColorTransferFunction('stresszz#{s_units}')"
      f.puts "stresszz#{s_units}LUT.RGBPoints = [-#{s_max}, 0.231373, 0.298039, 0.752941, 0.0, 0.865003, 0.865003, 0.865003, #{s_max}, 0.705882, 0.0156863, 0.14902]"
      f.puts "stresszz#{s_units}LUT.ScalarRangeInitialized = 1.0"
      f.puts "stresszz#{s_units}LUT.ApplyPreset('Cool to Warm (Extended)', True)"

      # Show the calculated results on the warped geometry
      f.puts "calculator1Display = Show(calculator1, renderView1)"
      f.puts "calculator1Display.ColorArrayName = ['POINTS', 'stress_zz (#{s_units})']"
      f.puts "calculator1Display.LookupTable = stresszz#{s_units}LUT"
      f.puts "calculator1Display.ScalarOpacityUnitDistance = 0.044238274071335064"
      f.puts "Hide(warpByVector2, renderView1)"

      # Set up and show the legend.
      f.puts "calculator1Display.SetScalarBarVisibility(renderView1, True)"
      f.puts "stresszz#{s_units}LUT.RescaleTransferFunction(-#{s_max}, #{s_max})"

      # Get and modify the stress opacity map.
      f.puts "stresszz#{s_units}PWF = GetOpacityTransferFunction('stresszz#{s_units}')"
      f.puts "stresszz#{s_units}PWF.Points = [-#{s_max}, 0.0, 0.5, 0.0, #{s_max}, 1.0, 0.5, 0.0]"
      f.puts "stresszz#{s_units}PWF.ScalarRangeInitialized = 1"
      f.puts "stresszz#{s_units}PWF.RescaleTransferFunction(-#{s_max}, #{s_max})"

      # Create a plane to represent the wall bc visually.
      f.puts "plane1 = Plane()"
      f.puts "plane1.Origin = [0.0, 0.0, 0.0]"
      f.puts "plane1.Point1 = [#{w}, 0.0, 0.0]"
      f.puts "plane1.Point2 = [0.0, #{h}, 0.0]"
      f.puts "plane1.XResolution = 1"
      f.puts "plane1.YResolution = 1"

      # Show the plane and modify its properties.
      f.puts "plane1Display = Show(plane1, renderView1)"
      f.puts "plane1Display.Scale = [#{plane_scale}, #{plane_scale}, 1.0]"
      f.puts "plane1Display.Position = [#{(1 - plane_scale) * w / 2}, #{(1 - plane_scale) * h / 2}, 0.0]"
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
      f.puts "arrow1Display.Position = [#{w / 2}, #{h - displ_scale * d_fem}, #{l}]"
      f.puts "arrow1Display.Scale = [#{arrow_scale}, #{arrow_scale}, #{arrow_scale}]"

      # Position the legend on the bottom of the window.
      f.puts "sb = GetScalarBar(stresszz#{s_units}LUT, GetActiveView())"
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
      f.puts "calculator1.ResultArrayName = 'displacement_Y (#{d_units})'"
      f.puts "calculator1.Function = 'displacement_Y/#{d_conv}'"

      # Set the scalar coloring.
      f.puts "ColorBy(calculator1Display, ('POINTS', 'displacement_Y (#{d_units})'))"

      # Now reshow the legend.
      f.puts "calculator1Display.SetScalarBarVisibility(renderView1, True)"

      # Get the color transfer function for vertical displacement.
      f.puts "displacementY#{d_units}LUT = GetColorTransferFunction('displacementY#{d_units}')"
      f.puts "displacementY#{d_units}LUT.RGBPoints = [#{d_min}, 0.231373, 0.298039, 0.752941, #{(d_max + d_min) / 2}, 0.865003, 0.865003, 0.865003, #{d_max}, 0.705882, 0.0156863, 0.14902]"
      f.puts "displacementY#{d_units}LUT.ScalarRangeInitialized = 1.0"
      f.puts "displacementY#{d_units}LUT.ApplyPreset('Cool to Warm (Extended)', True)"

      # Get the opacity transfer function for vertical displacement.
      f.puts "displacementY#{d_units}PWF = GetOpacityTransferFunction('displacementY#{d_units}')"
      f.puts "displacementY#{d_units}PWF.Points = [#{d_min}, 0.0, 0.5, 0.0, #{d_max}, 1.0, 0.5, 0.0]"
      f.puts "displacementY#{d_units}PWF.ScalarRangeInitialized = 1"

      # Position the legend on the bottom of the window.
      f.puts "sb = GetScalarBar(displacementY#{d_units}LUT, GetActiveView())"
      f.puts "sb.Orientation = 'Horizontal'"
      f.puts "sb.Position = [0.3, 0.05]"
      f.puts "sb.ComponentTitle = ''"

      # Reset the view to fit data.
      f.puts "renderView1.ResetCamera()"

      # Save the WebGL file.
      f.puts "ExportView(\"#{webgl_displ_file}\", view=renderView1)"

    end

    # Run Python Paraview.
    Dir.chdir(results_dir) {
      cmd = "/usr/bin/pvpython #{pv_script}" # > #{fem_out} 2>&1"
      `#{cmd}`
    }
  end

  # Gets the Paraview generated WebGL file - returns empty string if nonexistant.
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
end
