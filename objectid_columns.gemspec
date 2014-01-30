# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'objectid_columns/version'

Gem::Specification.new do |spec|
  spec.name          = "objectid_columns"
  spec.version       = ObjectidColumns::VERSION
  spec.authors       = ["Andrew Geweke"]
  spec.email         = ["ageweke@swiftype.com"]
  spec.summary       = %q{Transparely store MongoDB ObjectId values in ActiveRecord.}
  spec.homepage      = "https://www.github.com/swiftype/objectid_columns"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport", ">= 3.0", "<= 4.99.99"

  ar_version = ENV['OBJECTID_COLUMNS_AR_TEST_VERSION']
  ar_version = ar_version.strip if ar_version

  version_spec = case ar_version
  when nil then [ ">= 3.0", "<= 4.99.99" ]
  when 'master' then nil
  else [ "=#{ar_version}" ]
  end

  if version_spec
    spec.add_dependency("activerecord", *version_spec)
  end

  spec.add_dependency "active_record", [ ">= 3.0", "<= 4.99.99" ]

  spec.add_development_dependency "bundler", "~> 1.5"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec", "~> 2.14"
end
