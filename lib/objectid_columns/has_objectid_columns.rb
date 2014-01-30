require 'active_support'
require 'active_support/core_ext/object'
require 'objectid_columns/objectid_columns_manager'

module ObjectidColumns
  module HasObjectidColumns
    extend ActiveSupport::Concern

    BINARY_OBJECTID_LENGTH = 12
    STRING_OBJECTID_LENGTH = 24

    def read_objectid_column(column_name)
      self.class.objectid_columns_manager.read_objectid_column(self, column_name)
    end

    def write_objectid_column(column_name, new_value)
      self.class.objectid_columns_manager.write_objectid_column(self, column_name, new_value)
    end

    module ClassMethods
      def has_objectid_columns?
        true
      end

      delegate :has_objectid_columns, :has_objectid_column, :objectid_column_object_for, :to => :objectid_columns_manager

      def objectid_columns_manager
        @objectid_columns_manager ||= ::ObjectidColumns::ObjectidColumnsManager.new(self)
      end
    end
  end
end
