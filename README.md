# Elbenwald

Scout-Plugin for watching the number of "healthy" instances available on an AWS-ELB.

## Installation

Refer to https://scoutapp.com/info/creating_a_plugin

## Usage

### Options

* `elb_name` - (required) Name of the ELB
* `aws_credentials_path` - A YAML file with credentials for accessing the AWS (key names are same as in AWS-SDK).
* `error_log_path` - Path to error log file, where unhealthy instances will be logged.

### Metrics and error log

It provides a count of healthy instance for an ELB for a availability zone.
For example if you have an ELB `My-ELB` which has 1 healthy instance available in zone `eu-west-1a`
and one unhealthy and 2 healthy instances available in zone `eu-west-1b`,
then following metrics will be generated:

* `eu-west-1a`: 1.0
* `eu-west-1b`: 2.0
* `total`: 3.0
* `average`: 1.5
* `minimum`: 1.0

Each unhealthy instance will be notices in the error log like this:

`[0000-01-01 00:00:00 +0100] [My-ELB] [eu-west-1b] [iabc123] [Doesn't feel good...]`

## Development

```bash
$ bundle
$ ./bin/rspec
```
