require 'active_support'
require 'active_support/core_ext/object'
require 'objectid_columns/objectid_columns_manager'

module ObjectidColumns
  # This module gets mixed into an ActiveRecord class when you say +has_objectid_column(s)+ or
  # +has_objectid_primary_key+. It delegates everything it does to the ObjectidColumnsManager; we do it this way so
  # that we can define all kinds of helper methods on the ObjectidColumnsManager without polluting the method
  # namespace on the actual ActiveRecord class.
  module HasObjectidColumns
    extend ActiveSupport::Concern

    # Reads the current value of the given +column_name+ (which must be an ObjectId column) as an ObjectId object.
    def read_objectid_column(column_name)
      self.class.objectid_columns_manager.read_objectid_column(self, column_name)
    end

    # Writes a new value to the given +column_name+ (which must be an ObjectId column), accepting a String (in either
    # hex or binary formats) or an ObjectId object, and transforming it to whatever storage format is correct for
    # that column.
    def write_objectid_column(column_name, new_value)
      self.class.objectid_columns_manager.write_objectid_column(self, column_name, new_value)
    end

    # Called as a +before_create+ hook, if (and only if) this class has declared +has_objectid_primary_key+ -- sets
    # the primary key to a newly-generated ObjectId, unless it has one already.
    def assign_objectid_primary_key
      self.id ||= ObjectidColumns.new_objectid
    end

    module ClassMethods
      # Does this class have any ObjectId columns? It does if this module has been included, since it only gets included
      # if you declare an ObjectId column.
      def has_objectid_columns?
        true
      end

      # Delegate all of the interesting work to the ObjectidColumnsManager.
      delegate :has_objectid_columns, :has_objectid_column, :has_objectid_primary_key,
        :translate_objectid_query_pair, :to => :objectid_columns_manager

      def objectid_columns_manager
        @objectid_columns_manager ||= ::ObjectidColumns::ObjectidColumnsManager.new(self)
      end
    end
  end
end
