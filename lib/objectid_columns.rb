require "objectid_columns/version"
require "objectid_columns/active_record/base"
require "objectid_columns/active_record/relation"
require "active_record"

# This is the root module for ObjectidColumns. It contains largely just configuration and integration information;
# all the real work is done in ObjectidColumns::ObjectidColumnsManager. ObjectidColumns gets its start through the
# module ObjectidColumns::ActiveRecord::Base, which gets mixed into ::ActiveRecord::Base (below) and is where methods
# like +has_objectid_columns+ are declared.
module ObjectidColumns
  class << self
    # This is the set of classes we support for representing ObjectIds, as objects, themselves. BSON::ObjectId comes
    # from the +bson+ gem, and Moped::BSON::ObjectId comes from the +moped+ gem.
    #
    # Note that this gem does not declare a dependency on either one of these gems, because we want you to be able to
    # use either, and there's currently no way of expressing that explicitly. Instead,
    # .available_objectid_columns_bson_classes, below, takes care of figuring out which ones are availble and loading
    # them.
    #
    # Order is important here: when creating new ObjectId objects (such as when reading from an ObjectId column), we
    # will prefer the earliest one of these classes that is actually defined. You can change this using
    # .preferred_bson_class=, below.
    #
    #
    # Any class added here has to obey the following constraints:
    #
    # * You can create a new instance from a hex string using .from_string(hex_string)
    # * Calling #to_s on it returns a hexadecimal String of exactly 24 characters
    #
    # Both these objects currently do. If they change, or you want to introduce a new ObjectId representation class,
    # a small amount of refactoring will be necessary.
    SUPPORTED_OBJECTID_BSON_CLASS_NAMES = %w{BSON::ObjectId Moped::BSON::ObjectId}

    # When we create a new ObjectId object (such as when reading from a column), what class should it be? If you have
    # multiple classes loaded and you don't like this one, you can call .preferred_bson_class=, below.
    def preferred_bson_class
      @preferred_bson_class ||= available_objectid_columns_bson_classes.first
    end

    # Sets the preferred BSON class to the given class.
    def preferred_bson_class=(bson_class)
      unless SUPPORTED_OBJECTID_BSON_CLASS_NAMES.include?(bson_class.name)
        raise ArgumentError, "ObjectidColumns does not support BSON class #{bson_class.name}; it supports: #{SUPPORTED_OBJECTID_BSON_CLASS_NAMES.inspect}"
      end

      @preferred_bson_class = bson_class
    end

    # Returns an array of Class objects -- of length at least 1, but potentially more than 1 -- of the various
    # ObjectId classes we have available to use. Again, because we don't explicitly depend on the BSON gems
    # (see above), this needs to take care of trying to load and require the gems in question, and fail gracefully
    # if they're not present.
    def available_objectid_columns_bson_classes
      @available_objectid_columns_bson_classes ||= begin
        # Try to load both gems, but don't fail if there are errors
        %w{moped bson}.each do |require_name|
          begin
            gem require_name
          rescue Gem::LoadError => le
          end

          begin
            require require_name
          rescue LoadError => le
          end
        end

        # See which classes we have managed to load
        defined_classes = SUPPORTED_OBJECTID_BSON_CLASS_NAMES.map do |name|
          eval("if defined?(#{name}) then #{name} end")
        end.compact

        # Raise an error if we haven't loaded either
        if defined_classes.length == 0
          raise %{ObjectidColumns requires a library that implements an ObjectId class to be loaded; we support
the following ObjectId classes: #{SUPPORTED_OBJECTID_BSON_CLASS_NAMES.join(", ")}.
(These are from the 'bson' or 'moped' gems.) You seem to have neither one installed.

Please add one of these gems to your project and try again. Usually, this just means
adding this to your Gemfile:

gem 'bson'

(ObjectidColumns does not explicitly depend on either of these, because we want you
to be able to choose whichever one you prefer.)}
        end

        defined_classes
      end
    end

    # Is the given object a valid BSON ObjectId? This doesn't count Strings in any format -- only objects.
    def is_valid_bson_object?(x)
      available_objectid_columns_bson_classes.detect { |k| x.kind_of?(k) }
    end

    # Creates a new BSON ObjectId from the given String, which must be in the hexadecimal format.
    def construct_objectid(hex_string)
      preferred_bson_class.send(:from_string, hex_string)
    end

    # Creates a new BSON ObjectId, from scratch; this must return an ObjectId with a value, suitable for assigning
    # to a newly-created row. We use this only if you've declared that your primary key column is an ObjectId, and
    # then only if you're about to save a new row and it has no ID yet.
    def new_objectid
      preferred_bson_class.new
    end
  end
end

# Include the modules that add the initial methods to ActiveRecord::Base, like +has_objectid_columns+.
::ActiveRecord::Base.class_eval do
  include ::ObjectidColumns::ActiveRecord::Base
end

# This adds our patch to +#where+, so that queries will work properly (assuming you use Hash-style syntax).
::ActiveRecord::Relation.class_eval do
  include ::ObjectidColumns::ActiveRecord::Relation
end

require "objectid_columns/extensions"
