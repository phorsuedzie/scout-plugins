# SWF Tasks <sub><sub>by [Infopark](http://www.infopark.com) ![Infopark](../infopark.png)</sub></sub>

A Scout plugin to monitor execution of AWS SWF. Detects
- queueing of executions (no worker cares)
- zombie executions (responsible worker has died silently)

To detect a zombie execution, the EC2 instance needs to be still
running and executing the plugin. There is no "the responsible
instance has died" detection (yet).


## Usage

### Prerequisites

The file `/home/scout/swf_tasks.yml` providing
- SWF configuration
- (optional) SWF access credentials (IAM roles are preferred...)
- (optional) stack id to distinguish equal hostnames on rolling deployment


```
---
simple_workflow_domain: 'ice-production'
simple_workflow_endpoint: 'swf.eu-west-1.amazonaws.com'
stack_id: <opsworks stack id>
```

### Metrics

The plugin reports the number of "waiting" executions and the number of zombies,
for every application as hard-coded into the plugin.

The application of an execution is derived from its "unit" (see
[ntswf](https://github.com/infopark/ntswf)).

If a suspicious execution cannot be resolved to an application, it is reported
for the application "unknown".

### Artefacts

Details about detected zombies are written to `/home/scout/swf_tasks.log`.

## Development

```bash
$ bundle
$ bundle exec rspec
```


## License

[LGPG-3.0](http://www.gnu.org/licenses/lgpl-3.0.html) License.
Copyright 1995 - 2014 Infopark AG.
http://www.infopark.com
