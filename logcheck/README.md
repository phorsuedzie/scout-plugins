# Logcheck

A Scout plugin to monitor a logfile and alert any lines not matched by a list of customized whitelist patterns.


## Usage

### Options

* `log_path` - (required) The full path to the the log file.
* `ignore` - A string containing all the line patterns to ignore.
   Due to the denial of Scout to add support for textarea input fields, this list is separated by the character '↓'.
   In `Scout-UI-Enhancer` you will find a Greasemonkey script which provides a textarea and takes care of the '↓'.
   

### Metrics and error log

All non-empty lines not matching any of the ignore patterns are alerted.
The plugin provides a count of reported lines under the key `lines_reported`.


## Development

```bash
$ bundle
$ bundle exec rspec *_spec.rb
```


## License

[LGPG-3.0](http://www.gnu.org/licenses/lgpl-3.0.html) License.
Copyright 2013 Infopark AG.
http://www.infopark.com
