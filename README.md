# AutoMarcDates (plugin for Koha)

This Koha plugin automatically puts creation and modification dates into the
MARC record whenever the MARC record is updated. It works for both
bibliographic and authority records.

## Installation

**IMPORTANT:** This plugin relies on `object_store_pre` hook, which is added by
[Bug 28173](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=28173).
Make sure you have this patch.
For authorities, you will also need
[Bug 28186](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=28186)

Once you've made sure you have those patches, you can install the plugin:

1. Clone the repository and add its path to `pluginsdir` in `$KOHA_CONF`
2. Flush or restart memcached
3. Run `misc/devel/install_plugins.pl`

## Configuration

From the main plugin page (`/plugins/plugins-home.pl`) you can go to the plugin
configuration page (Actions » Configure).

There you can enable the automatic modification of MARC records for
bibliographic records, authority records, or both.
You can also specify in which MARC field each date should go.

When you're done, click on the "Save configuration" button.

## How it works

Whenever a Koha::Biblio::Metadata or a Koha::Authority object is `store`d in
database, its corresponding MARC::Record is updated:
- The field chosen for modification date is set to the current date
  (`YYYY-MM-DD`)
- The field chosen for creation date is set to either `biblio.datecreated` or
  `auth_header.datecreated` (`YYYY-MM-DD`), but only if the field does not exist
  (the field is not overwritten)

The MARC::Record modifications happen just before the data are sent to the
database, so there's no additional INSERT/UPDATE query

## Known bugs / Limitations

- Control fields (001-009) are not supported

## License

MIT
