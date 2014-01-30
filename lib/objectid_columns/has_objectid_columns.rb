require 'active_support'

module ObjectidColumns
  module HasObjectidColumns
    extend ActiveSupport::Concern

    def read_objectid_column(column_name, type)
      value = self[column_name]

      if (! value)
        value
      elsif value.respond_to?(:to_bson_id)
        value.to_bson_id
      else
        raise "When trying to read the ObjectId column #{column_name.inspect} on #{inspect},  we got the following data from the database, which does not seem to be a valid BSON ID in any format: #{value.inspect}"
      end
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
