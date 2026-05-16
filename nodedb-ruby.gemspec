require_relative "lib/nodedb/version"

Gem::Specification.new do |spec|
  spec.name    = "nodedb-ruby"
  spec.version = NodeDB::VERSION
  spec.authors = ["Khairi"]
  spec.email   = ["khairi@labs.my"]

  spec.summary     = "Ruby client and SQL builders for NodeDB — the distributed multi-model database"
  spec.description = "Framework-agnostic core for connecting to NodeDB via PostgreSQL wire protocol. " \
                     "Provides connection helpers, type mapping, and SQL builders for all NodeDB engines " \
                     "(vector, graph, timeseries, spatial, KV, FTS). Used by activerecord-nodedb-adapter " \
                     "and sequel-nodedb-adapter."
  spec.homepage    = "https://github.com/mkhairi/nodedb-ruby"
  spec.license     = "BSD-2-Clause"

  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files         = Dir["lib/**/*", "LICENSE", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "pg", "~> 1.5"
  spec.add_dependency "msgpack", "~> 1.7"
end
