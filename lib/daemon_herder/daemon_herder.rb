require 'tmpdir'
require 'daemon_controller'
require 'daemon_herder/daemon_command'

class DaemonHerder
  attr_writer :log

  DEFAULT_PING_COMMAND = lambda { true }

  def self.load(config_file)
    returning(self.new) do |herder|
      config = File.read(config_file)
      herder.instance_eval(config, File.expand_path(config_file), 1)
    end
  end

  def initialize(options = {})
    @quiet    = options.delete(:quiet) { false }
    @temp_dir = options.delete(:temp_dir) { Dir.tmpdir }
  end

  def daemon(name, options={})
    options[:name] = name
    log_file       = options.delete(:log_file) {
      File.join(@temp_dir,"#{name}.output")
    }
    identifier     = options.delete(:identifier) {name}
    start_command  = options.delete(:start_command) {
      command(:start, options)
    }
    stop_command   = options.delete(:stop_command) {
      command(:stop, options)
    }
    pid_file       = options.delete(:pid_file) {
      File.join(@temp_dir, "#{name}.pid")
    }
    timeout        = options.delete(:timeout) {5}
    log_files << log_file

    controllers << DaemonController.new(
      :identifier       => identifier, 
      :start_command    => start_command,
      :stop_command     => stop_command,
      :ping_command     => options.delete(:ping_command) {DEFAULT_PING_COMMAND},
      :pid_file         => pid_file,
      :log_file         => log_file,
      :timeout          => timeout)
  end

  def controllers
    @controllers ||= []
  end

  def log_files
    @log_files ||= []
  end

  def log
    @log ||= Logger.new($stdout)
  end

  def daemon_count
    controllers.size
  end

  def start_all!
    controllers.each do |controller|
      say "Starting '#{controller.identifier}'..."
      controller.start
      say "done.\n"
    end
  end

  def stop_all!
    controllers.reverse.each do |controller|
      say "Stopping '#{controller.identifier}'..."
      controller.stop
      say "done.\n"
    end
  end

  private

  def command(action, options)
    "bin/daemon_runner " + DaemonCommand.new(action, options).to_args.join(" ")
  end

  def say(message)
    print message unless @quiet
  end
end
