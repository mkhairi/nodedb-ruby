require "socket"
require "msgpack"

RSpec.describe NodeDB::Native::Connection, "request cycle (no daemon)" do
  def open_pair(read_timeout: nil)
    client, server = UNIXSocket.pair
    conn = described_class.allocate
    conn.instance_variable_set(:@socket, client)
    conn.instance_variable_set(:@seq, 0)
    conn.instance_variable_set(:@read_timeout, read_timeout)
    @server = server
    conn
  end

  after { @server&.close unless @server&.closed? }

  def send_frame(hash)
    NodeDB::Native::Frame.write_frame(@server, MessagePack.pack(hash))
  end

  def ok_frame(seq, value)
    {"seq" => seq, "status" => 0, "columns" => ["v"], "rows" => [[[2, value]]]}
  end

  def partial_frame(seq, value)
    {"seq" => seq, "status" => 1, "columns" => ["v"], "rows" => [[[2, value]]]}
  end

  def error_frame(seq)
    {"seq" => seq, "status" => 2, "error" => {"code" => "XX000", "message" => "boom"}}
  end

  it "skips a stale frame from an earlier request" do
    conn = open_pair
    send_frame(ok_frame(0, 99))
    send_frame(ok_frame(1, 1))

    expect(conn.run("SELECT 1").first["v"]).to eq(1)
    expect(conn.closed?).to be(false)
  end

  it "raises the error that ends a partial stream" do
    conn = open_pair
    send_frame(partial_frame(1, 1))
    send_frame(error_frame(1))

    expect { conn.run("SELECT 1") }.to raise_error(NodeDB::QueryError, "XX000: boom")
    expect(conn.closed?).to be(false)
  end

  it "stays usable after a server error" do
    conn = open_pair
    send_frame(partial_frame(1, 1))
    send_frame(error_frame(1))
    expect { conn.run("x") }.to raise_error(NodeDB::QueryError)

    send_frame(ok_frame(2, 7))

    expect(conn.run("y").first["v"]).to eq(7)
  end

  it "closes when the peer drops" do
    conn = open_pair
    @server.close

    expect { conn.run("SELECT 1") }.to raise_error(NodeDB::ConnectionError)
    expect(conn.closed?).to be(true)
  end

  it "closes on an oversized frame" do
    conn = open_pair
    @server.write([20 * 1024 * 1024].pack("N"))

    expect { conn.run("SELECT 1") }.to raise_error(NodeDB::ConnectionError, /too large/)
    expect(conn.closed?).to be(true)
  end

  it "closes on read timeout" do
    conn = open_pair(read_timeout: 0.2)

    expect { conn.run("SELECT 1") }.to raise_error(NodeDB::TimeoutError)
    expect(conn.closed?).to be(true)
  end
end

RSpec.describe NodeDB::Native::Connection, "options and inspect (no daemon)" do
  it "refuses an sslmode that demands TLS before opening a socket" do
    expect(described_class).not_to receive(:new)

    expect {
      described_class.connect(database: "d", username: "u", sslmode: "verify-full")
    }.to raise_error(NodeDB::ConnectionError, /does not support TLS.*sslmode=verify-full/)
  end

  it "refuses an ssl file option" do
    expect {
      described_class.connect(database: "d", username: "u", sslrootcert: "/etc/ca.pem")
    }.to raise_error(NodeDB::ConnectionError, /does not support TLS/)
  end

  it "allows sslmode=prefer" do
    allow(described_class).to receive(:new).and_return(:conn)

    expect(described_class.connect(database: "d", username: "u", sslmode: "prefer")).to eq(:conn)
  end

  it "keeps the password out of #inspect" do
    conn = described_class.allocate
    conn.instance_variable_set(:@connection_parameters,
      {host: "h", port: 6433, database: "d", username: "u", password: "pw-placeholder-123"})

    expect(conn.inspect).to include("host=h", "username=u")
    expect(conn.inspect).not_to include("pw-placeholder-123")
  end
end
