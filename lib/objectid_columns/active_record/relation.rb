require 'objectid_columns'

module ObjectidColumns
  module ActiveRecord
    # This module gets included into ActiveRecord::Relation; it is responsible for modifying the behavior of +where+.
    # Note that when you call +where+ directly on an ActiveRecord class, it (through various AR magic) ends up calling
    # ActiveRecord::Relation#where, so this takes care of that, too.
    module Relation
      extend ActiveSupport::Concern

      # There is really only one case where we can transparently modify queries -- where you're using hash syntax:
      #
      #     model.where(:foo_oid => <objectID>)
      #
      # If you're using SQL string syntax:
      #
      #     model.where("foo_oid = ?", <objectID>)
      #
      # ...then there's no way to reliably determine what should be converted as an ObjectId (and, critically, to what
      # format -- hex or binary -- we should convert it). As such, we leave the responsibility for that case up to
      # the user.
      def where(*args)
        # Bail out if we don't have any ObjectId columns
        return super(*args) unless respond_to?(:has_objectid_columns?) && has_objectid_columns?
        # Bail out if we're not using the Hash form
        return super(*args) unless args.length == 1 && args[0].kind_of?(Hash)

        query = { }
        args[0].each do |key, value|
          # #translate_objectid_query_pair is a method defined on the ObjectidColumns::ObjectidColumnsManager, and is
          # called via the delegation defined in ObjectidColumns::HasObjectidColumns.
          (key, value) = translate_objectid_query_pair(key, value)
          query[key] = value
        end

        super(query)
      end
    end
  end
end
