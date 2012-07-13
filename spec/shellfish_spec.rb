require 'shellfish'

module ShellfishHelper
  def mock_process(command, stdout, stderr, exit_code)
    if stdout.instance_of? String
      @channel.should_receive(:on_data).and_yield(@channel, stdout)
    else
      mock = @channel.should_receive(:on_data)
      stdout.each do |data|
        mock.and_yield(@channel, data)
      end
    end

    if stderr.instance_of? String
      @channel.should_receive(:on_extended_data).and_yield(@channel, 1, stderr)
    else
      mock = @channel.should_receive(:on_extended_data)
      stderr.each do |data|
        mock.and_yield(@channel, 1, data)
      end
    end

    @channel.should_receive(:on_request).with('exit-status').and_yield(@channel, @exit_data)
    @exit_data.should_receive(:read_long).and_return(exit_code)
    @channel.should_receive(:exec).with(command).and_yield(@channel, true)
    @channel.should_receive(:wait)
  end
end

RSpec.configure do |c|
  c.include ShellfishHelper
end

describe Shellfish do
  before :each do
    @session = double("session")
    @channel = double("channel")
    @exit_data = double("exit_data")

    @stdout = []
    @stderr = []

    @session.stub(:exec!).and_yield(nil, :stdout, "/home/testuser\n")
    @session.stub(:open_channel).and_yield(@channel).and_return(@channel)

    @channel.stub(:request_pty).and_yield(@channel, true)

    @shell = Shellfish.new(@session, :pty => true)

    @shell.on_stdout {|ch, data, line_begin| @stdout << data}
    @shell.on_stderr {|ch, data, line_begin| @stderr << data}
  end

  it "should get proper pwd" do
    @shell.pwd.should == "/home/testuser"
  end

  it "should successfully cd to root" do
    mock_process('cd "/"', [], [], 0)

    @shell.cd "/"

    @shell.pwd.should == "/"
  end

  it "should successfully cd to absolute directory" do
    mock_process('cd "/test/dir"', [], [], 0)

    @shell.cd "/test/dir"

    @shell.pwd.should == "/test/dir"
  end

  it "should successfully cd to relative directory" do
    mock_process('cd "test/dir"', [], [], 0)

    @shell.cd "test/dir"

    @shell.pwd.should == "/home/testuser/test/dir"
  end

  it "should successfully cd to the parent directory" do
    mock_process('cd "../another_user"', [], [], 0)

    @shell.cd "../another_user"

    @shell.pwd.should == "/home/another_user"
  end

  it "should run command on pwd" do
    mock_process('cd "/home/testuser" && test_command', [], [], 0)

    @shell.run "test_command"
  end

  it "should run command and return a return code" do
    mock_process('cd "/home/testuser" && test_command', [], [], 0)

    @shell.run("test_command").should == 0
  end

  it "should run sudo command" do
    mock_process(/sudo test_command$/, [], [], 0)

    @shell.sudo "test_command"
  end

  it "should understand environment variables" do
    mock_process(/^cd .* && TEST_KEY=test_var test_command/, [], [], 0)

    @shell.env['TEST_KEY'] = "test_var"
    @shell.run "test_command"
  end

  it "should load default rvm" do
    mock_process(/^source .* && env$/, "GEM_HOME=/home/testuser/.rvm/gems\n", [], 0)

    @shell.load_rvm

    @shell.rvm_loaded.should == true
    @shell.env['GEM_HOME'].should == '/home/testuser/.rvm/gems'
  end

  it "should run callback functions on stdout" do
    mock_process(/^cd .* && echo "hello, world!"$/, "hello, world!\n", [], 0)

    @shell.run('echo "hello, world!"')

    @stdout.should == ["hello, world!\n"]
  end

  it "should run callback functions on stderr" do
    mock_process(kind_of(String), [], "hello, world\n", 0)

    @shell.run('echo "hello, world" 1&>2')

    @stderr.should == ["hello, world\n"]
  end
end
