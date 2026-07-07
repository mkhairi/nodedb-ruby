require "spec_helper"

RSpec.describe NodeDB::Pool do
  def nodedb_pg_up?
    require "socket"
    Socket.tcp(NODEDB_NATIVE_HOST, 6432, connect_timeout: 1) { true }
  rescue StandardError
    false
  end

  before do
    skip "NodeDB pgwire port 6432 unreachable" unless nodedb_pg_up?
  end

  let(:pool) do
    described_class.new(
      size: 2, timeout: 2,
      dbname: NODEDB_DATABASE, user: NODEDB_USER, password: NODEDB_PASSWORD
    )
  end

  after { pool.shutdown }

  it "checks a connection out with #with" do
    pool.with do |conn|
      expect(conn.exec("SELECT 1+1 AS r").first).to eq("r" => "2")
    end
  end

  it "executes directly with #exec" do
    expect(pool.exec("SELECT 1 AS one").first).to eq("one" => "1")
  end

  it "reuses connections across checkouts" do
    first = pool.with { |c| c.object_id }
    expect(pool.with { |c| c.object_id }).to eq(first)
  end

  it "serves concurrent threads within the pool size" do
    results = Array.new(4) do
      Thread.new { pool.exec("SELECT 1 AS one").first["one"] }
    end.map(&:value)
    expect(results).to eq(%w[1 1 1 1])
  end

  it "connects lazily — construction succeeds without a reachable daemon" do
    bad = described_class.new(size: 1, timeout: 1,
                              host: "localhost", port: 1, dbname: "x", user: "x")
    expect { bad.with { |c| c } }.to raise_error(PG::Error)
  end
end
