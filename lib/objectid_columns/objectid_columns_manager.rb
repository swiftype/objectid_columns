require 'objectid_columns/dynamic_methods_module'
require 'objectid_columns/objectid_column'

module ObjectidColumns
  class ObjectidColumnsManager
    BINARY_OBJECTID_LENGTH = 12
    STRING_OBJECTID_LENGTH = 24

    def initialize(active_record_class)
      raise ArgumentError, "You must supply a Class, not: #{active_record_class.inspect}" unless active_record_class.kind_of?(Class)
      raise ArgumentError, "You must supply a Class that's a descendant of ActiveRecord::Base, not: #{active_record_class.inspect}" unless superclasses(active_record_class).include?(::ActiveRecord::Base)

      @active_record_class = active_record_class
      @oid_columns = { }
      @dynamic_methods_module = ObjectidColumns::DynamicMethodsModule.new(active_record_class, :ObjectidColumnsDynamicMethods)
    end

    def has_objectid_columns(*columns)
      columns = autodetect_columns if columns.length == 0
      to_objectid_columns(columns).each { |oid_column| oid_columns[oid_column.column_name.to_sym] = oid_column }

      install_methods!
    end

    def read_objectid_column(model, column_name)
      value = model[column_name]
      return value unless value

      unless value.kind_of?(String)
        raise "When trying to read the ObjectId column #{column_name.inspect} on #{inspect},  we got the following data from the database; we expected a String: #{value.inspect}"
      end

      case objectid_column_type(column_name)
      when :binary then value = value[0..(BINARY_OBJECTID_LENGTH - 1)]
      when :string then value = value[0..(STRING_OBJECTID_LENGTH - 1)]
      end

      value.to_bson_id
    end

    def write_objectid_column(model, column_name, new_value)
      if (! new_value)
        model[column_name] = new_value
      elsif new_value.respond_to?(:to_bson_id)
        write_value = new_value.to_bson_id
        unless ObjectidColumns.is_valid_bson_object?(write_value)
          raise "We called #to_bson_id on #{new_value.inspect}, but it returned this, which is not a BSON ID object: #{write_value.inspect}"
        end

        case objectid_column_type(column_name)
        when :binary then model[column_name] = write_value.to_binary
        when :string then model[column_name] = write_value.to_s
        end
      else
        raise ArgumentError, "When trying to write the ObjectId column #{column_name.inspect} on #{inspect}, we were passed the following value, which doesn't seem to be a valid BSON ID in any format: #{new_value.inspect}"
      end
    end

    def objectid_column_object_for(column_name)
      oid_columns[column_name.to_sym]
    end

    def objectid_column_type(column_name)
      oid_columns[column_name.to_sym].type
    end

    alias_method :has_objectid_column, :has_objectid_columns

    private
    attr_reader :active_record_class, :dynamic_methods_module, :oid_columns

    def install_methods!
      dynamic_methods_module.remove_all_methods!
      oid_columns.each { |name, col| col.install_methods!(dynamic_methods_module) }
    end

    def superclasses(klass)
      out = [ ]
      while (sc = klass.superclass)
        out << sc
        klass = sc
      end
      out
    end

    def autodetect_columns
      active_record_class.columns.select { |c| c.name =~ /_oid$/i }.map(&:name)
    end

    def to_objectid_columns(columns)
      columns = columns.map { |c| c.to_s.strip }.uniq
      column_objects = active_record_class.columns.select { |c| columns.include?(c.name) }
      missing = columns - column_objects.map(&:name)

      if missing.length > 0
        raise ArgumentError, "The following do not appear to be columns on #{active_record_class}, and thus can't possibly be ObjectId columns: #{missing.inspect}"
      end

      column_objects.map { |column_object| ObjectidColumns::ObjectidColumn.new(self, column_object) }
    end
  end
end
