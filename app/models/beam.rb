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
    jobpath = Pathname.new(jobdir)
    if jobpath.directory?
      jobpath.rmtree
      self.jobdir = ""
      self.status = JOB_STATUS[:u]
    end
  end

  # Calculate the beam's bending moment of inertia.
  def inertia
    width * height**3 / 12
  end

  # Calculate the beam's mass.
  def mass
    length * width * height * density
  end

  # Calculate the beam's weight.
  def weight
    mass * GRAVITY
  end

  # Calculate the beam's flexural stiffness.
  def stiffness
    modulus * inertia
  end

  # Calculate the total force reaction due to load and gravity.
  def r_total
    load + weight
  end

  # Calculate the total moment reaction due to load and gravity.
  def m_total
    -load * length + -weight * length / 2
  end

  # Calculate the beam end angle due to load and gravity.
  def theta
    theta1 = load * length**2 / (2 * stiffness) * 180 / Math::PI
    theta2 = weight * length**2 / (6 * stiffness) * 180 / Math::PI
    theta1 + theta2
  end

  # Calculate to total displacement due to load and gravity.
  def d
    d1 = -load * length**3 / (3 * stiffness)
    d2 = -weight * length**3 / (8 * stiffness)
    d1 + d2
  end

  # Calculate the maximum pricipal stress.
  def sigma_max
    m_total.abs * height / (2 * inertia)
  end

  # Check if the .dat.names file has the 'stress_zz' keyword.
  def stress_results_ok?
    jobpath = Pathname.new(jobdir)
    data_name_file = jobpath + "#{prefix}.dat.names"
    File.foreach(data_name_file).grep(/stress_zz/).any?
  end

  def fem_results
    jobpath = Pathname.new(jobdir)
    data_file = jobpath + "#{prefix}.dat"

    # TODO: Add error checking for file
    results = []
    File.readlines(data_file).map do |line|
      results = line.split.map(&:to_f)
    end

    # TODO: Add error checking for displacement results
    d_fem = results[0].abs

    sigma_fem = 0
    if stress_results_ok?
      probe_y = results[12]
      probe_z = results[13]
      factor = length * height / ((length - probe_z) * (2 * probe_y - height))
      sigma_fem = factor * results[6].abs
    end

    Hash[d_fem: d_fem, sigma_fem: sigma_fem]
  end

  def error
    # TODO: Add error checking for displacement results
    d_error = (-fem_results[:d_fem] - d) / d * 100

    sigma_error = 0
    if stress_results_ok?
      sigma_error = (fem_results[:sigma_fem] - sigma_max) / sigma_max * 100
    end

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
    d_max = d_fem = fem_results[:d_fem]
    d_min = 0.0
    displ_scale = (0.2 * [length, width, height].max / d_fem).abs
    plane_scale = 3.0
    arrow_scale = 0.2 * [length, width, height].max

    if d_max < 0
      d_min = d_max
      d_max = 0.0
    end

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
      f.puts "warpByVector1Display.SetRepresentationType('Wireframe')"

      # set active source
      #f.puts "SetActiveSource(beamvtu)"

      # Create a new 'Warp By Vector' to display deformed geometry.  Geometry comes
      # into into Paraview already displaced.  Subtract 1 from scale to get true
      # scale.
      f.puts "warpByVector2 = WarpByVector(Input=beamvtu)"
      f.puts "warpByVector2.Vectors = ['POINTS', 'displacement']"
      f.puts "warpByVector2.ScaleFactor = #{displ_scale - 1}"
      f.puts "warpByVector2Display = Show(warpByVector2, renderView1)"
      f.puts "Hide(beamvtu, renderView1)"

      # Set up the legend
      f.puts "ColorBy(warpByVector2Display, ('POINTS', 'stress_zz'))"
      f.puts "warpByVector2Display.RescaleTransferFunctionToDataRange(True)"
      f.puts "warpByVector2Display.SetScalarBarVisibility(renderView1, True)"

      # Get and modify the stress color map.
      f.puts "stresszzLUT = GetColorTransferFunction('stresszz')"
      f.puts "stresszzLUT.LockDataRange = 0"
      f.puts "stresszzLUT.InterpretValuesAsCategories = 0"
      f.puts "stresszzLUT.ShowCategoricalColorsinDataRangeOnly = 0"
      f.puts "stresszzLUT.RescaleOnVisibilityChange = 0"
      f.puts "stresszzLUT.EnableOpacityMapping = 0"
      f.puts "stresszzLUT.RGBPoints = [-#{sigma_max}, 0.231373, 0.298039, 0.752941, 0.0, 0.865003, 0.865003, 0.865003, #{sigma_max}, 0.705882, 0.0156863, 0.14902]"
      f.puts "stresszzLUT.UseLogScale = 0"
      f.puts "stresszzLUT.ColorSpace = 'Lab'"
      f.puts "stresszzLUT.UseBelowRangeColor = 0"
      f.puts "stresszzLUT.BelowRangeColor = [0.0, 0.0, 0.0]"
      f.puts "stresszzLUT.UseAboveRangeColor = 0"
      f.puts "stresszzLUT.AboveRangeColor = [1.0, 1.0, 1.0]"
      f.puts "stresszzLUT.NanColor = [1.0, 1.0, 0.0]"
      f.puts "stresszzLUT.Discretize = 1"
      f.puts "stresszzLUT.NumberOfTableValues = 256"
      f.puts "stresszzLUT.ScalarRangeInitialized = 1.0"
      f.puts "stresszzLUT.HSVWrap = 0"
      f.puts "stresszzLUT.VectorComponent = 0"
      f.puts "stresszzLUT.VectorMode = 'Magnitude'"
      f.puts "stresszzLUT.AllowDuplicateScalars = 1"
      f.puts "stresszzLUT.Annotations = []"
      f.puts "stresszzLUT.ActiveAnnotatedValues = []"
      f.puts "stresszzLUT.IndexedColors = []"
      f.puts "stresszzLUT.ApplyPreset('Cool to Warm (Extended)', True)"

      # Get and modify the stress opacity map.
      f.puts "stresszzPWF = GetOpacityTransferFunction('stresszz')"
      f.puts "stresszzPWF.Points = [-#{sigma_max}, 0.0, 0.5, 0.0, #{sigma_max}, 1.0, 0.5, 0.0]"
      f.puts "stresszzPWF.AllowDuplicateScalars = 1"
      f.puts "stresszzPWF.ScalarRangeInitialized = 1"

      # Create a plane to represent the wall bc visually.
      f.puts "plane1 = Plane()"
      f.puts "plane1.Origin = [0.0, 0.0, 0.0]"
      f.puts "plane1.Point1 = [#{width}, 0.0, 0.0]"
      f.puts "plane1.Point2 = [0.0, #{height}, 0.0]"
      f.puts "plane1.XResolution = 1"
      f.puts "plane1.YResolution = 1"

      # Show the plane and modify its properties.
      f.puts "plane1Display = Show(plane1, renderView1)"
      f.puts "plane1Display.Scale = [#{plane_scale}, #{plane_scale}, 1.0]"
      f.puts "plane1Display.Position = [#{(1 - plane_scale) * width / 2}, #{(1 - plane_scale) * height / 2}, 0.0]"
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
      f.puts "arrow1Display.Position = [#{width / 2}, #{height - displ_scale * d_fem}, #{length}]"
      f.puts "arrow1Display.Scale = [#{arrow_scale}, #{arrow_scale}, #{arrow_scale}]"

      # Position the legend on the bottom of the window.
      f.puts "sb = GetScalarBar(stresszzLUT, GetActiveView())"
      f.puts "sb.Orientation = 'Horizontal'"
      f.puts "sb.Position = [0.3, 0.05]"

      # Reset the view to fit data.
      f.puts "renderView1.ResetCamera()"

      # Save the WebGL file.
      f.puts "ExportView(\"#{webgl_stress_file}\", view=renderView1)"

      # set active source
