require 'objectid_columns'

module ObjectidColumns
  module ActiveRecord
    module Relation
      extend ActiveSupport::Concern

      def where(*args)
        return super(*args) unless respond_to?(:has_objectid_columns?) && has_objectid_columns?
        return super(*args) unless args.length == 1 && args[0].kind_of?(Hash)

        query = { }
        args[0].each do |key, value|
          (key, value) = translate_objectid_query_pair(key, value)
          query[key] = value
        end

        super(query)
      end
    end
  end
end
