require 'net/ssh'
require 'highline'

class Shellfish
  class Abort < StandardError
    def initialize(msg)
      super(msg)
    end
  end

  RVM_KEYS = %w[GEM_HOME IRBRC MY_RUBY_HOME rvm_path PATH rvm_env_string rvm_ruby_string GEM_PATH RUBY_VERSION]
  DEFAULT_OPT = {:pty => false, :echo => false}

  attr_reader :env, :pwd, :rvm_loaded

  def initialize(session, opt = {})
    @opt = DEFAULT_OPT.merge opt

    @session = session
    @env = {}
    @rvm_loaded = false

    @stdout_callback = lambda do |channel, data, line_start|
      if data =~ /^\[sudo\] password for /
        password = HighLine.new.ask(data) {|q| q.echo = false}
        channel.send_data(password + "\n")
      else
        prefix = "[OUT]: "
        data.each_line do |line|
          if line_start
            print prefix
          else
            line_start = true
          end
          print line
        end
      end
    end

    @stderr_callback = lambda do |channel, data, line_start|
      prefix = "[ERR]: "
      data.each_line do |line|
        if line_start
          print prefix
        else
          line_start = true
        end
        print line
      end
    end

    @exit_callback = lambda {|exit_code| exit_code}

    get_pwd
  end

  def self.start(*args)
    shellopt = {}
    if args.length > 0 && args[-1].instance_of?(Hash)
      opt = args[-1]
      opt.each do |key,val|
        if DEFAULT_OPT.member? key
          opt.delete(key)
          shellopt[key] = val
        end
      end
    end

    Net::SSH.start(*args) do |session|
      sh = self.new(session, shellopt)
      yield sh
    end
  end

  def run(cmd)
    remote_cmd = command_string(cmd)

    remote_run(remote_cmd)
  end

  def sudo(cmd)
    sudo_cmd = @rvm_loaded ? "rvmsudo #{cmd}" : "sudo #{cmd}"

    run sudo_cmd
  end

  def cd(target)
    remote_cmd = "cd #{target}"
    remote_run(remote_cmd)
    new_pwd = if target[0] == ?/ then target else "#{@pwd}/#{target}" end
    @pwd = File.expand_path(new_pwd)
  end

  def load_rvm
    remote_run("source .rvm/environments/default && env") do |stream, data|
      if stream == :stderr
        raise Abort, "failed to load rvm: #{data}"
      else
        data.split("\n").each do |line|
          key, value = line.rstrip.split('=', 2)
          if RVM_KEYS.member? key
            @env[key] = value
          end
        end
        @rvm_loaded = true
      end
    end
  end

  def on_stdout(&block)
    @stdout_callback = block
  end

  def on_stderr(&block)
    @stderr_callback = block
  end

  def on_exit(&block)
    @exit_callback = block
  end

  private

  def env_string
    @env.map { |k,v| "#{k}=#{v}" }.join " " unless @env.empty?
  end

  def command_string(cmd)
    cd_string = "cd #{@pwd} &&"
    [cd_string, env_string, cmd].compact.join(" ")
  end

  def get_pwd
    @session.exec! "pwd" do |ch, stream, data|
      if stream == :stdout
        @pwd = data.rstrip
      else
        raise Abort, "remote command 'pwd' failed: #{data}"
      end
    end
  end

  def remote_run(command)
    exit_code = 0

    channel = @session.open_channel do |channel|
      if @opt[:pty]
        channel.request_pty do |ch, success|
          raise Abort, "request_pty failed" unless success
        end
      end

      channel.on_data do |ch, data|
        if block_given?
          yield :stdout, data
        else
          @stdout_callback[ch, data]
        end
      end

      channel.on_extended_data do |ch, type, data|
        if block_given?
          yield :stderr, data
        else
          @stderr_callback[ch, data]
        end
      end

      channel.on_request('exit-status') do |ch, data|
        exit_code = data.read_long
        @exit_callback[exit_code]
      end

      channel.exec command do |ch, success|
        cmd_success = success
      end
    end

    channel.wait
    raise Abort, exit_code.to_s if exit_code != 0
  end
end
