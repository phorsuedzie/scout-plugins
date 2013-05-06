# Elbenwald

Scout-Plugin for watching the number of "healthy" instances available on an AWS-ELB.

## Installation

Refer to https://scoutapp.com/info/creating_a_plugin

## Usage

### Options

* `aws_credentials_path` - A YAML file with credentials for accessing the AWS (key names are same as in AWS-SDK).
* `error_log_path` - Path to error log file, where unhealthy instances will be logged.

### Metrics and error log

It provides a count of healthy instance for an ELB for a availability zone.
For example if you have an ELB `My-ELB` which has 1 instance available in zone `eu-west-1a`
and 2 available in zone `eu-west-1b` then following metrics will be generated:

* `My-ELB-eu-west-1a`: 1
* `My-ELB-eu-west-1b`: 2

Each unhealthy instance will be notices in the error log like this:

`[0000-01-01 00:00:00 +0100] [My-ELB] [eu-west-1b] [iabc123] [Doesn't feel good...]`

## Development

```bash
$ bundle
$ ./bin/rspec
```
