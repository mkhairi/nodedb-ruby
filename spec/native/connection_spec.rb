RSpec.describe NodeDB::Native::Connection, :integration do
  def self.open_conn
    NodeDB::Native::Connection.connect(
      host: NODEDB_NATIVE_HOST, port: NODEDB_NATIVE_PORT,
      database: NODEDB_DATABASE, username: NODEDB_USER, password: NODEDB_PASSWORD
    )
  end

  # One login for the whole group: NodeDB throttles repeated auth attempts,
  # so opening a fresh connection per example trips the lockout.
  before(:context) { @conn = self.class.open_conn }
  after(:context)  { @conn&.close }

  let(:conn) { @conn }

  it "completes the handshake and reports the server version" do
    expect(conn.server_version).to match(/NodeDB/i)
  end

  it "runs a scalar SELECT and returns a PG-shaped Result" do
    result = conn.run("SELECT 1 AS one")
    expect(result).to be_a(NodeDB::Native::Result)
    expect(result.fields).to include("one")
    expect(result.first["one"].to_s).to eq("1")
  end

  it "raises NodeDB::QueryError with the SQLSTATE-ish code on a bad query" do
    expect { conn.run("SELECT * FROM definitely_missing_collection_xyz") }
      .to raise_error(NodeDB::QueryError)
  end

  it "stays usable after a query error" do
    expect(conn.run("SELECT 2 AS two").first["two"].to_s).to eq("2")
  end

  it "round-trips builder-generated DDL + insert + select on a disposable collection" do
    coll = "nv_conn_spec_#{Process.pid}_#{rand(10_000)}"
    conn.run(NodeDB::SQL::Collection.create(coll, columns: ["id TEXT PRIMARY KEY", "name TEXT"]))
    expect(conn.run("INSERT INTO #{coll} (id, name) VALUES ('1', 'ada')").cmd_tuples).to eq(1)
    result = conn.run("SELECT * FROM #{coll}")
    # NodeDB document engine returns the row as a JSON `data` blob.
    expect(result.first["data"]).to include("ada")
  ensure
    conn.run(NodeDB::SQL::Collection.drop_if_exists(coll)) rescue nil
  end

  it "supports begin / commit / rollback" do
    expect(conn.begin).to be(true)
    expect(conn.commit).to be(true)
    expect(conn.begin).to be(true)
    expect(conn.rollback).to be(true)
  end

  it "answers ping" do
    expect(conn.ping).to be(true)
  end

  it "feeds NodeDB::SQL builder output over the native transport" do
    expect(conn.run(NodeDB::SQL::Collection.show)).to be_a(NodeDB::Native::Result)
  end

  it "closes cleanly and reports closed?" do
    c = self.class.open_conn
    c.close
    expect(c.closed?).to be(true)
  end
end
