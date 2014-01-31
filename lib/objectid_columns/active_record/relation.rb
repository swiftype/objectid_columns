require 'objectid_columns'

module ObjectidColumns
  module ActiveRecord
    # This module gets included into ActiveRecord::Relation; it is responsible for modifying the behavior of +where+.
    # Note that when you call +where+ directly on an ActiveRecord class, it (through various AR magic) ends up calling
    # ActiveRecord::Relation#where, so this takes care of that, too.
    module Relation
      extend ActiveSupport::Concern

      # There is really only one case where we
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
