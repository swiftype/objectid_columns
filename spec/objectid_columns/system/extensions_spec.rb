require 'objectid_columns'

unless defined?(VALID_OBJECTID_CLASSES)
  VALID_OBJECTID_CLASSES = [ BSON::ObjectId ]
  VALID_OBJECTID_CLASSES << Moped::BSON::ObjectId if defined?(Moped::BSON::ObjectId)
end

describe "Objectid extensions" do
  HEX = "0123456789abcdef"

  def hex(length)
    out = ""
    length.times { out << HEX[rand(HEX.length)] }
    out
  end

  def binary(length)
    out = ""
    out.force_encoding(Encoding::BINARY) if out.respond_to?(:encoding)
    length.times { out << rand(256).chr }
    out
  end

  describe "String extensions" do
    it "should raise an error on invalid cases" do
      expect { "foo".to_bson_id }.to raise_error(ArgumentError)
      expect { hex(23).to_bson_id }.to raise_error(ArgumentError)
      expect { hex(25).to_bson_id }.to raise_error(ArgumentError)
      expect { binary(11).to_bson_id }.to raise_error(ArgumentError)
      expect { binary(13).to_bson_id }.to raise_error(ArgumentError)

      if "".respond_to?(:encoding)
        wrong_encoding = binary(12)
        wrong_encoding.force_encoding(Encoding::ISO_8859_1)
        expect { wrong_encoding.to_bson_id }.to raise_error(ArgumentError)
      end
    end
  end

  VALID_OBJECTID_CLASSES.each do |test_class|
    context "using BSON class #{test_class.name}" do
      before :each do
        @tc = test_class
        ObjectidColumns.preferred_bson_class = test_class
      end

      it "should convert Strings to the class correctly" do
        h = hex(24)
        h.to_bson_id.class.should == @tc
        h.to_bson_id.to_s.should == h

        b = binary(12)
        b.to_bson_id.class.should == @tc
        b.to_bson_id
      end

      it "should convert the class to binary correctly" do
        b = binary(12)
        object_id = b.to_bson_id
        object_id.to_binary.should == b
      end

      it "should just return self for #to_bson_id" do
        oid = @tc.new
        oid.to_bson_id.should be(oid)
      end
    end
  end
end
