# This file adds very useful convenience methods to certain classes:

# To each of the BSON classes, we add:
#
# * #to_binary, which returns a String containing a pure-binary (12-byte) representation of the ObjectId; and
# * #to_bson_id, which simply returns +self+ -- this is so we can call this method on any object passed in where we're
#   expecting an ObjectId, and, if you're already supplying an ObjectId object, it will just work.
ObjectidColumns.available_objectid_columns_bson_classes.each do |klass|
  klass.class_eval do
    def to_binary
      [ to_s ].pack("H*")
    end

    def to_bson_id
      self
    end
  end
end

# To String, we add #to_bson_id. This method knows how to convert a String that is in either the hex or pure-binary
# forms to an actual ObjectId object. Note that we use the method ObjectidColumns.construct_objectid to actually create
# the object; this way, it will follow any preference for exactly what BSON class to use that's set there.
#
# If your String is in binary form, it must have its encoding set to Encoding::BINARY (which is aliased to
# Encoding::ASCII_8BIT); if it's not in this encoding, it may well be coming from a source that doesn't support
# transparent binary data (for example, UTF-8 doesn't -- certain byte combinations are illegal in UTF-8 and will cause
# string manipulation to fail), which is a real problem.
String.class_eval do
  BSON_HEX_ID_REGEX = /^[0-9a-f]{24}$/i

  def to_bson_id
    if self =~ BSON_HEX_ID_REGEX
      ObjectidColumns.construct_objectid(self)
    elsif length == 12 && ((! respond_to?(:encoding)) || (encoding == Encoding::BINARY)) # :respond_to? is for Ruby 1.8.7 support
      ObjectidColumns.construct_objectid(unpack("H*").first)
    else
      encoding_string = respond_to?(:encoding) ? ", in encoding #{encoding.inspect}" : ""
      raise ArgumentError, "#{inspect} does not seem to be a valid BSON ID; it is in neither the valid hex (exactly 24 hex characters, any encoding) nor the valid binary (12 characters, binary/ASCII-8BIT encoding) form. It is #{length} characters long#{encoding_string}"
    end
  end
end
