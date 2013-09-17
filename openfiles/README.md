# Openfiles <sub><sub>by [Infopark](http://www.infopark.com) ![Infopark](../infopark.png)</sub></sub>

A Scout plugin to monitor the amount of open files of a specific user.


## Usage

### Prerequisites

The scout user on the machine has to have the right to `sudo lsof -u `_`user`_` | wc -l`.


### Options

* `name` - (required) The login for which the open files should be counted.


### Metrics

The amount of open files is reported as `open_files`.


## Development

```bash
$ bundle
$ bundle exec rspec *_spec.rb
```


## License

[LGPG-3.0](http://www.gnu.org/licenses/lgpl-3.0.html) License.
Copyright 2013 Infopark AG.
http://www.infopark.com
