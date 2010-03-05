require File.expand_path("../test_helper", File.dirname(__FILE__))
require 'daemon_herder/daemon_command'

class DaemonCommandtest < Test::Unit::TestCase
  def setup
    File.stubs(:readable?).returns(true)
  end

  def create_command_with_eval
    DaemonCommand.new(:start, :eval => "bin/MyDaemonA")
  end

  def create_command_from_args_with_eval
    DaemonCommand.from_args(%w[start --eval bin/MyDaemonA])
  end

  def create_command_with_exec
    DaemonCommand.new(:start, :exec => "MyDaemonB")
  end

  def create_command_from_args_with_exec
    DaemonCommand.from_args(%w[start --exec MyDaemonB])
  end


  def create_stop_command
    DaemonCommand.new(:stop, :exec => "MyDaemonC")
  end

  def create_stop_command_from_args
    DaemonCommand.from_args(%w[stop --exec MyDaemonC])
  end

  def create_command_with_args
    DaemonCommand.new(:stop, :exec => "MyDaemonD -a -b -c")
  end

  def create_command_with_args_from_args
    DaemonCommand.from_args(%w[stop --exec MyDaemonD -- -a -b -c])
  end

  def create_command_with_name
    DaemonCommand.new(:stop, :exec => "MyDaemonE", :name => "My Name")
  end

  def create_command_with_name_from_args
    DaemonCommand.from_args(%w[stop --exec MyDaemonE --name] + ["My Name"])
  end


  def test_command_with_eval
    command = create_command_with_eval
    assert_equal :start, command.action
    assert_equal :eval, command.strategy
    assert_equal File.expand_path("bin/MyDaemonA"), command.file
    assert_equal "MyDaemonA", command.name
    assert_equal(["start", "--name", "'MyDaemonA'", 
        "--eval", File.expand_path("bin/MyDaemonA")],
      command.to_args)
  end

  def test_command_from_args_with_eval
    command = create_command_from_args_with_eval
    assert_equal :start, command.action
    assert_equal :eval, command.strategy
    assert_equal File.expand_path("bin/MyDaemonA"), command.file
    assert_equal "MyDaemonA", command.name
  end

  def test_command_with_exec
    command = create_command_with_exec
    assert_equal :start, command.action
    assert_equal :exec, command.strategy
    assert_equal "MyDaemonB", command.file
    assert_equal "MyDaemonB", command.name
  end

  def test_command_from_args_with_exec
    command = create_command_from_args_with_exec
    assert_equal :start, command.action
    assert_equal :exec, command.strategy
    assert_equal "MyDaemonB", command.file
    assert_equal "MyDaemonB", command.name
  end

  def test_stop_command
    command = create_stop_command
    assert_equal :stop, command.action
  end

  def test_stop_command_from_args
    command = create_stop_command_from_args
    assert_equal :stop, command.action
  end

  def test_command_with_args
    command = create_command_with_args
    assert_equal %w[-a -b -c], command.args
    assert_equal(["stop", "--name", "'MyDaemonD'", 
      "--exec", "MyDaemonD", "--", "-a",  "-b", "-c"],
      command.to_args)
  end

  def test_command_with_args_from_args
    command = create_command_with_args_from_args
    assert_equal %w[-a -b -c], command.args
  end

  def test_command_with_name
    command = create_command_with_name
    assert_equal "MyDaemonE", command.file
    assert_equal "My Name", command.name
  end

  def test_command_with_args_from_args
    command = create_command_with_name_from_args
    assert_equal "MyDaemonE", command.file
    assert_equal "My Name", command.name
  end

  def test_run_eval_command
    Daemons.expects("run").
      with(File.expand_path("bin/MyDaemonA"), 
           :app_name            => "MyDaemonA",
           :ARGV                => ["start"],
           :dir_mode            => :normal,
           :dir                 => Dir.tmpdir,
           :multiple            => false,
           :mode                => :load,
           :log_output          => true,
           :keep_pid_files      => false,
           :hard_exit           => false)
    create_command_from_args_with_eval.run!
  end

  def test_run_exec_command
    Daemons.expects("run").
      with("MyDaemonB", 
           :app_name            => "MyDaemonB",
           :ARGV                => ["start"],
           :dir_mode            => :normal,
           :dir                 => Dir.tmpdir,
           :multiple            => false,
           :mode                => :exec,
           :log_output          => true,
           :keep_pid_files      => false,
           :hard_exit           => false)
    create_command_from_args_with_exec.run!
  end

  def test_run_stop_command
    Daemons.expects("run").
      with("MyDaemonC", 
           :app_name            => "MyDaemonC",
           :ARGV                => ["stop"],
           :dir_mode            => :normal,
           :dir                 => Dir.tmpdir,
           :multiple            => false,
           :mode                => :exec,
           :log_output          => true,
           :keep_pid_files      => false,
           :hard_exit           => false)
    create_stop_command.run!
  end

  def test_run_command_with_args
    Daemons.expects("run").
      with("MyDaemonD", 
           :app_name            => "MyDaemonD",
           :ARGV                => ["stop", "--", "-a", "-b", "-c"],
           :dir_mode            => :normal,
           :dir                 => Dir.tmpdir,
           :multiple            => false,
           :mode                => :exec,
           :log_output          => true,
           :keep_pid_files      => false,
           :hard_exit           => false)
    create_command_with_args.run!
  end

  def test_run_command_with_name
    Daemons.expects("run").
      with("MyDaemonE", 
           :app_name            => "My Name",
           :ARGV                => ["stop"],
           :dir_mode            => :normal,
           :dir                 => Dir.tmpdir,
           :multiple            => false,
           :mode                => :exec,
           :log_output          => true,
           :keep_pid_files      => false,
           :hard_exit           => false)
    create_command_with_name.run!
  end
  

end
