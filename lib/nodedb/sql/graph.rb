module NodeDB
  module SQL
    # SQL builders for NodeDB graph operations.
    # All string args (from, to, type, props) must already be quoted by caller.
    module Graph
      # in_collection: quoted collection name (required — NodeDB syntax changed to require IN clause)
      def self.insert_edge(from:, to:, type:, properties_json:, in_collection:)
        "GRAPH INSERT EDGE IN #{in_collection} FROM #{from} TO #{to} TYPE #{type} PROPERTIES #{properties_json}"
      end

      # direction: :both | :inbound | :outbound
      def self.traverse(from:, depth:, direction: :both)
        dir_clause = direction.to_sym == :both ? "" : " DIRECTION #{direction.to_s.upcase}"
        "GRAPH TRAVERSE FROM #{from} DEPTH #{depth.to_i}#{dir_clause}"
      end

      # algo: :pagerank | :betweenness | :closeness | :bfs | :dfs | :scc
      def self.algo(table:, algo:, **options)
        opts_clause = options.map { |k, v| "#{k.to_s.upcase} #{v}" }.join(" ")
        "GRAPH ALGO #{algo.to_s.upcase} ON #{table} #{opts_clause}".strip
      end

      def self.delete_edge(from:, to:, type:)
        "GRAPH DELETE EDGE FROM #{from} TO #{to} TYPE #{type}"
      end
    end
  end
end
