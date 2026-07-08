require "spec_helper"
require "nodedb/sql/graph"

RSpec.describe NodeDB::SQL::Graph do
  describe ".delete_edge" do
    it "renders the IN-clause form current upstream requires" do
      sql = described_class.delete_edge(
        from: "'alice'", to: "'bob'", type: "'knows'", in_collection: "social"
      )

      expect(sql).to eq("GRAPH DELETE EDGE IN social FROM 'alice' TO 'bob' TYPE 'knows'")
    end
  end

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
        personalization: {"alice" => 1.0, "bob" => 0.5}
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

  describe ".stats" do
    it "renders the tenant-wide compact form by default" do
      expect(described_class.stats).to eq("SHOW GRAPH STATS")
    end

    it "scopes to a single collection when collection is passed pre-quoted" do
      expect(described_class.stats(collection: "'social_nodes'"))
        .to eq("SHOW GRAPH STATS 'social_nodes'")
    end

    it "appends VERBOSE for the per-label-per-collection projection" do
      expect(described_class.stats(verbose: true))
        .to eq("SHOW GRAPH STATS VERBOSE")
    end

    it "appends AS OF SYSTEM TIME with the integer millisecond timestamp" do
      expect(described_class.stats(as_of: 1_700_000_000_000))
        .to eq("SHOW GRAPH STATS AS OF SYSTEM TIME 1700000000000")
    end

    it "combines collection + verbose + as_of in NodeDB-accepted ordering" do
      expect(described_class.stats(collection: "'g'", verbose: true, as_of: 100))
        .to eq("SHOW GRAPH STATS 'g' VERBOSE AS OF SYSTEM TIME 100")
    end
  end
end
