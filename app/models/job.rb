class Job < ActiveRecord::Base
  has_one :beam
  before_destroy :delete_staging_directories
  validates :status,   presence: true
  validates :config,   presence: true
  validates :cores,    presence: true,
                       numericality: { only_integer: true,
                                       greater_than_or_equal_to: 1,
                                       less_than_or_equal_to: 16 }
  validates :machines, presence: true,
                       numericality: { only_integer: true,
                                       greater_than_or_equal_to: 1,
                                       less_than_or_equal_to: 16 }

  require 'pathname'
  require 'nokogiri'
  include UnitsHelper

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

  validates_inclusion_of :status, in: JOB_STATUS.values

  # case @config
  # when "elmer"
    include ElmerJob
  # else
  #   include ElmerJob
  # end


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
    self.pid = nil
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

  def prefix
    beam.prefix
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

  # Check the job's status.  Use qstat if submitted via PBS, otherwise check
  # the child PIDs from the submitted group PID.
  def check_status
    return status if pid.nil?

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
    unless pid.nil?
      WITH_PBS ? `qdel #{pid}` : Process.kill("TERM", -pid.to_i)
      set_status! :m
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
      WITH_PBS ? "qstat #{pid} -x" : "pgrep -g #{pid}"
    end

    def check_completed_status
      jobpath = Pathname.new(jobdir)
      result_file = jobpath + jobpath.basename +
        (use_mpi? ? "#{prefix}0001.pvtu" : "#{prefix}0001.vtu")
      std_out = jobpath + (WITH_PBS ? "#{prefix}.o#{pid.split('.')[0]}" :
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
