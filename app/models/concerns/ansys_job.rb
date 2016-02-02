module AnsysJob
  extend ActiveSupport::Concern

  case SERVER
  when :khaleesi
    ANSYS_EXE =       "ansys162"
    PARAVIEW_EXE =    "/apps/paraview/bin/pvbatch"
  when :login
    ANSYS_EXE =       "/gpfs/apps/ansys/v162/ansys/bin/ansys162"
    PARAVIEW_EXE =    "/gpfs/home/jkopp/apps/paraview/4.4.0/bin/pvbatch"
  else
    PARAVIEW_EXE =    "pvbatch"
  end

  # Capture the job stats and return the data as a hash.
  def job_stats
    jobpath = Pathname.new(jobdir)
    std_out = jobpath + (WITH_PBS ? "#{prefix}.o#{pid.split('.')[0]}" :
      "#{prefix}.out")

    nodes, elements, cputime, walltime = nil
    if std_out.exist?
      File.foreach(std_out) do |line|
        nodes    = line.split[4] if line.include? "MAXIMUM NODE NUMBER"
        elements = line.split[4] if line.include? "MAXIMUM ELEMENT NUMBER"
        cputime  = "#{line.split[5]} s" if line.include? "CP Time"
        walltime = "#{line.split[5]} s" if line.include? "Elapsed Time"
      end
    end
    Hash["Number of Nodes" => nodes,
         "Number of Elements" => elements,
         "CPU Time" => cputime,
         "Wall Time" => walltime]
  end

  def result_path
    Pathname.new(jobdir)
  end

  private

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
      stagedir.to_s
    end

    # Submit the job.  Use qsub if using PBS scheduler.  Otherwise run the bash
    # script.  If the latter, capture the group id from the process spawned.
    def submit_job
      self.jobdir = create_staging_directories
      input_deck = generate_input_deck
      results_script = generate_results_script

      if !input_deck.nil? && !results_script.nil?
        submit_script = generate_submit_script(input_deck:     input_deck,
                                               results_script: results_script)

        if !submit_script.nil?
          Dir.chdir(jobdir) {
            cmd =  "#{WITH_PBS ? 'qsub' : 'bash'} #{prefix}.sh"
            cmd += " > #{prefix}.out 2>&1 &" unless WITH_PBS
            self.pid = WITH_PBS ? `#{cmd}` : Process.spawn(cmd, pgroup: true)
          }
        end
      end

      # If successful, set the status to "Submitted" and save to database.
      unless pid.nil? || pid.empty?
        self.pid = pid.strip
        set_status! :b
      else
        self.pid = nil
        set_status! :f
      end
    end

    # Write the input deck for solving in Ansys.
    def generate_input_deck
      input_deck = Pathname.new(jobdir) + "#{prefix}.dat"

      l = convert(beam, :length)
      w = convert(beam, :width)
      h = convert(beam, :height)
      e = convert(beam.material, :modulus)
      rho = convert(beam.material, :density)
      p = convert(beam, :load)
      ms = convert(beam, :meshsize)
      wt = beam.weight

      # Stresses cannot be linearly interpolated since moment due to a
      # distributed load is proportional to distance squared.  Therefore, the
      # stress multiplier at the beam midpoint uses a load proportion as
      # follows:
      alpha = wt == 0 ? nil : p / wt

      # Generate the Elmer input deck.
      File.open(input_deck, 'w') do |f|

        # This APDL code creates the beam geometry, partitions it, meshes it
        # with SOLID185 brick elements, and creates surface effect elements
        # at the beams end so that a traction may be applied.
        f.puts "/prep7"
        f.puts "et,1,185"
        f.puts "r,1,"
        f.puts "mp,ex,1,#{e}"
        f.puts "mp,nuxy,1,#{beam.material.poisson}"
        f.puts "mp,dens,1,#{rho}"
        f.puts "et,2,154"
        f.puts "keyopt,2,2,1"
        f.puts "keyopt,2,4,1"
        f.puts "keyopt,2,11,2"
        f.puts "r,2,"
        f.puts "mp,dens,2,"
        f.puts "block,,#{w},,#{h},,#{l}"
        f.puts "wpave,#{w/2},,"
        f.puts "wprota,,,90"
        f.puts "vsbw,all,,del"
        f.puts "wpave,,,#{l/2}"
        f.puts "wprota,,,-90"
        f.puts "vsbw,all,,del"
        f.puts "allsel,all"
        f.puts "vatt,1,1,1"
        f.puts "esize,#{ms}"
        f.puts "mshape,0"
        f.puts "mshkey,1"
        f.puts "vmesh,all"
        f.puts "cdwrite,geom,#{prefix},inp"
        f.puts "nsel,s,loc,z,0"
        f.puts "d,all,all"
        f.puts "asel,s,loc,z,#{l}"
        f.puts "nsla,s,1"
        f.puts "type,2"
        f.puts "real,2"
        f.puts "mat,2"
        f.puts "local,100,,,,,,,"
        f.puts "csys,0"
        f.puts "esys,100"
        f.puts "esurf,"
        f.puts "esel,s,type,,2"
        f.puts "sfe,all,2,pres,1,#{-p / w / h}"
        f.puts "allsel,all"
        f.puts "acel,,#{GRAVITY},"
        f.puts "allsel,all"
        f.puts "fini"
        f.puts "/solution"
        f.puts "solve"
        f.puts "fini"

        # The following goes into the Ansys postprocessor to extract the
        # stress at the beam midpoint and the displacement at the end of the
        # beam.  The stress is factored appropriately to get peak stress at
        # the wall.  The displacement and stress are then written to file.
        f.puts "/post1"
        f.puts "set,1"
        f.puts "nsel,s,loc,x,#{w/2}"
        f.puts "nsel,r,loc,y,#{h}"
        f.puts "nsel,r,loc,z,#{l/2}"
        f.puts "*get,stress_node,node,1,nxth"
        f.puts "*get,stress,node,stress_node,s,z"
        f.puts "*get,stress_node_z,node,stress_node,loc,z"
        f.puts "nsel,s,loc,x,#{w}"
        f.puts "nsel,r,loc,y,#{h}"
        f.puts "nsel,r,loc,z,#{l}"
        f.puts "*get,displ_node,node,1,nxth"
        f.puts "*get,displ,node,displ_node,u,y"
        f.puts "*cfopen,#{prefix},stress,,"
        f.puts "*vwrite,stress*(2.0*#{alpha}+1.0)/((stress_node_z/#{l})*" \
          "(2.0*#{alpha}+(stress_node_z/#{l})))"
        f.puts "%G"
        f.puts "*cfclos"
        f.puts "*cfopen,#{prefix},displ,,"
        f.puts "*vwrite,displ"
        f.puts "%G"
        f.puts "*cfclos"

        # The following lines of code instruct Ansys to write nodal
        # coordinates, displacements, and stresses located just on the
        # surface of the beam to a CSV file to be read into Paraview.
        f.puts "asel,s,all"
        f.puts "nsla,s,1"
        f.puts "*get,nnummax,node,,num,max"
        f.puts "*del,nmask"
        f.puts "*del,narray"
        f.puts "*dim,nmask,array,nnummax"
        f.puts "*dim,narray,array,nnummax,7"
        f.puts "*vget,nmask(1),node,1,nsel"
        f.puts "*vmask,nmask(1)"
        f.puts "*vget,narray(1,1),node,1,loc,x"
        f.puts "*vmask,nmask(1)"
        f.puts "*vget,narray(1,2),node,1,loc,y"
        f.puts "*vmask,nmask(1)"
        f.puts "*vget,narray(1,3),node,1,loc,z"
        f.puts "*vmask,nmask(1)"
        f.puts "*vget,narray(1,4),node,1,u,x"
        f.puts "*vmask,nmask(1)"
        f.puts "*vget,narray(1,5),node,1,u,y"
        f.puts "*vmask,nmask(1)"
        f.puts "*vget,narray(1,6),node,1,u,z"
        f.puts "*vmask,nmask(1)"
        f.puts "*vget,narray(1,7),node,1,s,z"
        f.puts "*cfopen,#{prefix},csv"
        f.puts "*vmask,nmask(1)"
        f.puts "*vwrite,narray(1,1),narray(1,2),narray(1,3),narray(1,4)," \
          "narray(1,5),narray(1,6),narray(1,7)"
        f.puts "%G,%G,%G,%G,%G,%G,%G"
        f.puts "*cfclos"
        f.puts "fini"
      end

      input_deck.exist? ? input_deck : nil
    end

    # Write the Python script used to generate visual contoured plots for
    # post-processing using open source Paraview.  The script imports point
    # data in the form of exterior nodal coordinates from the CSV file
    # generated in Ansys.  Geometry is created using a Delaunay tesselation
    # algorithm.  Contours are then plotted on the resulting geometry.  The
    # script then creates a plane to represent the wall on one side, and an
    # arrow to represent the load.  A WebGL file is finally exported.
    # (Note: Paraview must be built using OSMesa in order to render on the
    # cluster off screen.)
    def generate_results_script
      # TODO: Give a warning when beam reaches nonlinear territory.
      # TODO: At some point create a second job to generate results.  Then FEA
      #       results can be used for scaling.
      jobpath = Pathname.new(jobdir)
      csv_file = jobpath + "#{prefix}.csv"
      paraview_script = jobpath + "#{prefix}.py"
      webgl_stress_file = jobpath + "#{prefix}_stress.webgl"
      webgl_displ_file = jobpath + "#{prefix}_displ.webgl"

      displ_conversion, displ_units =
        RESULT_UNITS[beam.result_unit_system.to_sym][:displ].values
      stress_conversion, stress_units =
        RESULT_UNITS[beam.result_unit_system.to_sym][:stress].values

      # TODO: Add error checking for displacement and stress values.
      displ_max = beam.displ / displ_conversion
      displ_max_abs = beam.displ.abs
      displ_min = 0.0
      if displ_max < 0
        displ_min = displ_max
        displ_max = 0.0
      end

      stress_max = beam.stress / stress_conversion

      l = convert(beam, :length)
      w = convert(beam, :width)
      h = convert(beam, :height)

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
        f.puts "from paraview.simple import *"
        f.puts "paraview.simple._DisableFirstRenderCameraReset()"

        f.puts "beamcsv = CSVReader(FileName=[\"#{csv_file}\"])"
        f.puts "beamcsv.HaveHeaders = 0"
        f.puts "renderView1 = GetActiveViewOrCreate('RenderView')"
        f.puts "tableToPoints1 = TableToPoints(Input=beamcsv)"
        f.puts "tableToPoints1.XColumn = 'Field 0'"
        f.puts "tableToPoints1.YColumn = 'Field 1'"
        f.puts "tableToPoints1.ZColumn = 'Field 2'"
        f.puts "calculator1 = Calculator(Input=tableToPoints1)"
        f.puts "calculator1.CoordinateResults = 1"
        f.puts "calculator1.Function = 'coords + #{displ_scale}*"\
          "(Field 3*iHat + Field 4*jHat + Field 5*kHat)'"
        f.puts "delaunay3D1 = Delaunay3D(Input=calculator1)"

        f.puts "calculator2 = Calculator(Input=delaunay3D1)"
        f.puts "calculator2.ResultArrayName = 'stress_zz (#{stress_units})'"
        f.puts "calculator2.Function = 'Field 6/#{stress_conversion}'"

        f.puts "stresszz#{stress_units}LUT = " \
          "GetColorTransferFunction('stresszz#{stress_units}')"
        f.puts "stresszz#{stress_units}LUT.RGBPoints = [-#{stress_max}, " \
          "0.231373, 0.298039, 0.752941, 0.0, 0.865003, 0.865003, 0.865003, " \
          "#{stress_max}, 0.705882, 0.0156863, 0.14902]"
        f.puts "stresszz#{stress_units}LUT.ScalarRangeInitialized = 1.0"
        f.puts "stresszz#{stress_units}LUT.ApplyPreset('Cool to Warm " \
          "(Extended)', True)"

        f.puts "calculator2Display = Show(calculator2, renderView1)"
        f.puts "calculator2Display.ColorArrayName = ['POINTS', 'stress_zz " \
          "(#{stress_units})']"
        f.puts "calculator2Display.LookupTable = stresszz#{stress_units}LUT"
        f.puts "calculator2Display.ScalarOpacityUnitDistance = " \
          "0.027201157402185396"
        f.puts "calculator2Display.Scale = [#{view_scale}, #{view_scale}, "\
          "#{view_scale}]"

        f.puts "calculator2Display.SetScalarBarVisibility(renderView1, True)"
        f.puts "stresszz#{stress_units}LUT.RescaleTransferFunction" \
          "(-#{stress_max}, #{stress_max})"
        f.puts "stresszz#{stress_units}PWF = " \
          "GetOpacityTransferFunction('stresszz#{stress_units}')"
        f.puts "stresszz#{stress_units}PWF.Points = [-#{stress_max}, 0.0, " \
          "0.5, 0.0, #{stress_max}, 1.0, 0.5, 0.0]"
        f.puts "stresszz#{stress_units}PWF.ScalarRangeInitialized = 1"
        f.puts "stresszz#{stress_units}PWF.RescaleTransferFunction" \
          "(-#{stress_max}, #{stress_max})"

        f.puts "plane1 = Plane()"
        f.puts "plane1.Origin = [0.0, 0.0, 0.0]"
        f.puts "plane1.Point1 = [#{w}, 0.0, 0.0]"
        f.puts "plane1.Point2 = [0.0, #{h}, 0.0]"
        f.puts "plane1.XResolution = 1"
        f.puts "plane1.YResolution = 1"

        f.puts "plane1Display = Show(plane1, renderView1)"
        f.puts "plane1Display.Scale = [#{plane_scale * view_scale}, " \
          "#{plane_scale * view_scale}, 1.0]"
        f.puts "plane1Display.Position = " \
          "[#{(1 - plane_scale) * w * view_scale / 2}, " \
          "#{(1 - plane_scale) * h * view_scale / 2}, 0.0]"
        f.puts "plane1Display.DiffuseColor = [0.35, 0.35, 0.35]"

        f.puts "arrow1 = Arrow()"
        f.puts "arrow1.TipResolution = 50"
        f.puts "arrow1.TipRadius = 0.1"
        f.puts "arrow1.TipLength = 0.35"
        f.puts "arrow1.ShaftResolution = 50"
        f.puts "arrow1.ShaftRadius = 0.03"
        f.puts "arrow1.Invert = 1"

        f.puts "arrow1Display = Show(arrow1, renderView1)"
        f.puts "arrow1Display.DiffuseColor = [1.0, 0.0, 0.0]"
        f.puts "arrow1Display.Orientation = [0.0, 0.0, 90.0]"
        f.puts "arrow1Display.Position = [#{w * view_scale / 2}, " \
          "#{(h - displ_scale * displ_max_abs) * view_scale}, " \
          "#{l * view_scale}]"
        f.puts "arrow1Display.Scale = [#{arrow_scale * view_scale}, " \
          "#{arrow_scale * view_scale}, #{arrow_scale * view_scale}]"

        f.puts "sb = GetScalarBar(stresszz#{stress_units}LUT, GetActiveView())"
        f.puts "sb.Orientation = 'Horizontal'"
        f.puts "sb.Position = [0.3, 0.05]"

        f.puts "renderView1.ResetCamera()"

        f.puts "ExportView(\"#{webgl_stress_file}\", view=renderView1)"

        f.puts "SetActiveSource(calculator2)"
        f.puts "calculator2Display.SetScalarBarVisibility(renderView1, False)"
        f.puts "Render()"

        f.puts "calculator2.ResultArrayName = 'displacement_Y " \
          "(#{displ_units})'"
        f.puts "calculator2.Function = 'Field 4/#{displ_conversion}'"

        f.puts "ColorBy(calculator2Display, ('POINTS', 'displacement_Y " \
          "(#{displ_units})'))"

        f.puts "calculator2Display.SetScalarBarVisibility(renderView1, True)"

        f.puts "displacementY#{displ_units}LUT = " \
          "GetColorTransferFunction('displacementY#{displ_units}')"
        f.puts "displacementY#{displ_units}LUT.RGBPoints = [#{displ_min}, " \
          "0.231373, 0.298039, 0.752941, #{(displ_max + displ_min) / 2}, " \
          "0.865003, 0.865003, 0.865003, #{displ_max}, 0.705882, 0.0156863, " \
          "0.14902]"
        f.puts "displacementY#{displ_units}LUT.ScalarRangeInitialized = 1.0"
        f.puts "displacementY#{displ_units}LUT.ApplyPreset('Cool to Warm " \
          "(Extended)', True)"

        f.puts "displacementY#{displ_units}PWF = " \
          "GetOpacityTransferFunction('displacementY#{displ_units}')"
        f.puts "displacementY#{displ_units}PWF.Points = [#{displ_min}, 0.0, " \
          "0.5, 0.0, #{displ_max}, 1.0, 0.5, 0.0]"
        f.puts "displacementY#{displ_units}PWF.ScalarRangeInitialized = 1"

        f.puts "sb = GetScalarBar(displacementY#{displ_units}LUT, " \
          "GetActiveView())"
        f.puts "sb.Orientation = 'Horizontal'"
        f.puts "sb.Position = [0.3, 0.05]"
        f.puts "sb.ComponentTitle = ''"

        f.puts "renderView1.ResetCamera()"

        f.puts "ExportView(\"#{webgl_displ_file}\", view=renderView1)"
      end

      paraview_script.exist? ? paraview_script : nil
    end

    # Write the Bash script used to submit the job to the cluster.  The job
    # first generates the geometry and mesh using GMSH, converts the mesh to
    # Elmer format using ElmerGrid, solves using ElmerSolver, then creates
    # 3D visualization plots of the results using Paraview (batch).
    def generate_submit_script(args)
      jobpath = Pathname.new(jobdir)
      input_deck = Pathname.new(args[:input_deck]).basename
      output_file = "#{prefix}.o"
      results_script = Pathname.new(args[:results_script]).basename
      submit_script = jobpath + "#{prefix}.sh"
      shell_cmd = `which bash`.strip
      File.open(submit_script, 'w') do |f|
        f.puts "#!#{shell_cmd}"

        if WITH_PBS
          f.puts "#PBS -S #{shell_cmd}"
          f.puts "#PBS -N #{prefix}"
          f.puts "#PBS -l nodes=#{machines}:ppn=#{cores}"
          f.puts "#PBS -j oe"
          f.puts "machines=`uniq -c ${PBS_NODEFILE} | " \
            "awk '{print $2 \":\" $1}' | paste -s -d ':'`"
          f.puts "cd ${PBS_O_WORKDIR}"
          f.puts "#{ANSYS_EXE} -b -dis -machines $machines -O " \
            "$1 -I #{input_deck}"
        else
          f.puts "cd #{jobpath}"
          f.puts "#{ANSYS_EXE} -b -np #{cores} -O #{output_file} -I " \
            "#{input_deck}"
        end

        f.puts "#{PARAVIEW_EXE} #{results_script}"
      end

      submit_script.exist? ? submit_script : nil
    end

    def output_ok?(std_out)
      jobpath = Pathname.new(jobdir)
      std_out = jobpath + (WITH_PBS ? "#{prefix}.o#{pid.split('.')[0]}" :
        "#{prefix}.out")

      errors = nil
      if std_out.exist?
        File.foreach(std_out) do |line|
          errors = line.split[5].to_i if line.include? \
            "NUMBER OF ERROR   MESSAGES ENCOUNTERED="
        end
      end

      !errors.nil? && errors == 0
    end
end
