require 'shellfish'
require 'net/ssh'

Net::SSH.start('kanie.cafe24.com', 'kimhyunkang') do |session|
  sh = Shellfish.new(session, :pty => true)
  begin
    sh.load_rvm
    sh.cd "staticlog"
    sh.run "git pull"
    sh.run "bundle install --without=development"
    sh.run "rake compile"
    sh.sudo "rake install[/var/www]"
  rescue Shellfish::Abort => e
    puts "Abort[#{e.message}]"
  end
end
