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
                       numericality: { greater_than_or_eqaul_to: 0 }
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

  SERVER = :khaleesi

  case SERVER
  when :khaleesi
    GMSH_EXE =        "/apps/gmsh/gmsh-2.11.0-Linux/bin/gmsh"
    ELMERGRID_EXE =   "/apps/elmer/bin/ElmerGrid"
    ELMERSOLVER_EXE = "/apps/elmer/bin/ElmerSolver"
    PARAVIEW_EXE =    "/apps/paraview/bin/pvbatch"
    USE_MUMPS = true
    WITH_PBS =  false
  when :raptor
    GMSH_EXE =        "/gpfs/admin/setup/gmsh/gmsh-2.8.5-Linux/bin/gmsh"
    ELMERGRID_EXE =   "/gpfs/admin/setup/elmer/old/install-old/bin/ElmerGrid"
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

  require 'open3'
  require 'pathname'
  require 'nokogiri'

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

  # Formulate a file/directory prefix using the beam's name by removing all
  # spaces and converting to lower case.
  # TODO: Maybe add ID to prefix?  Can then strip name of characters that aren't
  # allowed in GMSH and Elmer, and still ensure some type of uniqueness.
  def prefix
    name.gsub(/\s+/, "").downcase
    # name.gsub(/\W/, "").downcase
  end

  def submit
    create_staging_directories
    generate_geometry_file
    generate_input_deck
    generate_results_script
    generate_submit_script

    # Submit to cluster via PBS.
    Dir.chdir(jobdir) {
      cmd = "#{WITH_PBS ? 'qsub' : 'bash'} #{prefix}.sh"
      cmd += " > #{prefix}.out 2>&1 &" if !WITH_PBS
      self.jobid = `#{cmd}`
    }

    # If successful, set the status to "Submitted" and save to database.
    unless jobid.nil?
      self.jobid = jobid.strip
      self.status = JOB_STATUS[:b]
    else
      self.status = JOB_STATUS[:f]
    end
    self.save
  end

  def check_status
    if WITH_PBS
      return JOB_STATUS[:u] if jobid.nil?
      return status if completed?

      xml_status = `qstat #{jobid} -x`
      unless xml_status.nil? || xml_status.empty?
        self.status = JOB_STATUS[Nokogiri::XML(xml_status).xpath( \
          '//Data/Job/job_state').children.first.content.downcase.to_sym] \
          || JOB_STATUS[:k]
      else
        self.status = JOB_STATUS[:k]
      end
      self.save
      status
    else
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
            if !File.foreach(fem_out).enum_for(:grep, /error/i).first.nil?
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
  end

  # Calculate the beam's bending moment of inertia.
  def inertia
    convert(:width) * convert(:height)**3 / 12
  end

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

  # Check if the .dat.names file has the 'stress_zz' keyword.
  def displacement_results_ok?
    jobpath = Pathname.new(jobdir)
    data_name_file = jobpath + "#{prefix}.dat.names"

    if data_name_file.exist?
      File.foreach(data_name_file).grep(/1: max: displacement 2/).any? &&
      File.foreach(data_name_file).grep(/2: min: displacement 2/).any?
    else
      false
    end
  end

  # Check if the .dat.names file has the 'stress_zz' keyword.
  def stress_results_ok?
    jobpath = Pathname.new(jobdir)
    data_name_file = jobpath + "#{prefix}.dat.names"

    if data_name_file.exist?
      File.foreach(data_name_file).grep(/8: value: stress_zz/).any?
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

  # Extract the displacement results from the results file.  The first entry in
  # the dat file is maximum y displacement, the second is minimum.  Return the
  # greater of the two absolute values.
  def displacement_fem
    results = fem_results
    if displacement_results_ok? && !results.nil?
      results[0].abs > results[1].abs ? results[0] : results[1]
    else
      nil
    end
  end

  # Extract the stress results from the results file.
  # Stresses are extracted at the beam midpoint due to singularities at the
  # wall and boundary condition effects.  This probed stress is then linearly
  # interpolated to the wall to determine peak stress.
  def stress_fem
    results = fem_results
    if stress_results_ok? && !results.nil?
      probe_y = results[13]
      probe_z = results[14]
      factor = convert(:length) * convert(:height) / \
        ((convert(:length) - probe_z) * (2 * probe_y - convert(:height)))
      factor * results[7].abs
    else
      nil
    end
  end

  # Calcaulte the FEM displacement error as a percentage of theory value.
  def displacement_error
    d = displacement
    d_fem = displacement_fem
    (d_fem - d) / d * 100 if (displacement_results_ok? && !d_fem.nil?)
  end

  # Calcaulte the FEM stress error as a percentage of theory value.
  def stress_error
    s = stress
    s_fem = stress_fem
    (s_fem - s) / s * 100 if (stress_results_ok? && !s_fem.nil?)
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

  def delete_staging_directories
    if !jobdir.nil?
      jobpath = Pathname.new(jobdir)
      if jobpath.directory?
        jobpath.rmtree
        self.jobdir = nil
        self.jobid = nil
        self.status = JOB_STATUS[:u]
        self.save
      end
    end
  end

    private

    # Create the following directories as job staging in the user's home.
    # $HOME/Scratch/<beam name>
    # TODO: Add error checking if directories cannot be created.
    def create_staging_directories
      homedir = Pathname.new(Dir.home())
      if homedir.directory?
        scratchdir = homedir + "Scratch"
        Dir.mkdir(scratchdir) unless scratchdir.directory?
        stagedir = scratchdir + prefix
        Dir.mkdir(stagedir) unless stagedir.directory?
        resultdir = stagedir + prefix
        Dir.mkdir(resultdir) unless resultdir.directory?
        self.jobdir = stagedir.to_s
      end
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
    end

    # Write the input deck utilizing the previously generated mesh.  The input
    # deck is generated for and solved using Elmer, and open source FEA
    # package.  (Note: Elmer was build using MUMPS for direct solving.  If not
    # using MUMPS, comment out the appropriate line below.)
    def generate_input_deck
      fem_file = Pathname.new(jobdir) + "#{prefix}.sif"
      result_file = "#{prefix}.vtu"
      output_file = "#{prefix}.result"

      l = convert(:length)
      w = convert(:width)
      h = convert(:height)
      e = convert(:modulus)
      rho = convert(:density)
      p = convert(:load)

      # Generate the Elmer input deck.
      File.open(fem_file, 'w') do |f|
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
        f.puts "  Solver Input File = #{fem_file}"
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
        f.puts "  Linear System Solver = Direct"
        f.puts "  Linear System Direct Method = MUMPS" if USE_MUMPS == true
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
        f.puts "  Save Coordinates(1,3) = #{w / 2} #{h} #{l / 2}"
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
    end

    # Write the Python script used to generate visual contoured plots for
    # post-processing using open source Paraview.  The script creates a plane
    # to represent the wall on one side, and an arrow to represent the load.
    # (Note: Paraview must be built using OSMesa in order to render on the
    # cluster off screen.)
    def generate_results_script
      # TODO: Give a warning when beam reaches nonlinear territory.
      # TODO: Create a separate PBS job for this.
      # TODO: At some point create a second job to generate results.  Then FEA
      #       results can be used for scaling.
      jobpath = Pathname.new(jobdir)
      results_dir = jobpath + jobpath.basename
      results_file = results_dir + "#{prefix}0001.vtu"
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
        f.puts "beamvtu = XMLUnstructuredGridReader(FileName=" \
          "[\"#{results_file}\"])"
        f.puts "beamvtu.CellArrayStatus = ['GeometryIds']"
        f.puts "beamvtu.PointArrayStatus = ['stress_xx', 'stress_yy', " \
          "'stress_zz', 'stress_xy', 'stress_yz', 'stress_xz', 'vonmises', " \
          "'displacement']"

        # get active view
        f.puts "renderView1 = GetActiveViewOrCreate('RenderView')"

        # Create a new 'Warp By Vector' to display undeformed mesh.  Geometry
        # comes into into Paraview already displaced.  Set scale factor to -1.0
        # to back out undeformed geometry.
        f.puts "warpByVector1 = WarpByVector(Input=beamvtu)"
        f.puts "warpByVector1.Vectors = ['POINTS', 'displacement']"
        f.puts "warpByVector1.ScaleFactor = -1.0"
        f.puts "warpByVector1Display = Show(warpByVector1, renderView1)"
        f.puts "warpByVector1Display.ColorArrayName = [None, '']"
        f.puts "warpByVector1Display.ScalarOpacityUnitDistance = " \
          "0.04268484912825877"
        f.puts "warpByVector1Display.SetRepresentationType('Wireframe')"

        # Create a new 'Warp By Vector' to display deformed geometry.  Geometry
        # comes into into Paraview already displaced.  Subtract 1 from scale to
        # get true scale.
        f.puts "warpByVector2 = WarpByVector(Input=beamvtu)"
        f.puts "warpByVector2.Vectors = ['POINTS', 'displacement']"
        f.puts "warpByVector2.ScaleFactor = #{displ_scale - 1}"
        f.puts "warpByVector2Display = Show(warpByVector2, renderView1)"
        f.puts "warpByVector2Display.ColorArrayName = [None, '']"
        f.puts "warpByVector2Display.ScalarOpacityUnitDistance = " \
          "0.04268484912825877"
        f.puts "Hide(beamvtu, renderView1)"

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
        f.puts "stresszz#{stress_units}LUT.ApplyPreset('Cool to Warm " \
          "(Extended)', True)"

        # Show the calculated results on the warped geometry
        f.puts "calculator1Display = Show(calculator1, renderView1)"
        f.puts "calculator1Display.ColorArrayName = ['POINTS', 'stress_zz " \
          "(#{stress_units})']"
        f.puts "calculator1Display.LookupTable = stresszz#{stress_units}LUT"
        f.puts "calculator1Display.ScalarOpacityUnitDistance = " \
          "0.044238274071335064"
        f.puts "Hide(warpByVector2, renderView1)"

        # Set up and show the legend.
        f.puts "calculator1Display.SetScalarBarVisibility(renderView1, True)"
        f.puts "stresszz#{stress_units}LUT.RescaleTransferFunction" \
          "(-#{stress_max}, #{stress_max})"

        # Get and modify the stress opacity map.
        f.puts "stresszz#{stress_units}PWF = " \
          "GetOpacityTransferFunction('stresszz#{stress_units}')"
        f.puts "stresszz#{stress_units}PWF.Points = [-#{stress_max}, 0.0, " \
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
        f.puts "plane1Display.Scale = [#{plane_scale}, #{plane_scale}, 1.0]"
        f.puts "plane1Display.Position = [#{(1 - plane_scale) * w / 2}, " \
          "#{(1 - plane_scale) * h / 2}, 0.0]"
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
        f.puts "arrow1Display.Position = [#{w / 2}, " \
          "#{h - displ_scale * displ_max_abs}, #{l}]"
        f.puts "arrow1Display.Scale = [#{arrow_scale}, #{arrow_scale}, " \
          "#{arrow_scale}]"

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
        f.puts "displacementY#{displ_units}LUT.ApplyPreset('Cool to Warm " \
          "(Extended)', True)"

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
    end

    # Write the Bash script used to submit the job to the cluster.  The job
    # first generates the geometry and mesh using GMSH, converts the mesh to
    # Elmer format using ElmerGrid, solves using ElmerSolver, then creates
    # 3D visualization plots of the results using Paraview (batch).
    def generate_submit_script
      jobpath = Pathname.new(jobdir)
      submit_script = jobpath + "#{prefix}.sh"
      File.open(submit_script, 'w') do |f|
        f.puts "#!/bin/bash"

        if WITH_PBS
          f.puts "#PBS -N #{prefix}"
          f.puts "#PBS -l nodes=1:ppn=1"
          f.puts "#PBS -j oe"
          f.puts "cd $PBS_O_WORKDIR"
        else
          f.puts "cd #{jobpath}"
        end

        f.puts "#{GMSH_EXE} #{prefix}.geo -3"
        f.puts "#{ELMERGRID_EXE} 14 2 #{prefix}.msh -autoclean"
        f.puts "#{ELMERSOLVER_EXE} #{prefix}.sif"

        if WITH_PBS
          f.puts "cd $PBS_O_WORKDIR/#{prefix}"
        else
          f.puts "cd #{jobpath + prefix}"
        end

        f.puts "#{PARAVIEW_EXE} #{prefix}.py"
      end
    end
end
