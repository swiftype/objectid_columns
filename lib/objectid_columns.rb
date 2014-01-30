require "objectid_columns/version"
require "objectid_columns/active_record/base"
require "objectid_columns/active_record/relation"
require "active_record"

module ObjectidColumns
  class << self
    def valid_objectid_bson_class_names
      %w{BSON::ObjectId Moped::BSON::ObjectId}
    end

    def preferred_bson_class
      available_objectid_columns_bson_classes.first
    end

    def available_objectid_columns_bson_classes
      %w{moped bson}.each do |require_name|
        begin
          require require_name
        rescue LoadError => le
        end
      end

      defined_classes = valid_objectid_bson_class_names.map do |name|
        eval("if defined?(#{name}) then #{name} end")
      end.compact

      if defined_classes.length == 0
        raise %{ObjectidColumns requires a library that implements an ObjectId class to be loaded -- either
BSON::ObjectId (from MongoMapper) or Moped::BSON::ObjectId (from Moped); you seem to have
neither one defined.

Please add one of these gems to your project and try again.}
      end

      defined_classes
    end

    def is_valid_bson_object?(x)
      available_objectid_columns_bson_classes.detect { |k| x.kind_of?(k) }
    end

    def construct_objectid(hex_string)
      klass = available_objectid_columns_bson_classes.first.name
      if klass =~ /^(.*)::([^:]+)$/i
        $1.constantize.send($2, hex_string)
      else
        raise "no go"
      end
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
