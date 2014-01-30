require 'active_support'
require 'active_support/core_ext/object'
require 'objectid_columns/objectid_columns_manager'

module ObjectidColumns
  module HasObjectidColumns
    extend ActiveSupport::Concern

    BINARY_OBJECTID_LENGTH = 12
    STRING_OBJECTID_LENGTH = 24

    def read_objectid_column(column_name, type)
      value = self[column_name]
      return value unless value

      unless value.kind_of?(String)
        raise "When trying to read the ObjectId column #{column_name.inspect} on #{inspect},  we got the following data from the database; we expected a String: #{value.inspect}"
      end

      case type
      when :binary then value = value[0..(BINARY_OBJECTID_LENGTH - 1)]
      when :string then value = value[0..(STRING_OBJECTID_LENGTH - 1)]
      else raise "Invalid type: #{type.inspect}"
      end

      value.to_bson_id
    end

    def write_objectid_column(column_name, new_value, type)
      if (! new_value)
        self[column_name] = new_value
      elsif new_value.respond_to?(:to_bson_id)
        write_value = new_value.to_bson_id
        unless ObjectidColumns.is_valid_bson_object?(write_value)
          raise "We called #to_bson_id on #{new_value.inspect}, but it returned this, which is not a BSON ID object: #{write_value.inspect}"
        end

        case type
        when :binary then self[column_name] = write_value.to_binary
        when :string then self[column_name] = write_value.to_s
        else raise ArgumentError, "Invalid type: #{type.inspect}"
        end
      else
        raise ArgumentError, "When trying to write the ObjectId column #{column_name.inspect} on #{inspect}, we were passed the following value, which doesn't seem to be a valid BSON ID in any format: #{new_value.inspect}"
      end
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
