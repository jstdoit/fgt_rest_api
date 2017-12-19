# FGT::RestApi

Welcome to fgt_rest_api! In this directory, you'll find the files you need to be able to package up fgt_rest_api into a gem. Put your Ruby code in the file `lib/fgt_rest_api`. To experiment with that code, run `bin/console` for an interactive prompt.

TODO: Delete this and the text above, and describe your gem

## Installation

### current release

This gem has not been released to rubygems, yet. There is much work to do on documentation and some refactoring as well.

Checkout the tree from https://github.com/fuegito/fgt_rest_api.git.
Chdir in the repo-dir and do a "rake build".
After that, do "gem install pkg/fgt_rest_api-<VERSION>.gem".
Now you can use this gem as described below in 'Usage'.


### This Part is for later usage (1.0.0)

Add this line to your application's Gemfile:

```ruby
gem 'fgt_rest_api'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install fgt_rest_api

## Usage

require 'fgt_rest_api'

demo = FGT::RestApi.new(ip: 'fortigate.fortidemo.com', port: 443, username: 'demo', password: 'demo')

demo.timeout = 10

addresses = demo.cmdb_get(path: 'firewall', name: 'address')['results']

addresses.first.type ( == addresses.first['type'] == addresses.first[:type])
-> "wildcard-fqdn"

You can access the objects with the original key delivered from the JSON API (object['start-ip']) or with smybols (object[:start_ip]) or with attribute methods (object.start_ip).

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/fuegito/fgt_rest_api.
