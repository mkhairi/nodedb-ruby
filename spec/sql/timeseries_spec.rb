require "spec_helper"
require "nodedb/sql/timeseries"

RSpec.describe NodeDB::SQL::Timeseries do
  describe ".time_bucket" do
    it "renders time_bucket() aliased :bucket by default" do
      sql = described_class.time_bucket("1 hour")

      expect(sql).to eq("time_bucket('1 hour', timestamp) AS bucket")
    end

    it "uses a custom alias when as: is given" do
      sql = described_class.time_bucket("1 hour", as: :hr)

      expect(sql).to eq("time_bucket('1 hour', timestamp) AS hr")
    end
  end

  describe ".epoch_ms" do
    it "converts a Time to Unix milliseconds" do
      time = Time.at(1700000000)

      expect(described_class.epoch_ms(time)).to eq(1700000000000)
    end
  end

  describe ".since_clause" do
    it "renders a timestamp > epoch_ms(time) fragment" do
      time = Time.at(1700000000)

      expect(described_class.since_clause(time)).to eq("timestamp > 1700000000000")
    end
  end

  describe ".until_clause" do
    it "renders a timestamp <= epoch_ms(time) fragment" do
      time = Time.at(1700000000)

      expect(described_class.until_clause(time)).to eq("timestamp <= 1700000000000")
    end
  end
end
