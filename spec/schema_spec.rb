require "spec_helper"
require "securerandom"

RSpec.describe NodeDB::Schema do
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
  let(:name) { "schema_spec_#{SecureRandom.hex(4)}" }

  before(:each) do
    conn.exec("CREATE COLLECTION #{name} " \
              "(id TEXT PRIMARY KEY, label TEXT, score FLOAT, emb VECTOR(3)) " \
              "WITH (engine='document_strict')")
  end

  after(:each) do
    conn.exec("DROP COLLECTION #{name}")
    conn.close
  end

  describe ".columns" do
    it "returns typed columns, deduped and without internals" do
      cols = described_class.columns(conn, name)

      expect(cols.map(&:name)).to eq(%w[id label score emb])
      expect(cols.map(&:pg_type)).to eq(
        ["text", "text", "double precision", "text"]
      )

      emb = cols.last
      expect(emb.type).to eq("VECTOR(3)")
      expect(emb.oid).to eq(25)
    end

    it "marks the primary key even though DESCRIBE splits it across duplicate rows" do
      id = described_class.columns(conn, name).first
      expect(id.primary_key).to be(true)
      expect(described_class.columns(conn, name).count(&:primary_key)).to eq(1)
    end

    it "exposes internal columns on request" do
      all = described_class.columns(conn, name, internal: true)
      expect(all.map(&:name)).to include("__storage")
    end
  end

  describe ".normalize" do
    it "normalizes raw DESCRIBE hashes without a connection" do
      cols = described_class.normalize([
        {"field" => "id", "type" => "TEXT", "nullable" => "false"},
        {"field" => "id", "type" => "TEXT PRIMARY KEY", "nullable" => "true"},
        {"field" => "n", "type" => "INTEGER", "nullable" => "true"},
        {"field" => "__storage", "type" => "document_strict", "nullable" => "false"}
      ])

      expect(cols.map(&:name)).to eq(%w[id n])
      expect(cols.first.primary_key).to be(true)
      expect(cols.last.pg_type).to eq("integer")
    end
  end

  describe ".collections" do
    it "lists collection names" do
      expect(described_class.collections(conn)).to include(name)
    end
  end
end
