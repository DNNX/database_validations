require 'benchmark/ips'
require 'database_validations'

# ===Setups===
# Enable and start GC before each job run. Disable GC afterwards.
class GCSuite
  def warming(*)
    run_gc
  end

  def running(*)
    run_gc
  end

  def warmup_stats(*)
  end

  def add_report(*)
  end

  private

  def run_gc
    GC.enable
    GC.start
    GC.disable
  end
end

[
  {
    adapter: 'sqlite3',
    database: ':memory:'
  },
  {
    adapter: 'postgresql',
    database: 'database_validations_test'
  },
  {
    adapter: 'mysql2',
    database: 'database_validations_test',
    username: 'root'
  }
].each do |database_configuration|
  ActiveRecord::Base.establish_connection(database_configuration)
  ActiveRecord::Schema.define(version: 1) do
    drop_table :entities, if_exists: true

    create_table :entities do |t|
      t.integer :field
      t.index [:field], unique: true
    end
  end
  ActiveRecord::Schema.verbose = false
  ActiveRecord::Base.logger = nil

  class Entity < ActiveRecord::Base
    reset_column_information
  end

  class DbValidation < Entity
    validates_db_uniqueness_of :field
  end

  class AppValidation < Entity
    validates_uniqueness_of :field
  end

  # ===Benchmarks===
  suite = GCSuite.new
  field = 0
  Entity.create(field: field)

  # ===Save duplicate item===
  Benchmark.ips do |x|
    x.config(suite: suite)
    x.report('validates_db_uniqueness_of') { DbValidation.create(field: field) }
    x.report('validates_uniqueness_of') { AppValidation.create(field: field) }
  end

  # ===Save unique item===
  Benchmark.ips do |x|
    x.config(suite: suite)
    x.report('validates_db_uniqueness_of') { field +=1; DbValidation.create(field: field) }
    x.report('validates_uniqueness_of') { field +=1; AppValidation.create(field: field) }
  end

  # ===Each hundredth item is duplicate===
  Benchmark.ips do |x|
    x.config(suite: suite)
    x.report('validates_db_uniqueness_of') { field +=1; DbValidation.create(field: (field % 100 == 0 ? 0 : field)) }
    x.report('validates_uniqueness_of') { field +=1; AppValidation.create(field: (field % 100 == 0 ? 0 : field)) }
  end
end
