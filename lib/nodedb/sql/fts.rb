module NodeDB
  module SQL
    # SQL builders for NodeDB full-text search.
    #
    # NodeDB removed the standalone `fts` engine. FTS now runs on a
    # document_strict (or schemaless) collection with a separate
    # CREATE FULLTEXT INDEX; `text_match(col, query)` is the filtering
    # predicate and now excludes non-matching rows server-side.
    module FTS
      # CREATE FULLTEXT INDEX <name> ON <collection> (<column>)
      #
      # @param name       [String] index name (unquoted identifier)
      # @param collection [String] collection name (unquoted identifier)
      # @param column     [String] indexed column (unquoted identifier)
      def self.create_index(name:, collection:, column:)
        "CREATE FULLTEXT INDEX #{name} ON #{collection} (#{column})"
      end

      # DROP INDEX <name>. NodeDB does not implement `DROP FULLTEXT INDEX`;
      # the generic `DROP INDEX` removes a fulltext index too.
      def self.drop_index(name)
        "DROP INDEX #{name}"
      end

      # SELECT id ... WHERE text_match(col, query). text_match filters rows
      # server-side now, so no client-side score filtering is needed.
      #
      # @param table  [String] pre-quoted table/collection name
      # @param column [String] column name (unquoted identifier)
      # @param query  [String] pre-quoted search term string
      # @param limit  [Integer]
      # @param fuzzy  [Boolean] enable fuzzy matching (distance: 2)
      def self.search(table:, column:, query:, limit:, fuzzy: false)
        fuzzy_opts = fuzzy ? ", { fuzzy: true, distance: 2 }" : ""
        "SELECT id " \
        "FROM #{table} " \
        "WHERE text_match(#{column}, #{query}#{fuzzy_opts}) " \
        "LIMIT #{limit.to_i}"
      end
    end
  end
end
