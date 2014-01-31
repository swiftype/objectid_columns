require 'objectid_columns/dynamic_methods_module'

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
      @class_dynamic_methods_module = Module.new
      @active_record_class.send(:extend, @class_dynamic_methods_module)
    end

    def has_objectid_primary_key(primary_key_name = nil)
      primary_key_name = primary_key_name.to_s if primary_key_name
      pk = active_record_class.primary_key

      if (! pk) && (! primary_key_name)
        raise ArgumentError, "Class #{active_record_class.name} has no primary key set, and you haven't supplied one to .has_objectid_primary_key. Either set one before this call (using self.primary_key = :foo), or supply one to this call (has_objectid_primary_key :foo) and we'll set it for you."
      end

      pk = pk.to_s if pk

      if (! pk) || (primary_key_name && pk.to_s != primary_key_name.to_s)
        active_record_class.primary_key = pk = primary_key_name
      end

      # In case someone is using composite_primary_key
      raise "You can't have an ObjectId primary key that's not a String or Symbol: #{pk.inspect}" unless pk.kind_of?(String) || pk.kind_of?(Symbol)

      has_objectid_column pk

      unless pk.to_s == 'id'
        p = pk
        dynamic_methods_module.define_method("id") { read_objectid_column(p) }
        dynamic_methods_module.define_method("id=") { |new_value| write_objectid_column(p, new_value) }
      end

      active_record_class.send(:before_create, :assign_objectid_primary_key)

      [ :find, :find_by_id ].each do |class_method_name|
        @class_dynamic_methods_module.send(:define_method, class_method_name) do |*args, &block|
          if args.length == 1 && args[0].kind_of?(String) || ObjectidColumns.is_valid_bson_object?(args[0]) || args[0].kind_of?(Array)
            args[0] = if args[0].kind_of?(Array)
              args[0].map { |x| objectid_columns_manager.to_valid_value_for_column(primary_key, x) }
            else
              objectid_columns_manager.to_valid_value_for_column(primary_key, args[0])
            end

            super(args[0], &block)
          else
            super(*args, &block)
          end
        end
      end
    end

    def has_objectid_columns(*columns)
      return unless active_record_class.table_exists?

      columns = autodetect_columns if columns.length == 0
      columns = columns.map { |c| c.to_s.strip.downcase.to_sym }
      columns.each do |column_name|
        column_object = active_record_class.columns.detect { |c| c.name.to_s == column_name.to_s }

        unless column_object
          raise ArgumentError, "#{active_record_class.name} doesn't seem to have a column named #{column_name.inspect} that we could make an ObjectId column; did you misspell it? It has columns: #{active_record_class.columns.map(&:name).inspect}"
        end

        unless [ :string, :binary ].include?(column_object.type)
          raise ArgumentError, "#{active_record_class.name} has a column named #{column_name.inspect}, but it is of type #{column_object.type.inspect}; we can only make ObjectId columns out of :string or :binary columns"
        end

        required_length = self.class.const_get("#{column_object.type.to_s.upcase}_OBJECTID_LENGTH")
        # The ||= is in case there's no limit on the column at all
        unless (column_object.limit || required_length + 1) >= required_length
          raise ArgumentError, "#{active_record_class.name} has a column named #{column_name.inspect} of type #{column_object.type.inspect}, but it is of length #{column_object.limit}, which is too short to contain an ObjectId of this format; it must be of length at least #{required_length}"
        end

        cn = column_name
        dynamic_methods_module.define_method(column_name) do
          read_objectid_column(cn)
        end

        dynamic_methods_module.define_method("#{column_name}=") do |x|
          write_objectid_column(cn, x)
        end

        @oid_columns[column_name] = column_object.type
      end
    end

    def read_objectid_column(model, column_name)
      column_name = column_name.to_s
      value = model[column_name]
      return value unless value

      unless value.kind_of?(String)
        raise "When trying to read the ObjectId column #{column_name.inspect} on #{inspect},  we got the following data from the database; we expected a String: #{value.inspect}"
      end

      # ugh...ActiveRecord 3.1.x can return this in certain circumstances
      return nil if value.length == 0

      case objectid_column_type(column_name)
      when :binary then value = value[0..(BINARY_OBJECTID_LENGTH - 1)]
      when :string then value = value[0..(STRING_OBJECTID_LENGTH - 1)]
      else unknown_type(type)
      end

      value.to_bson_id
    end

    def write_objectid_column(model, column_name, new_value)
      column_name = column_name.to_s
      if (! new_value)
        model[column_name] = new_value
      elsif new_value.respond_to?(:to_bson_id)
        model[column_name] = to_valid_value_for_column(column_name, new_value)
      else
        raise ArgumentError, "When trying to write the ObjectId column #{column_name.inspect} on #{inspect}, we were passed the following value, which doesn't seem to be a valid BSON ID in any format: #{new_value.inspect}"
      end
    end

    def to_valid_value_for_column(column_name, value)
      out = value.to_bson_id
      unless ObjectidColumns.is_valid_bson_object?(out)
        raise "We called #to_bson_id on #{value.inspect}, but it returned this, which is not a BSON ID object: #{out.inspect}"
      end

      case objectid_column_type(column_name)
      when :binary then out = out.to_binary
      when :string then out = out.to_s
      else unknown_type(type)
      end

      out
    end

    def translate_objectid_query_pair(query_key, query_value)
      if (type = oid_columns[query_key.to_sym])
        if (! query_value)
          [ query_key, query_value ]
        elsif query_value.respond_to?(:to_bson_id)
          v = query_value.to_bson_id
          v = case type
          when :binary then v.to_binary
          when :string then v.to_s
          else unknown_type(type)
          end
          [ query_key, v ]
        else
          raise ArgumentError, "You're trying to constrain #{active_record_class.name} on column #{query_key.inspect}, which is an ObjectId column, but the value you passed, #{query_value.inspect}, is not a valid format for an ObjectId."
        end
      else
        [ query_key, query_value ]
      end
    end

    alias_method :has_objectid_column, :has_objectid_columns

    private
    attr_reader :active_record_class, :dynamic_methods_module, :oid_columns

    def objectid_column_type(column_name)
      out = oid_columns[column_name.to_sym]
      raise "Something is horribly wrong; #{column_name.inspect} is not an ObjectId column -- we have: #{oid_columns.keys.inspect}" unless out
      out
    end

    def unknown_type(type)
      raise "Bug in ObjectidColumns in this method -- type #{type.inspect} does not have a case here."
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
