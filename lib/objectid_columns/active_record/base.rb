require 'objectid_columns'
require 'active_support'
require 'objectid_columns/has_objectid_columns'

module ObjectidColumns
  module ActiveRecord
    # This module gets included into ActiveRecord::Base when ObjectidColumns loads. It is just a "trampoline" -- the
    # first time you call one of its methods, it includes ObjectidColumns::HasObjectidColumns into your model, and
    # then re-calls the method. (This looks like infinite recursion, but isn't, because once we include the module,
    # its implementation takes precedence over ours -- because we will always be a module earlier on the inheritance
    # chain, since we by definition were included before ObjectidColumns::HasObjectidColumns.)
    module Base
      extend ActiveSupport::Concern

      module ClassMethods
        # Do we have any ObjectId columns? This is always false -- once we include ObjectidColumns::HasObjectidColumns,
        # its implementation (which just returns 'true') takes precedence.
        def has_objectid_columns?
          false
        end

        # These are our "trampoline" methods -- the methods that you should be able to call on an ActiveRecord class
        # that has never had any ObjectidColumns-related methods called on it before, that bootstrap the process.
        [ :has_objectid_columns, :has_objectid_column, :has_objectid_primary_key ].each do |method_name|
          define_method(method_name) do |*args|
            include ::ObjectidColumns::HasObjectidColumns
            send(method_name, *args)
          end
        end
      end
    end
  end
end
