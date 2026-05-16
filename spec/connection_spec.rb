RSpec.describe NodeDB::Connection do
  describe ".connect protocol selector" do
    it "rejects an unknown protocol without touching the network" do
      expect {
        described_class.connect(dbname: "x", user: "y", password: "z", protocol: :carrier_pigeon)
      }.to raise_error(ArgumentError, /unknown protocol/)
    end

    it "returns a native connection when protocol: :native", :integration do
      conn = described_class.connect(
        host: NODEDB_NATIVE_HOST, port: NODEDB_NATIVE_PORT,
        dbname: NODEDB_DATABASE, user: NODEDB_USER, password: NODEDB_PASSWORD,
        protocol: :native
      )
      expect(conn).to be_a(NodeDB::Native::Connection)
      expect(conn.run("SELECT 1 AS one").first["one"].to_s).to eq("1")
    ensure
      conn&.close
    end
  end
end
