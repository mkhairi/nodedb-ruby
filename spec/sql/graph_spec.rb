require "spec_helper"
require "nodedb/sql/graph"

RSpec.describe NodeDB::SQL::Graph do
  describe ".algo" do
    it "renders scalar options uppercased and stringified" do
      sql = described_class.algo(table: "users", algo: :pagerank, damping: 0.85, iterations: 20)

      expect(sql).to eq("GRAPH ALGO PAGERANK ON users DAMPING 0.85 ITERATIONS 20")
    end

    it "JSON-encodes Hash options so PERSONALIZATION matches NodeDB v0.3.0 syntax" do
      sql = described_class.algo(
        table: "'users'",
        algo: :pagerank,
        damping: 0.85,
        personalization: { "alice" => 1.0, "bob" => 0.5 }
      )

      expect(sql).to eq(
        %(GRAPH ALGO PAGERANK ON 'users' DAMPING 0.85 PERSONALIZATION {"alice":1.0,"bob":0.5})
      )
    end

    it "JSON-encodes Array options" do
      sql = described_class.algo(table: "g", algo: :pagerank, seeds: %w[a b])

      expect(sql).to eq(%(GRAPH ALGO PAGERANK ON g SEEDS ["a","b"]))
    end

    it "strips trailing whitespace when no options are passed" do
      sql = described_class.algo(table: "g", algo: :pagerank)

      expect(sql).to eq("GRAPH ALGO PAGERANK ON g")
    end
  end
end
