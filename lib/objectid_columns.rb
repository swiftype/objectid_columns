require "objectid_columns/version"
require "objectid_columns/active_record/base"
require "objectid_columns/active_record/relation"
require "active_record"

module ObjectidColumns
  class << self
    # Note: Any class added here has to obey the following constraints:
    #
    # * You can create a new instance from a hex string using .from_string(hex_string)
    # * Calling #to_s on it
    SUPPORTED_OBJECTID_BSON_CLASS_NAMES = %w{BSON::ObjectId Moped::BSON::ObjectId}

    def preferred_bson_class
      @preferred_bson_class ||= available_objectid_columns_bson_classes.first
    end

    def preferred_bson_class=(bson_class)
      unless SUPPORTED_OBJECTID_BSON_CLASS_NAMES.include?(bson_class.name)
        raise ArgumentError, "ObjectidColumns does not support BSON class #{bson_class.name}; it supports: #{SUPPORTED_OBJECTID_BSON_CLASS_NAMES.inspect}"
      end
    end

    # Returns an array of Class objects -- of length at least 1, but potentially more than 1 -- of the various
    # ObjectId classes we have available to use.
    def available_objectid_columns_bson_classes
      @available_objectid_columns_bson_classes ||= begin
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

        defined_classes = SUPPORTED_OBJECTID_BSON_CLASS_NAMES.map do |name|
          eval("if defined?(#{name}) then #{name} end")
        end.compact

        if defined_classes.length == 0
          raise %{ObjectidColumns requires a library that implements an ObjectId class to be loaded; we support
  the following ObjectId classes: #{SUPPORTED_OBJECTID_BSON_CLASS_NAMES.join(", ")}.
  (These are from the 'bson' or 'moped' gems.) You seem to have neither one installed.

  Please add one of these gems to your project and try again.}
        end

        defined_classes
      end
    end

    def is_valid_bson_object?(x)
      available_objectid_columns_bson_classes.detect { |k| x.kind_of?(k) }
    end

    def construct_objectid(hex_string)
      preferred_bson_class.send(:from_string, hex_string)
    end
  end
end

::ActiveRecord::Base.class_eval do
  include ::ObjectidColumns::ActiveRecord::Base
end

::ActiveRecord::Relation.class_eval do
  include ::ObjectidColumns::ActiveRecord::Relation
end

require "objectid_columns/extensions"
