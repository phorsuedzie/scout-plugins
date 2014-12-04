# Say Cheese! <sub><sub>by [Infopark](http://www.infopark.com) ![Infopark](../infopark.png)</sub></sub>

Scout-Plugin for watching the statistics of an elasticsearch snapshot.


## Installation

* Copy [the source](https://raw.github.com/infopark/scout-plugins/master/say_cheese/say_cheese.rb)
* Create a new private plugin in Scout-GUI
* Paste the code

Refer to [https://scoutapp.com/info/creating_a_plugin](https://scoutapp.com/info/creating_a_plugin)

## Usage

### Options

* `state_file` - (required) Path to the snapshot statistics file (see `create_snapshot.rb` in [infopark/elasticsearch_cookbooks](https://github.com/infopark/elasticsearch_cookbooks))

### Metrics

* `shards_total` - How many shards have been snapshotted in __total__. This can be `0`, if the reporting instance is not the master node.
* `shards_successful` - How many shards have been snapshotted __successfully__. This can be `0`, if the reporting instance is not the master node.
* `shards_failed` - How many shards have been __failed__ to snapshot.
* `snapshot_started_minutes_ago` - How many minutes passed since the last snapshot.
* `snapshot_duration_in_seconds` - How long the snapshot took in seconds.

## Development

```bash
$ bundle
$ bundle exec rspec
```

## License

[LGPG-3.0](http://www.gnu.org/licenses/lgpl-3.0.html) License.
Copyright 2014 Infopark AG.
http://www.infopark.com

