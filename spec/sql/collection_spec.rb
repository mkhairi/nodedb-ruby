require "spec_helper"
require "nodedb/sql/collection"

RSpec.describe NodeDB::SQL::Collection do
  describe ".create" do
    it "renders a schemaless collection with no body" do
      expect(described_class.create(:users))
        .to eq("CREATE COLLECTION users")
    end

    it "renders a strict-schema collection with the WITH clause" do
      sql = described_class.create(
        :orders,
        engine:  :document_strict,
        columns: ["id TEXT PRIMARY KEY", "total NUMERIC"]
      )

      expect(sql).to eq(
        "CREATE COLLECTION orders (id TEXT PRIMARY KEY, total NUMERIC) WITH (engine='document_strict')"
      )
    end

    it "appends a BITEMPORAL flag inside the column-list parens with the WITH clause" do
      sql = described_class.create(
        :orders,
        engine:  :document_strict,
        columns: ["id TEXT PRIMARY KEY", "total NUMERIC"],
        flags:   [:bitemporal]
      )

      expect(sql).to eq(
        "CREATE COLLECTION orders (id TEXT PRIMARY KEY, total NUMERIC, BITEMPORAL) " \
        "WITH (engine='document_strict')"
      )
    end

    it "uppercases flag symbols / strings consistently" do
      sql = described_class.create(:c, columns: ["id TEXT"], flags: ["append_only"])

      expect(sql).to include("(id TEXT, APPEND_ONLY)")
    end

    it "fills timeseries defaults when columns is empty" do
      sql = described_class.create(:m, engine: :timeseries)

      expect(sql).to include("(ts TIMESTAMP TIME_KEY, value FLOAT)")
      expect(sql).to include("WITH (engine='timeseries')")
    end
  end
end