f.puts "SetActiveSource(warpByVector2)"
f.puts "warpByVector2Display.SetScalarBarVisibility(renderView1, False)"
f.puts "Render()"

# set scalar coloring
f.puts "ColorBy(warpByVector2Display, ('POINTS', 'displacement'))"

# rescale color and/or opacity maps used to include current data range
f.puts "warpByVector2Display.RescaleTransferFunctionToDataRange(True)"

# show color bar/color legend
f.puts "warpByVector2Display.SetScalarBarVisibility(renderView1, True)"

# get color transfer function/color map for 'displacement'
f.puts "displacementLUT = GetColorTransferFunction('displacement')"
f.puts "displacementLUT.LockDataRange = 0"
f.puts "displacementLUT.InterpretValuesAsCategories = 0"
f.puts "displacementLUT.ShowCategoricalColorsinDataRangeOnly = 0"
f.puts "displacementLUT.RescaleOnVisibilityChange = 0"
f.puts "displacementLUT.EnableOpacityMapping = 0"
f.puts "displacementLUT.RGBPoints = [#{d_min}, 0.231373, 0.298039, 0.752941, #{(d_max + d_min) / 2}, 0.865003, 0.865003, 0.865003, #{d_max}, 0.705882, 0.0156863, 0.14902]"
f.puts "displacementLUT.UseLogScale = 0"
f.puts "displacementLUT.ColorSpace = 'Diverging'"
f.puts "displacementLUT.UseBelowRangeColor = 0"
f.puts "displacementLUT.BelowRangeColor = [0.0, 0.0, 0.0]"
f.puts "displacementLUT.UseAboveRangeColor = 0"
f.puts "displacementLUT.AboveRangeColor = [1.0, 1.0, 1.0]"
f.puts "displacementLUT.NanColor = [1.0, 1.0, 0.0]"
f.puts "displacementLUT.Discretize = 1"
f.puts "displacementLUT.NumberOfTableValues = 256"
f.puts "displacementLUT.ScalarRangeInitialized = 1.0"
f.puts "displacementLUT.HSVWrap = 0"
f.puts "displacementLUT.VectorComponent = 0"
f.puts "displacementLUT.VectorMode = 'Magnitude'"
f.puts "displacementLUT.AllowDuplicateScalars = 1"
f.puts "displacementLUT.Annotations = []"
f.puts "displacementLUT.ActiveAnnotatedValues = []"
f.puts "displacementLUT.IndexedColors = []"
f.puts "displacementLUT.ApplyPreset('Cool to Warm (Extended)', True)"

# get opacity transfer function/opacity map for 'displacement'
f.puts "displacementPWF = GetOpacityTransferFunction('displacement')"
f.puts "displacementPWF.Points = [#{d_min}, 0.0, 0.5, 0.0, #{d_max}, 1.0, 0.5, 0.0]"
f.puts "displacementPWF.AllowDuplicateScalars = 1"
f.puts "displacementPWF.ScalarRangeInitialized = 1"

# Position the legend on the bottom of the window.
      f.puts "sb = GetScalarBar(displacementLUT, GetActiveView())"
      f.puts "sb.Orientation = 'Horizontal'"
      f.puts "sb.Position = [0.3, 0.05]"

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
