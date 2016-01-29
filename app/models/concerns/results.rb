module Results
  extend ActiveSupport::Concern

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
end
