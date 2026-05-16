require "nodedb"

NODEDB_NATIVE_HOST = ENV.fetch("NODEDB_HOST", "localhost")
NODEDB_NATIVE_PORT = Integer(ENV.fetch("NODEDB_NATIVE_PORT", "6433"))
NODEDB_DATABASE    = ENV.fetch("NODEDB_DATABASE", "nodedb")
NODEDB_USER        = ENV.fetch("NODEDB_USER", "nodedb")
NODEDB_PASSWORD    = ENV.fetch("NODEDB_PASSWORD") do
  path = File.expand_path("~/.local/share/nodedb/.superuser_password")
  File.exist?(path) ? File.read(path).strip : nil
end

def nodedb_native_up?
  require "socket"
  Socket.tcp(NODEDB_NATIVE_HOST, NODEDB_NATIVE_PORT, connect_timeout: 1) { true }
rescue StandardError
  false
end

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.disable_monkey_patching!
  config.order = :defined

  config.before(:context, :integration) do
    skip "NodeDB native port #{NODEDB_NATIVE_PORT} unreachable" unless nodedb_native_up?
  end
end
