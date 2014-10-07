require 'objectid_columns/dynamic_methods_module'

module ObjectidColumns
  # The ObjectidColumnsManager does all the real work of the ObjectidColumns gem, in many ways -- it takes care of
  # reading ObjectId values and transforming them to objects, transforming supplied data to the right format when
  # writing them, handling primary-key definitions and queries.
  #
  # This is a separate class, rather than being mixed into the actual ActiveRecord class, so that we can add methods
  # and define constants here without polluting the namespace of the underlying class.
  class ObjectidColumnsManager
    # NOTE: These constants are used in a metaprogrammed fashion in #has_objectid_columns, below. If you rename them,
    # you must change that, too.
    BINARY_OBJECTID_LENGTH = 12
    STRING_OBJECTID_LENGTH = 24

    # Creates a new instance. There should only ever be a single instance for a given ActiveRecord class, accessible
    # via ObjectidColumns::HasObjectidColumns.objectid_columns_manager.
    def initialize(active_record_class)
      raise ArgumentError, "You must supply a Class, not: #{active_record_class.inspect}" unless active_record_class.kind_of?(Class)
      raise ArgumentError, "You must supply a Class that's a descendant of ActiveRecord::Base, not: #{active_record_class.inspect}" unless superclasses(active_record_class).include?(::ActiveRecord::Base)

      @active_record_class = active_record_class
      @oid_columns = { }

      # We use a DynamicMethodsModule to add our magic to the target ActiveRecord class, rather than just defining
      # methods directly on the class, for a number of very good reasons -- see the class comment on
      # DynamicMethodsModule for more information.
      @dynamic_methods_module = ObjectidColumns::DynamicMethodsModule.new(active_record_class, :ObjectidColumnsDynamicMethods)

      self.class.register_for_table(active_record_class.table_name, self)
    end

    class << self
      # ObjectidColumns::Arel::Visitors::ToSql needs to be able to figure out whether an ObjectId column is of binary
      # or text format, in order to properly transform/quote the value it has. However, by the time the code gets there,
      # we no longer have access to the ActiveRecord model at all. So, instead, we need an entry point to be able to
      # find the ObjectidColumnsManager for a table by name. That's .for_table, below; this is the method called at
      # the end of the constructor of every ObjectidColumnsManager, registering the instance by table name.
      def register_for_table(table_name, instance)
        @_registered_instances ||= { }
        @_registered_instances[table_name] = instance
      end

      # See above. Given a table name, this returns the ObjectidColumnsManager for it, or +nil+ if none has been
      # defined for that table.
      def for_table(table_name)
        @_registered_instances[table_name]
      end
    end

    # This method basically says: does our +active_record_class+ have a primary key defined, for real? There are two
    # reasons this is anything more than (<tt>!! active_record_class.primary_key</tt>):
    #
    # * In earlier versions of ActiveRecord (like 3.0.x), this will return +id+ even if you haven't set it and there is
    #   no column named +id+.
    # * The +composite_primary_keys+ gem can make this an array instead.
    def activerecord_class_has_no_real_primary_key?
      (! active_record_class.primary_key) ||
        (active_record_class.primary_key == [ ]) ||
        ( ([ [ 'id' ], [ :id ] ].include?(Array(active_record_class.primary_key))) &&
          (! active_record_class.columns_hash.has_key?('id')) &&
          (! active_record_class.columns_hash.has_key?(:id)))
    end

    # If you haven't specified a primary key on your model (using <tt>self.primary_key=</tt>), and you call
    # +has_objectid_primary_key+, we want to tell the ActiveRecord model that that's the new primary key. This takes
    # care of that, and handles the fact that this may be a composite primary key, too.
    def set_primary_key_from!(primary_keys)
      if primary_keys.length > 1
        active_record_class.primary_key = primary_keys.map(&:to_s)
      elsif primary_keys.length == 1
        active_record_class.primary_key = primary_keys[0].to_s
      else
        # nothing here; we handle this elsewhere
      end
    end

    # Assigns a new ObjectId primary key to a brand-new model that's about to be created, if needed. This handles
    # composite primary keys correctly.
    def assign_objectid_primary_key(model)
      Array(model.class.primary_key).each do |pk_column|
        if is_objectid_column?(pk_column) && model[pk_column].blank?
          model.send("#{pk_column}=", ObjectidColumns.new_objectid)
        end
      end
    end

    # Given a model, returns the correct value for #id. This takes into account composite primary keys where some
    # columns may be ObjectId columns and some may not.
    def read_objectid_primary_key(model)
      pks = Array(model.class.primary_key)
      out = [ ]
      pks.each do |pk_column|
        out << if is_objectid_column?(pk_column)
          read_objectid_column(model, pk_column)
        else
          model[pk_column]
        end
      end
      out = out[0] if out.length == 1
      out
    end

    # Given a model, stores a new value for #id. This takes into account composite primary keys where some
    # columns may be ObjectId columns and some may not.
    def write_objectid_primary_key(model, new_value)
      pks = Array(model.class.primary_key)
      if pks.length == 1
        write_objectid_column(model, pks[0], new_value)
      else
        pks.each_with_index do |pk_column, index|
          value = new_value[index]
          if is_objectid_column?(pk_column)
            write_objectid_column(model, pk_column, value)
          else
            model[pk_column] = value
          end
        end
      end
    end

    # Implements .find or .find_by_id for classes that have a primary key that has at least one ObjectId column in it;
    # this takes care of handling both normal primary keys and composite primary keys.
    def find_or_find_by_id(*args)
      primary_key = active_record_class.primary_key
      pk_length = primary_key.kind_of?(Array) ? primary_key.length : 1

      # If we just have a single primary key, we flatten any input, just because that's exactly what base
      # ActiveRecord does...
      if pk_length == 1
        args = args.flatten
        args = args.map { |x| to_valid_value_for_column(primary_key, x) if x }
        yield(*args)
      else
        # composite_primary_keys, however, requires that you pass each key as a single, separate argument to .find or
        # .find_by_id; we transform them here.
        keys = args.map do |key|
          new_key = [ ]
          key.each_with_index do |key_component, index|
            column = primary_key[index]
            new_key << if is_objectid_column?(column)
              to_valid_value_for_column(column, key_component) if key_component
            else
              key_component
            end
          end
          new_key
        end
        yield(*keys)
      end
    end

    # Declares that this class is using an ObjectId as its primary key. Ordinarily, this requires no arguments;
    # however, if your primary key is not named +id+ and you have not yet told ActiveRecord this (using
    # <tt>self.primary_key = :foo</tt>), then you must pass the name of the primary-key column.
    #
    # Note that, unlike normal database-generated primary keys, this will cause us to auto-generate an ObjectId
    # primary key value for a new record just before saving it to the database (ActiveRecord's +before_create hook).
    # ObjectIds are safe to generate client-side, and very difficult to properly generate server-side in a relational
    # database. However, we will respect (and not overwrite) any primary key already assigned to the record before it's
    # saved, so if you want to assign your own ObjectId primary keys, you can.
    #
    # This method handles composite primary keys, as provided by the +composite_primary_keys+ gem, correctly.
    def has_objectid_primary_key(*primary_keys_that_are_objectid_columns)
      return unless active_record_class.table_exists?

      # First, normalize our set of primary keys that are ObjectId columns...
      primary_keys_that_are_objectid_columns = primary_keys_that_are_objectid_columns.compact.map(&:to_s).uniq

      # Now, see what all the primary keys are. If the user hasn't specified any primary keys on the class at all yet,
      # but has told us what they are, then we need to tell ActiveRecord what they are.
      all_primary_keys = if activerecord_class_has_no_real_primary_key?
        set_primary_key_from!(primary_keys_that_are_objectid_columns)
        primary_keys_that_are_objectid_columns
      else
        Array(active_record_class.primary_key)
      end
      # Normalize the set of all primary keys.
      all_primary_keys = all_primary_keys.compact.map(&:to_s).uniq

      # Let's make sure we have a primary key...
      raise ArgumentError, "Class #{active_record_class.name} has no primary key set, and you haven't supplied one to #has_objectid_primary_key" if all_primary_keys.empty?

      # If you didn't specify any ObjectId columns explicitly, use what we know about the class to figure out which
      # ones you mean.
      if primary_keys_that_are_objectid_columns.empty?
        if all_primary_keys.length == 1
          primary_keys_that_are_objectid_columns = all_primary_keys
        else
          primary_keys_that_are_objectid_columns = autodetect_columns_from(all_primary_keys, true)
        end
      end

      # Make sure we have at least one ObjectId primary key, if we're in this method.
      raise "Class #{active_record_class.name} has no columns in its primary key that qualify as object IDs automatically; you must specify their names explicitly." if primary_keys_that_are_objectid_columns.empty?

      # Make sure all the columns the user named actually exist as columns on the model.
      missing = primary_keys_that_are_objectid_columns.select { |c| ! active_record_class.columns_hash.has_key?(c) }
      raise "The following primary-key column(s) do not appear to actually exist on #{active_record_class.name}: #{missing.inspect}; we have these columns: #{active_record_class.columns_hash.keys.inspect}" unless missing.empty?

      # Declare our primary-key column as an ObjectId column.
      has_objectid_column *primary_keys_that_are_objectid_columns

      # Override #id and #id= to do the right thing...
      dynamic_methods_module.define_method("id") do
        self.class.objectid_columns_manager.read_objectid_primary_key(self)
      end
      dynamic_methods_module.define_method("id=") do |new_value|
        self.class.objectid_columns_manager.write_objectid_primary_key(self, new_value)
      end

      # Allow us to autogenerate the primary key, if needed, on save.
      active_record_class.send(:before_create, :assign_objectid_primary_key)

      # Override a couple of methods that, if you're using an ObjectId column as your primary key, need overriding. ;)
      [ :find, :find_by_id ].each do |class_method_name|
        @dynamic_methods_module.define_class_method(class_method_name) do |*args, &block|
          objectid_columns_manager.find_or_find_by_id(*args) { |*new_args| super(*new_args, &block) }
        end
      end
    end

    # Declares one or more columns as containing ObjectId values. After this call, they can be written using a String
    # in hex or binary formats, or an ObjectId object; they will return ObjectId objects for values, and can be queried
    # using any of the above (as long as you use the <tt>where(:foo_oid => ...)</tt> Hash-style syntax).
    #
    # If you don't pass in any column names, this will look for columns that end in +_oid+ and assume those are
    # ObjectId columns.
    def has_objectid_columns(*columns)
      return unless active_record_class.table_exists?

      # Autodetect columns ending in +_oid+ if needed
      columns = autodetect_columns_from(active_record_class.columns_hash.keys) if columns.length == 0

      columns = columns.map { |c| c.to_s.strip.downcase.to_sym }
      columns.each do |column_name|
        # Go fetch the column object from the ActiveRecord class, and make sure it's present and of the right type.
        column_object = active_record_class.columns.detect { |c| c.name.to_s == column_name.to_s }

        unless column_object
          raise ArgumentError, "#{active_record_class.name} doesn't seem to have a column named #{column_name.inspect} that we could make an ObjectId column; did you misspell it? It has columns: #{active_record_class.columns.map(&:name).inspect}"
        end

        unless [ :string, :binary ].include?(column_object.type)
          raise ArgumentError, "#{active_record_class.name} has a column named #{column_name.inspect}, but it is of type #{column_object.type.inspect}; we can only make ObjectId columns out of :string or :binary columns"
        end

        # Is the column long enough to contain the data we'll need to put in it?
        required_length = self.class.const_get("#{column_object.type.to_s.upcase}_OBJECTID_LENGTH")
        # The ||= is in case there's no limit on the column at all -- for example, PostgreSQL +bytea+ columns
        # behave this way.
        unless (column_object.limit || required_length + 1) >= required_length
          raise ArgumentError, "#{active_record_class.name} has a column named #{column_name.inspect} of type #{column_object.type.inspect}, but it is of length #{column_object.limit}, which is too short to contain an ObjectId of this format; it must be of length at least #{required_length}"
        end

        # Define reader and writer methods that just call through to ObjectidColumns::HasObjectidColumns (which, in
        # turn, just delegates the call back to this object -- the #read_objectid_column method below; the one on
        # HasObjectidColumns just passes through the model object itself).
        cn = column_name
        dynamic_methods_module.define_method(column_name) do
          read_objectid_column(cn)
        end

        dynamic_methods_module.define_method("#{column_name}=") do |x|
          write_objectid_column(cn, x)
        end

        # Store away the fact that we've done this.
        @oid_columns[column_name] = column_object.type
      end
    end

    # Called from ObjectidColumns::HasObjectidColumns#read_objectid_column -- given a model and a column name (which
    # must be an ObjectId column), returns the data in it, as an ObjectId.
    def read_objectid_column(model, column_name)
      column_name = column_name.to_s
      value = model[column_name]
      return value unless value # in case it's nil
      return value if ObjectidColumns.is_valid_bson_object?(value) # we can get this when reading the 'id' pseudocolumn

      # If it's not nil, the database should always be giving us back a String...
      unless value.kind_of?(String)
        raise "When trying to read the ObjectId column #{column_name.inspect} on #{active_record_class.name} ID=#{model.id.inspect}, we got the following data from the database; we expected a String: #{value.inspect}"
      end

      # ugh...ActiveRecord 3.1.x can return this in certain circumstances
      return nil if value.length == 0

      # In many databases, if you have a column that is, _e.g._, BINARY(16), and you only store twelve bytes in it,
      # you get back all 16 anyway, with 0x00 bytes at the end. Converting this to an ObjectId will fail, so we make
      # sure we chop those bytes off. (Note that while String#strip will, in fact, remove these bytes too, it is not
      # safe: if the ObjectId itself ends in one or more 0x00 bytes, then these will get incorrectly removed.)
      case type = objectid_column_type(column_name)
      when :binary then value = value[0..(BINARY_OBJECTID_LENGTH - 1)]
      when :string then value = value[0..(STRING_OBJECTID_LENGTH - 1)]
      else unknown_type(type)
      end

      # +lib/objectid_columns/extensions.rb+ adds this method to String.
      value.to_bson_id
    end

    # Called from ObjectidColumns::HasObjectidColumns#write_objectid_column -- given a model, a column name (which must
    # be an ObjectId column) and a new value, stores that value in the column.
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

    alias_method :has_objectid_column, :has_objectid_columns

    # Given a value for an ObjectId column -- could be a String in either hex or binary formats, or an
    # ObjectId object -- returns a String of the correct type for the given column (_i.e._, either the binary or hex
    # String representation of an ObjectId, depending on the type of the underlying column).
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

    # Given a key in a Hash supplied to +where+ for the given ActiveRecord class, returns a two-element Array
    # consisting of the key and the proper value we should actually use to query on that column. If the key does not
    # represent an ObjectID column, then this will just be exactly the data passed in; however, if it does represent
    # an ObjectId column, then the value will be translated to whichever String format (binary or hex) that column is
    # using.
    #
    # We use this in ObjectidColumns:;ActiveRecord::Relation#where to make the following work properly:
    #
    #     MyModel.where(:foo_oid => BSON::ObjectId('52ec126d78161f56d8000001'))
    #
    # This method is used to translate this to:
    #
    #     MyModel.where(:foo_oid => "52ec126d78161f56d8000001")
    def translate_objectid_query_pair(query_key, query_value)
      if (type = net_oid_columns[query_key.to_sym])

        # Handle nil, false
        if (! query_value)
          [ query_key, query_value ]

        # +lib/objectid_columns/extensions.rb+ adds String#to_bson_id
        elsif query_value.respond_to?(:to_bson_id)
          v = query_value.to_bson_id
          v = case type
          when :binary then v.to_binary
          when :string then v.to_s
          else unknown_type(type)
          end
          [ query_key, v ]

        # Handle arrays of values
        elsif query_value.kind_of?(Array)
          array = query_value.map do |v|
            translate_objectid_query_pair(query_key, v)[1]
          end
          [ query_key, array ]

        # Um...what did you pass?
        else
          raise ArgumentError, "You're trying to constrain #{active_record_class.name} on column #{query_key.inspect}, which is an ObjectId column, but the value you passed, #{query_value.inspect}, is not a valid format for an ObjectId."
        end
      else
        [ query_key, query_value ]
      end
    end

    # Given the name of a column, tell whether or not it is an ObjectId column.
    def is_objectid_column?(column_name)
      net_oid_columns.has_key?(column_name.to_sym)
    end

    # Returns the same thing as +oid_columns+, except merges in the ActiveRecord class's superclass's columns, if
    # any.
    def net_oid_columns
      out = { }
      if (socm = superclass_objectid_columns_manager)
        out = socm.net_oid_columns
      end
      out.merge(oid_columns)
    end

    private
    attr_reader :active_record_class, :dynamic_methods_module, :oid_columns

    # Given the name of a column -- which must be an ObjectId column -- returns its type, either +:binary+ or
    # +:string+.
    def objectid_column_type(column_name)
      out = net_oid_columns[column_name.to_sym]
      raise "Something is horribly wrong; #{column_name.inspect} is not an ObjectId column -- we have: #{net_oid_columns.keys.inspect}" unless out
      out
    end

    # If our +@active_record_class+ has a superclass that in turn is using +objectid_columns+, returns the
    # ObjectidColumnsManager for that class, if any.
    def superclass_objectid_columns_manager
      ar_superclass = @active_record_class.superclass
      ar_superclass.objectid_columns_manager if ar_superclass.respond_to?(:objectid_columns_manager)
    end

    # Raises an exception -- used for +case+ statements where we switch on the type of the column. Useful so that if,
    # in the future, we support a new column type, we won't forget to add a case for it in various places.
    def unknown_type(type)
      raise "Bug in ObjectidColumns in this method -- type #{type.inspect} does not have a case here."
    end

    # What's the entire superclass chain of the given class? Used in the constructor to make sure something is
    # actually a descendant of ActiveRecord::Base.
    def superclasses(klass)
      out = [ ]
      while (sc = klass.superclass)
        out << sc
        klass = sc
      end
      out
    end

    # If someone called +has_objectid_columns+ but didn't pass an argument, this method detects which columns we should
    # automatically turn into ObjectId columns -- which means any columns ending in +_oid+, except for the primary key.
    def autodetect_columns_from(column_names, allow_primary_key = false)
      column_names = column_names.map(&:to_s)
      out = column_names.select do |column_name|
        column = active_record_class.columns_hash[column_name]
        column && column.name =~ /_oid$/i
      end

      # Make sure we never, ever automatically make the primary-key column an ObjectId column.
      out -= Array(active_record_class.primary_key).compact.map(&:to_s) unless allow_primary_key

      unless out.length > 0
        raise ArgumentError, "You didn't pass in the names of any ObjectId columns, and we couldn't find any columns ending in _oid to pick up automatically (primary key is always excluded). Either name some columns explicitly, or remove the has_objectid_columns call. We found columns named: #{column_names.inspect}"
      end

      out
    end
  end
end
