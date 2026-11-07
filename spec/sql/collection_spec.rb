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
        engine: :document_strict,
        columns: ["id TEXT PRIMARY KEY", "total NUMERIC"]
      )

      expect(sql).to eq(
        "CREATE COLLECTION orders (id TEXT PRIMARY KEY, total NUMERIC) WITH (engine='document_strict')"
      )
    end

    it "puts a bitemporal flag in the WITH clause, where NodeDB honours it" do
      sql = described_class.create(
        :orders,
        engine: :document_strict,
        columns: ["id TEXT PRIMARY KEY", "total NUMERIC"],
        flags: [:bitemporal]
      )

      expect(sql).to eq(
        "CREATE COLLECTION orders (id TEXT PRIMARY KEY, total NUMERIC) " \
        "WITH (engine='document_strict', bitemporal=true)"
      )
    end

    it "accepts flags as strings and without an engine" do
      sql = described_class.create(:c, columns: ["id TEXT"], flags: ["APPEND_ONLY"])

      expect(sql).to eq("CREATE COLLECTION c (id TEXT) WITH (append_only=true)")
    end

    it "rejects a flag that is not a bare identifier" do
      expect { described_class.create(:c, flags: ["x=1); DROP"]) }.to raise_error(ArgumentError)
    end

    it "fills timeseries defaults when columns is empty" do
      sql = described_class.create(:m, engine: :timeseries)

      expect(sql).to include("(timestamp BIGINT TIME_KEY, value FLOAT)")
      expect(sql).to include("WITH (engine='timeseries')")
    end

    it "doubles an embedded single quote in an engine_options value" do
      sql = described_class.create(:t, engine: :document, engine_options: {comment: "it's"})

      expect(sql).to eq("CREATE COLLECTION t WITH (comment='it''s')")
    end

    it "keeps a malicious-shaped value inside a single literal" do
      sql = described_class.create(:t, engine: :document, engine_options: {comment: "x', evil='y"})

      expect(sql).to eq("CREATE COLLECTION t WITH (comment='x'', evil=''y')")
      expect(sql.scan("WITH (").length).to eq(1)
    end

    it "rejects an engine_options key with a space" do
      expect {
        described_class.create(:t, engine: :document, engine_options: {"a b" => "x"})
      }.to raise_error(ArgumentError, /invalid engine option key/)
    end

    it "rejects an engine_options key with a quote" do
      expect {
        described_class.create(:t, engine: :document, engine_options: {"k'" => "x"})
      }.to raise_error(ArgumentError, /invalid engine option key/)
    end
  end
end
