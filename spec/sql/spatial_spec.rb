require "spec_helper"
require "nodedb/sql/spatial"

RSpec.describe NodeDB::SQL::Spatial do
  describe ".within_distance" do
    it "renders ST_DWithin with lon before lat inside ST_Point" do
      sql = described_class.within_distance(column: "geo", lat: 3.1, lon: 101.7, meters: 500)

      expect(sql).to eq("ST_DWithin(geo, ST_Point(101.7, 3.1), 500.0)")
    end
  end

  describe ".distance_expr" do
    it "renders ST_Distance with lon before lat, aliased :distance by default" do
      sql = described_class.distance_expr(column: "geo", lat: 3.1, lon: 101.7)

      expect(sql).to eq("ST_Distance(geo, ST_Point(101.7, 3.1)) AS distance")
    end

    it "uses a custom alias when as: is given" do
      sql = described_class.distance_expr(column: "geo", lat: 3.1, lon: 101.7, as: :dist)

      expect(sql).to eq("ST_Distance(geo, ST_Point(101.7, 3.1)) AS dist")
    end
  end

  describe ".bbox_filter" do
    it "renders the && ST_MakeEnvelope filter in SRID 4326" do
      sql = described_class.bbox_filter(column: "geo", min_lon: 100.0, min_lat: 1.0,
        max_lon: 102.0, max_lat: 4.0)

      expect(sql).to eq("geo && ST_MakeEnvelope(100.0, 1.0, 102.0, 4.0, 4326)")
    end
  end
end
