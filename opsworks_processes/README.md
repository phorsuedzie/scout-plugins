# Logcheck <sub><sub>by [Infopark](http://www.infopark.com) ![Infopark](../infopark.png)</sub></sub>

A Scout plugin to monitor and restrict the amount of running Opsworks agents.


## Usage

### Prerequisites

The scout user on the machine has to have the right to `sudo /usr/bin/killall -9 opsworks-agent`.


### Metrics

The amount of Opsworks master proceses is reported as `master_count` and the total amount of
Opsworks processes is reported as `total_count`.

After ten sequent reports with a master count greater than one, all Opsworks processes are being
killed.
Thereupon one master will be started by monit and no ressources are being wasted by too many
Opsworks processes.


## Development

```bash
$ bundle
$ bundle exec rspec *_spec.rb
```


## License

[LGPG-3.0](http://www.gnu.org/licenses/lgpl-3.0.html) License.
Copyright 2013 Infopark AG.
http://www.infopark.com
