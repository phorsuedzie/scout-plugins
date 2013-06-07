# Elbenwald

[![Build Status](https://travis-ci.org/kostia/scout-elbenwald.png)](https://travis-ci.org/kostia/scout-elbenwald)
[![Code Climate](https://codeclimate.com/github/kostia/scout-elbenwald.png)](https://codeclimate.com/github/kostia/scout-elbenwald)

![Elbenwald](https://raw.github.com/kostia/scout-elbenwald/master/elbenwald.png)

Scout-Plugin for watching the number of "healthy" instances available on an AWS-ELB.

## Installation

* Copy [the source](https://raw.github.com/kostia/scout-elbenwald/master/elbenwald.rb)
* Create a new private plugin in Scout-GUI
* Paste the code

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

```
Eu-west-1a: 1.0
Eu-west-1b: 2.0
Total:      3.0
Average:    1.5
Minimum:    1.0
```

Each unhealthy instance will be notices in the error log like this:

`[0000-01-01 00:00:00 +0100] [My-ELB] [eu-west-1b] [iabc123] [Doesn't feel good...]`

## Development

```bash
$ bundle
$ ./bin/rspec
```
