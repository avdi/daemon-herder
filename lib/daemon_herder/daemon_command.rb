require 'optparse'
require 'daemons'
require 'pathname'
require 'etc'
require 'tmpdir'

class DaemonCommand
  attr_reader :action
  attr_reader :strategy
  attr_reader :file
  attr_reader :args
  attr_reader :name
  attr_reader :user
  attr_reader :load_paths

  # Init from ARGV
  def self.from_args(args)
    options = {}
    if sep_index = args.index("--") then
      options[:args] = args.slice!((sep_index + 1)..-1)
    end
    parser = OptionParser.new { |opts|
      opts.on("--eval FILE", "Run daemon by evaling FILE") do |file|
        options[:eval] = file
      end
      opts.on("--exec FILE", "Run daemon by executing FILE") do |file|
        options[:exec] = file
      end
      opts.on("--name NAME", "Give the daemon a name") do |name|
        options[:name] = name
      end
      opts.on("--user USER", "Execute as USER") do |user|
        options[:user] = user
      end
      opts.on("-I PATH", "Add PATH to Ruby load paths") do |path|
        (options[:load_paths] ||= []) << path
      end
    }.parse!(args)
    raise "start|stop required" if args.empty?
    action  = args.shift.to_sym
    self.new(action, options)
  end

  def initialize(action, options = {})
    @action    = action
    options.key?(:exec) ^ options.key?(:eval) or 
      raise "Must have either :exec or :eval option"
    @strategy  = options.keys.find{|k| k == :exec || k == :eval}
    file       = options[@strategy]
    @args      = options.fetch(:args) { file.split[1..-1] }
    @file_path = Pathname(file.split.first)
    @name      = options.fetch(:name, @file_path.basename.to_s)
    @user      = options.fetch(:user) do 
      if running_as_root?
        raise "Daemon '#{name}': User MUST be set if running as root"
      else
        nil
      end
    end
    @load_paths = options.fetch(:load_paths, [])
    @load_paths.map!{|p| File.expand_path(p)}
  end

  def file
    file = if exec?
             if @file_path.executable? || @file_path.absolute?
               @file_path.to_s
             else
               resolved_path = resolve_exec_path(@file_path)
               (resolved_path || @file_path).to_s
             end
           else
             @file_path.expand_path.to_s
           end
    if file.nil? || file.empty? || !File.readable?(file)
      raise "#{file} does not exist or is not readable"
    end
    file
  end

  def command
    if @user
      "#{sudo_path} -u #{@user} -- #{@file_path}"
    else
      file
    end
  end

  def to_args
    args = [action.to_s, "--name", "'#{name}'", "--#{strategy}", file]
    if @user
      args += ["--user", user]
    end
    args += load_paths_args 
    args += args_with_separator
    args
  end

  def run!
    if eval?
      load_paths.each do |path|
        $LOAD_PATH << path
      end
      if @user
        switch_user!(@user)
      end
      $0 = file
    end
    run_daemon!
  end

  private

  def args_with_separator
    if not args.empty?
      ["--"] + args
    else
      []
    end
  end

  def run_daemon!
    ensure_temp_dir_writable!
    Daemons.run(*daemon_args)
  end

  def daemon_args
    [
      exec? ? command : file, 
      {
        :app_name            => name,
        :ARGV                => [action.to_s] + args_with_separator,
        :dir_mode            => :normal,
        :dir                 => temp_dir,
        :multiple            => false,
        :mode                => eval? ? :load : :exec,
        :log_output          => true,
        :keep_pid_files      => false,
        :hard_exit           => false
      }
    ]
  end

  def switch_user!(user)
    passwd_entry = Etc.getpwnam(user)
    uid = passwd_entry.uid
    gid = passwd_entry.gid
    Process::Sys.setgid(gid)
    Process::Sys.setuid(uid)

    # Unless we were actually switching TO root, make sure the change was
    # permanent.  Otherwise the daemon code could give itself root privs
    # unexpectedly.
    unless uid == 0
      ensure_user_permanently_switched!
    end
  end

  def ensure_user_permanently_switched!
    Process::Sys.setuid(0)
  rescue Errno::EPERM
    true
  else
    raise "Root privileges not successfully dropped!"
  end

  def running_as_root?
    Process::Sys::geteuid == 0
  end


  def exec?
    strategy == :exec
  end

  def eval?
    strategy == :eval
  end

  def resolve_exec_path(file_path)
    search_path = ENV['PATH'].split(Config::CONFIG['PATH_SEPARATOR'])
    search_path.map{|p| (Pathname(p) + file_path) }.detect{|p| 
      p.executable? 
    }
  end

  def sudo_path
    resolve_exec_path('sudo')
  end

  def temp_dir
    Dir.tmpdir
  end

  def ensure_temp_dir_writable!
    unless Pathname(temp_dir).writable?
      raise "Cannot write to #{temp_dir} as #{user}:#{group}"
    end
  end

  def user
    Etc.getpwuid(Process::Sys.geteuid).name
  end

  def group
    Etc.getgrgid(Process::Sys::getegid).name
  end

  def load_paths_args
    load_paths.map{|p| ["-I", p] }.flatten
  end
end
