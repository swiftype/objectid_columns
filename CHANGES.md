# Change History for ObjectidColumns

### Version 1.0.3: June 11, 2014

* Fixed an issue where, if you tried to declare `has_objectid_primary_key` on a table that didn't exist (usually meaning it just hadn't been migrated into existence yet), you'd get an error. Now, we ignore this declaration.

### Version 1.0.2: April 14, 2014

* Fixed an issue where, if you tried to pass an ObjectID instance in a `where` clause for a column that didn't exist or wasn't on a table that declared any ObjectID columns, you could get an error from deep down in `ObjectidColumns`. (Now, you'll still get an error, but it will be the ActiveRecord error you expect, instead.)
* Rails 4.1 support.
* Bumped Travis version matrix to the latest point-releases of Rails 3.2 and 4.0.

### Version 1.0.1: March 7, 2014

* Compatibility with the [`composite_primary_keys`](https://github.com/composite-primary-keys/composite_primary_keys)
  gem, so that you can use object-ID columns as part of a composite primary key.
* Fixed an issue where you could not save an ActiveRecord model that had an ObjectId column as its primary key.
  Implemented this by teaching Arel how to deal with BSON ObjectIds, which should have broader benefits, too.
