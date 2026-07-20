require "spec_helper"

RSpec.describe NodeDB::Pool do
  # Daemon-less unit examples — no reachable NodeDB required. The
  # connection factory (NodeDB::Connection.connect) is stubbed so these
  # exercise Pool's own logic in isolation.
  describe "unit (no daemon required)" do
    let(:fake_conn) { instance_double(PG::Connection, close: nil, exec: nil) }

    it "does not connect during construction" do
      allow(NodeDB::Connection).to receive(:connect).and_return(fake_conn)

      described_class.new(size: 1, timeout: 1, dbname: "x", user: "x")

      expect(NodeDB::Connection).not_to have_received(:connect)
    end

    it "#with yields the connection built by the factory" do
      allow(NodeDB::Connection).to receive(:connect).and_return(fake_conn)
      pool = described_class.new(size: 1, timeout: 1, dbname: "x", user: "x")

      pool.with { |conn| expect(conn).to equal(fake_conn) }
    end

    it "#exec checks a connection out, execs, and checks it back in" do
      allow(fake_conn).to receive(:exec).with("SELECT 1").and_return([{"r" => "1"}])
      allow(NodeDB::Connection).to receive(:connect).and_return(fake_conn)
      pool = described_class.new(size: 1, timeout: 1, dbname: "x", user: "x")

      result = pool.exec("SELECT 1")

      expect(fake_conn).to have_received(:exec).with("SELECT 1")
      expect(result).to eq([{"r" => "1"}])
    end

    it "#reload closes existing connections and future checkouts reconnect" do
      first_conn = instance_double(PG::Connection, close: nil, exec: nil)
      second_conn = instance_double(PG::Connection, close: nil, exec: nil)
      allow(NodeDB::Connection).to receive(:connect).and_return(first_conn, second_conn)
      pool = described_class.new(size: 1, timeout: 1, dbname: "x", user: "x")
      pool.with { |c| c }

      pool.reload

      expect(first_conn).to have_received(:close)
      pool.with { |c| expect(c).to equal(second_conn) }
    end

    it "#shutdown closes connections" do
      allow(NodeDB::Connection).to receive(:connect).and_return(fake_conn)
      pool = described_class.new(size: 1, timeout: 1, dbname: "x", user: "x")
      pool.with { |c| c }

      pool.shutdown

      expect(fake_conn).to have_received(:close)
    end

    it "connects lazily — construction succeeds without a reachable daemon" do
      bad = described_class.new(size: 1, timeout: 1,
        host: "localhost", port: 1, dbname: "x", user: "x")
      expect { bad.with { |c| c } }.to raise_error(PG::Error)
    end
  end

  # Integration examples — require a reachable NodeDB pgwire daemon.
  describe "integration" do
    def nodedb_pg_up?
      require "socket"
      Socket.tcp(NODEDB_NATIVE_HOST, 6432, connect_timeout: 1) { true }
    rescue
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
  end
end
