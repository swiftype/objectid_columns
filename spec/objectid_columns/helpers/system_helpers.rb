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

      def create_standard_system_spec_tables!
        migrate do
          drop_table :objectidcols_spec_table rescue nil
          create_table :objectidcols_spec_table do |t|
            t.column :perfect_b_oid, 'BINARY(12)'
            t.column :longer_b_oid, 'BINARY(15)'

            t.column :too_short_b, 'BINARY(11)'
            t.column :perfect_b, 'BINARY(12)'
            t.column :longer_b, 'BINARY(15)'

            t.column :perfect_s_oid, 'VARCHAR(24)'
            t.column :longer_s_oid, 'VARCHAR(30)'

            t.column :too_short_s, 'VARCHAR(23)'
            t.column :perfect_s, 'VARCHAR(24)'
            t.column :longer_s, 'VARCHAR(30)'
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
