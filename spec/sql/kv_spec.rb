require "spec_helper"
require "nodedb/sql/kv"

RSpec.describe NodeDB::SQL::KV do
  describe ".set_ttl" do
    it "renders the UPDATE ... SET ttl statement" do
      sql = described_class.set_ttl(table: "cache", key: "'k1'", ttl: 60)

      expect(sql).to eq("UPDATE cache SET ttl = 60 WHERE key = 'k1'")
    end

    it "coerces ttl with #to_i" do
      sql = described_class.set_ttl(table: "cache", key: "'k1'", ttl: "60")

      expect(sql).to eq("UPDATE cache SET ttl = 60 WHERE key = 'k1'")
    end
  end
end
