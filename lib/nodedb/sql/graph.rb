require "json"

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
        dir_clause = (direction.to_sym == :both) ? "" : " DIRECTION #{direction.to_s.upcase}"
        "GRAPH TRAVERSE FROM #{from} DEPTH #{depth.to_i}#{dir_clause}"
      end

      # algo: :pagerank | :betweenness | :closeness | :bfs | :dfs | :scc
      #
      # Hash- and Array-valued options are JSON-encoded so the rendered SQL
      # stays valid. Motivating example: personalized PageRank in NodeDB
      # v0.3.0+ takes `PERSONALIZATION { "alice": 1.0, "bob": 0.5 }`; without
      # explicit JSON encoding a Ruby Hash renders as `{"alice"=>1.0}` and
      # the parser rejects it.
      def self.algo(table:, algo:, **options)
        opts_clause = options.map { |k, v| "#{k.to_s.upcase} #{render_algo_value(v)}" }.join(" ")
        "GRAPH ALGO #{algo.to_s.upcase} ON #{table} #{opts_clause}".strip
      end

      # in_collection: quoted collection name (required — current upstream
      # rejects the IN-less form with a parse error, same syntax change
      # that hit insert_edge)
      def self.delete_edge(from:, to:, type:, in_collection:)
        "GRAPH DELETE EDGE IN #{in_collection} FROM #{from} TO #{to} TYPE #{type}"
      end

      # SHOW GRAPH STATS [<collection>] [VERBOSE] [AS OF SYSTEM TIME <ms>]
      #
      # NodeDB v0.3.0+ exposes persistent O(1) edge-store counters
      # (`edge_count`, `distinct_node_count`, `distinct_label_count`, per-label
      # counts) via a `SHOW` command. Omitting `collection` aggregates across
      # the tenant. `verbose: true` returns one row per (collection, label);
      # `verbose: false` (default) returns one row per collection with labels
      # collapsed into a JSON array. `as_of` is a millisecond timestamp.
      #
      # @param collection [String, nil] pre-quoted collection name literal
      # @param verbose    [Boolean]
      # @param as_of      [Integer, nil] millisecond timestamp
      def self.stats(collection: nil, verbose: false, as_of: nil)
        sql = +"SHOW GRAPH STATS"
        sql << " #{collection}" if collection
        sql << " VERBOSE" if verbose
        sql << " AS OF SYSTEM TIME #{as_of.to_i}" if as_of
        sql
      end

      def self.render_algo_value(value)
        case value
        when Hash, Array then JSON.generate(value)
        else value.to_s
        end
      end
      private_class_method :render_algo_value
    end
  end
end
