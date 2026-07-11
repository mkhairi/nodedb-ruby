require "spec_helper"
require "nodedb/sql/vector"

RSpec.describe NodeDB::SQL::Vector do
  describe ".search" do
    it "renders a basic vector SEARCH" do
      sql = described_class.search(table: "t", column: "c", embedding: [1, 2], limit: 5)

      expect(sql).to eq("SEARCH t USING VECTOR(c, ARRAY[1.0, 2.0], 5)")
    end

    it "floats integer embedding values" do
      sql = described_class.search(table: "t", column: "c", embedding: [1, 2], limit: 5)

      expect(sql).to include("ARRAY[1.0, 2.0]")
    end

    it "coerces limit with #to_i" do
      sql = described_class.search(table: "t", column: "c", embedding: [1.0], limit: "5")

      expect(sql).to end_with("5)")
    end

    it "appends a WHERE clause when filter is given" do
      sql = described_class.search(table: "t", column: "c", embedding: [1.0, 2.0],
        limit: 5, filter: "active = true")

      expect(sql).to eq("SEARCH t USING VECTOR(c, ARRAY[1.0, 2.0], 5) WHERE active = true")
    end

    it "omits WHERE when filter is nil" do
      sql = described_class.search(table: "t", column: "c", embedding: [1.0], limit: 5)

      expect(sql).not_to include("WHERE")
    end
  end
end
