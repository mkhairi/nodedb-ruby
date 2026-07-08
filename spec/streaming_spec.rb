require "spec_helper"
require "securerandom"

RSpec.describe NodeDB::Streaming do
  def nodedb_pg_up?
    require "socket"
    Socket.tcp(NODEDB_NATIVE_HOST, 6432, connect_timeout: 1) { true }
  rescue
    false
  end

  before(:all) do
    skip "NodeDB pgwire port 6432 unreachable" unless nodedb_pg_up?
  end

  let(:conn) do
    NodeDB::Connection.connect(
      host: NODEDB_NATIVE_HOST, port: 6432,
      dbname: NODEDB_DATABASE, user: NODEDB_USER, password: NODEDB_PASSWORD
    )
  end
  let(:name) { "stream_spec_#{SecureRandom.hex(4)}" }

  before(:each) do
    conn.exec("CREATE COLLECTION #{name} (id TEXT PRIMARY KEY, n INTEGER) " \
              "WITH (engine='document_strict')")
    values = (1..25).map { |i| "('r#{format("%02d", i)}', #{i})" }.join(", ")
    conn.exec("INSERT INTO #{name} (id, n) VALUES #{values}")
  end

  after(:each) do
    conn.exec("DROP COLLECTION #{name}")
    conn.close
  end

  it "yields every row as a Hash without buffering the whole result" do
    rows = []
    described_class.each_row(conn, "SELECT id, n FROM #{name}") { |row| rows << row }

    expect(rows.length).to eq(25)
    expect(rows.first).to include("id", "n")
  end

  it "returns an Enumerator without a block" do
    enum = described_class.each_row(conn, "SELECT id FROM #{name}")
    expect(enum).to be_an(Enumerator)
    expect(enum.count).to eq(25)
  end

  it "leaves the connection usable after an early break" do
    described_class.each_row(conn, "SELECT id FROM #{name}") { |_row| break }
    expect(conn.exec("SELECT 1 AS one").first).to eq("one" => "1")
  end

  it "raises QueryError on bad SQL and leaves the connection usable" do
    expect { described_class.each_row(conn, "SELECT FROM nope syntax") { |r| } }
      .to raise_error(NodeDB::QueryError)
    expect(conn.exec("SELECT 1 AS one").first).to eq("one" => "1")
  end

  it "rejects non-PG connections" do
    expect { described_class.each_row(Object.new, "SELECT 1") { |r| } }
      .to raise_error(ArgumentError, /PG::Connection/)
  end
end
