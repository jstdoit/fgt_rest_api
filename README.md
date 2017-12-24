# FGT::RestApi v0.0.7

Welcome to fgt_rest_api!

## Installation

This gem has not been released to rubygems, yet. There is much work to do on documentation and some refactoring as well.

Checkout the tree from https://github.com/fuegito/fgt_rest_api.git.
Chdir in the repo-dir and do a "rake build".
After that, do "gem install pkg/fgt_rest_api-0.0.7.gem".
Now you can use this gem as described below in 'Usage'.

## Usage

Run IRB and:

    require 'fgt_rest_api'
    demo = FGT::RestApi.new(ip: 'fortigate.fortidemo.com', port: 443, username: 'demo', password: 'demo')
    demo.timeout = 10 #  -> default is 5s
    addresses = demo.cmdb_get(path: 'firewall', name: 'address').results
    addresses.first.type    -> "wildcard-fqdn"
    addresses.first['type'] -> "wildcard-fqdn"
    addresses.first[:type]  -> "wildcard-fqdn"

You can access the objects with the original key delivered from the JSON API (object['start-ip']) or with smybols (object[:start_ip]) or with attribute methods (object.start_ip).
Note that you need to replace dashes with underscores in the latter two.

## Extensions

I created some extensions for FGT::RestApi. These will provide you shortcut methods for accessing some config objects.
Have a look at the policy_and_object extension.

### system.rb

### interface.rb

### ipsec.rb

### router.rb

### policy_and_object.rb


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/fuegito/fgt_rest_api.
