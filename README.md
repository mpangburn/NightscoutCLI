# Nightscout CLI

[![Swift 4.0](https://img.shields.io/badge/Swift-4.0-orange.svg?style=flat)](#)
[![MIT](https://img.shields.io/packagist/l/doctrine/orm.svg)](https://github.com/mpangburn/NightscoutCLI/blob/master/LICENSE)
[![@pangburnout](https://img.shields.io/badge/contact-@pangburnout-blue.svg?style=flat)](https://twitter.com/pangburnout)

A simple command-line interface for viewing [Nightscout](https://github.com/nightscout/cgm-remote-monitor/) data. 

Built with [NightscoutKit](https://github.com/mpangburn/NightscoutKit).

## Installation
```
mkdir NightscoutCLI
cd NightscoutCLI
git clone https://github.com/mpangburn/NightscoutCLI.git
make
```
The created program, `ns`, will look for the `NS_SITE` environment variable if its first argument is not a URL. For easier access to your Nightscout data, add

`export NS_SITE=YOUR-NIGHTSCOUT-URL`

to your `~/.bash_profile`.

## Usage
```
OVERVIEW: Display recent Nightscout entries, treatments, and device statuses

USAGE: ns [url] [options]
  If no url is specified, the environment variable NS_SITE
  will be checked for the Nightscout URL.
  If no options are specified, 10 blood glucose entries will be displayed.

OPTIONS:
  --entries, -e     Display blood glucose entries [default: 10]
  --treatments, -t  Display treatments [default: 10]
  --devices, -d     Display device statuses
  --help            Display available options
```

## License
NightscoutCLI is released under the MIT license. See [LICENSE](https://github.com/mpangburn/NightscoutCLI/blob/master/LICENSE) for details.