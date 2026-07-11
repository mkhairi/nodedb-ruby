require "spec_helper"
require "nodedb/sql/fts"

RSpec.describe NodeDB::SQL::FTS do
  describe ".create_index" do
    it "renders CREATE FULLTEXT INDEX" do
      sql = described_class.create_index(name: "idx1", collection: "docs", column: "body")

      expect(sql).to eq("CREATE FULLTEXT INDEX idx1 ON docs (body)")
    end
  end

  describe ".drop_index" do
    it "renders a plain DROP INDEX (not DROP FULLTEXT INDEX)" do
      sql = described_class.drop_index("idx1")

      expect(sql).to eq("DROP INDEX idx1")
    end
  end

  describe ".search" do
    it "renders a non-fuzzy text_match search" do
      sql = described_class.search(table: "docs", column: "body", query: "'hello'", limit: 10)

      expect(sql).to eq("SELECT id FROM docs WHERE text_match(body, 'hello') LIMIT 10")
    end

    it "appends the fuzzy options when fuzzy: true" do
      sql = described_class.search(table: "docs", column: "body", query: "'hello'",
        limit: 10, fuzzy: true)

      expect(sql).to eq(
        "SELECT id FROM docs WHERE text_match(body, 'hello', { fuzzy: true, distance: 2 }) LIMIT 10"
      )
    end

    it "coerces limit with #to_i" do
      sql = described_class.search(table: "docs", column: "body", query: "'hello'", limit: "10")

      expect(sql).to end_with("LIMIT 10")
    end
  end
end
