module ObjectidColumns
  module Columns
    class ObjectidColumn
      def initialize(active_record_class, column_object)
        @active_record_class = active_record_class
        @column_object = column_object

        min_length = case column_object.type
        when :binary then 12
        when :string then 24
        else raise ArgumentError, "The column #{column_object} is of type #{type.inspect}; we don't know how to treat this as an ObjectId column."
        end

        unless column_object.length >= min_length
          raise ArgumentError, "The column #{column_object} (of type #{type.inspect}) is of length #{column_object.length}; it needs to be of at least length #{min_length} to store an ObjectId."
        end
      end

      def column_name
        column_object.name
      end

      def type
        column_object.type
      end

      def query_value_for(value)
        if (! value)
          value
        elsif value.respond_to?(:to_bson_id)
          bson_id = value.to_bson_id
          case type
          when :binary then bson_id.to_binary
          when :string then bson_id.to_s
          else raise "Need to add query_value_for support for: #{type.inspect}"
          end
        else
          raise ArgumentError, "You're trying to constrain on ObjectID column #{column_name.inspect}, but you passed #{value.inspect}, and we don't know how to convert that to an ObjectID value."
        end
      end

      def install_methods!(dynamic_methods_module)
        t = type

        dynamic_methods_module.define_method(column_name) do
          read_objectid_column(column_name, t)
        end

        dynamic_methods_module.define_method("#{column_name}=") do |x|
          write_objectid_column(column_name, x, t)
        end
      end

      private
      attr_reader :active_record_class, :column_object
    end
  end
end
