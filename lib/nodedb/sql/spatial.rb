module NodeDB
  module SQL
    # SQL expression builders for NodeDB spatial engine (ST_* functions).
    # Coordinates must be pre-validated by the caller.
    module Spatial
      def self.within_distance(column:, lat:, lon:, meters:)
        "ST_DWithin(#{column}, ST_Point(#{lon.to_f}, #{lat.to_f}), #{meters.to_f})"
      end

      def self.distance_expr(column:, lat:, lon:, as: :distance)
        "ST_Distance(#{column}, ST_Point(#{lon.to_f}, #{lat.to_f})) AS #{as}"
      end

      def self.bbox_filter(column:, min_lon:, min_lat:, max_lon:, max_lat:)
        "#{column} && ST_MakeEnvelope(#{min_lon.to_f}, #{min_lat.to_f}, #{max_lon.to_f}, #{max_lat.to_f}, 4326)"
      end
    end
  end
end
