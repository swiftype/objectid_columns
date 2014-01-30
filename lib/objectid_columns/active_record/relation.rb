require 'objectid_columns'

module ObjectidColumns
  module ActiveRecord
    module Relation
      def where(*args)
        return super(*args) unless respond_to?(:has_objectid_columns?) && has_objectid_columns?
        return super(*args) unless args.length == 1 && args[0].kind_of?(Hash)

        query = { }
        args[0].each do |key, value|
          objectid_column = objectid_column_object_for(key)
          if objectid_column
            query[key] = objectid_column.query_value_for(value)
          else
            query[key] = value
          end
        end

        super(query)
      end
    end
  end
end
