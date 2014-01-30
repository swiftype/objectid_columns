require 'active_record'
require 'active_record/migration'

module ObjectidColumns
  module Helpers
    module SystemHelpers
      def migrate(&block)
        migration_class = Class.new(::ActiveRecord::Migration)
        metaclass = migration_class.class_eval { class << self; self; end }
        metaclass.instance_eval { define_method(:up, &block) }

        ::ActiveRecord::Migration.suppress_messages do
          migration_class.migrate(:up)
        end
      end

      def define_model_class(name, table_name, &block)
        model_class = Class.new(::ActiveRecord::Base)
        ::Object.send(:remove_const, name) if ::Object.const_defined?(name)
        ::Object.const_set(name, model_class)
        model_class.table_name = table_name
        model_class.class_eval(&block)
      end

      class << self
        def binary_column(length)
          case OBJECTID_COLUMNS_SPEC_DATABASE_CONFIG[:config][:adapter].to_s
          when /mysql/, /sqlite/ then "BINARY(#{length})"
          when /postgres/ then "BYTEA"
          else raise "Don't yet know how to define a binary column for database #{OBJECTID_COLUMNS_SPEC_DATABASE_CONFIG[:config][:adapter].inspect}"
          end
        end

        def supports_length_limits_on_binary_columns?
          case OBJECTID_COLUMNS_SPEC_DATABASE_CONFIG[:config][:adapter].to_s
          when /mysql/, /sqlite/ then true
          when /postgres/ then false
          else raise "Don't yet know whether database #{OBJECTID_COLUMNS_SPEC_DATABASE_CONFIG[:config][:adapter].inspect} supports limits on binary columns"
          end
        end
      end

      def create_standard_system_spec_tables!
        migrate do
          drop_table :objectidcols_spec_table rescue nil
          create_table :objectidcols_spec_table do |t|
            t.column :perfect_b_oid, ObjectidColumns::Helpers::SystemHelpers.binary_column(12)
            t.column :longer_b_oid, ObjectidColumns::Helpers::SystemHelpers.binary_column(15)

            t.column :too_short_b, ObjectidColumns::Helpers::SystemHelpers.binary_column(11)
            t.column :perfect_b, ObjectidColumns::Helpers::SystemHelpers.binary_column(12)
            t.column :longer_b, ObjectidColumns::Helpers::SystemHelpers.binary_column(15)

            t.column :perfect_s_oid, 'VARCHAR(24)'
            t.column :longer_s_oid, 'VARCHAR(30)'

            t.column :too_short_s, 'VARCHAR(23)'
            t.column :perfect_s, 'VARCHAR(24)'
            t.column :longer_s, 'VARCHAR(30)'

            t.integer :some_int_column
          end
        end
      end

      def create_standard_system_spec_models!
        define_model_class(:Spectable, 'objectidcols_spec_table') { }
      end

      def drop_standard_system_spec_tables!
        migrate do
          drop_table :objectidcols_spec_table rescue nil
        end
      end
    end
  end
end
