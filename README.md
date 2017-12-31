# FGT::RestApi v0.0.9

Welcome to fgt_rest_api!

## Installation

This gem has not been released to rubygems, yet. There is much work to do on documentation and some refactoring as well.

Checkout the tree from https://github.com/fuegito/fgt_rest_api.git.
Chdir in the repo-dir and do a "rake build".
After that, do "gem install pkg/fgt_rest_api-0.0.9.gem".
Now you can use this gem as described below in 'Usage'.

## Usage

### Attributes & their defaults

- api_version: 'v2'           ==> I anticipated this attribute for future REST API version. Use the default.
- url_schema: 'https'         ==> I guess most users will nedd https, http has not been tested, yet. When in doubt, use the default.
- ip: MANDATORY               ==> IP or resolvable hostname of your FortiGate Device.
- port: 443                   ==> Remote port of FortiGate REST API.
- username: MANDATORY         ==> make an educated guess...
- password: MANDATORY         ==> make an educated guess...
- timeout: 5                  ==> How long will it take for timing out an request and do a retry.
- proxy: ENV['http_proxy']    ==> Access via proxy has not been tested, yet.
- use_proxy: false            ==> Proxy will only be used if this is set to true.
- debug: false                ==> If set to true, some debug messages will appear on STDERR.
- safe_mode: true             ==> Default is true (and it means read-only access). This means that anything other than a GET request will throw an exception.
- retry_counter: 3            ==> How many retries will there be after a timeout before an exception is thrown.
- use_vdom: 'root'            ==> Set VDOM here. If you don't use VDOMs on your FortiGate device, 'root' is always correct.

### Example: connection to https://fortigate.fortidemo.com

Run IRB:

    irb(main):001:0> require 'fgt_rest_api'
    irb(main):002:0> demo = FGT::RestApi.new(ip: 'fortigate.fortidemo.com', username: 'demo', password: 'demo')
    irb(main):003:0> demo.timeout = 10  # ==> default is 5s, but fortidemo is slow...
    irb(main):004:0> addresses = demo.cmdb_get(path: 'firewall', name: 'address').results
    irb(main):005:0> p addresses.first
    {"name"=>"*.google.com", "q_origin_key"=>"*.google.com", "uuid"=>"089fafbe-4d63-51e7-bd51-b41dc40375d1", "subnet"=>"0.0.0.0 0.0.0.0", "type"=>"wildcard-fqdn",     "start-ip"=>"0.0.0.0", "end-ip"=>"0.0.0.0", "fqdn"=>"*.google.com", "country"=>"", "wildcard-fqdn"=>"*.google.com", "cache-ttl"=>0, "wildcard"=>"0.0.0.0 0.0.0.0",  "sdn"=>"", "tenant"=>"", "organization"=>"", "epg-name"=>"", "subnet-name"=>"", "sdn-tag"=>"", "policy-group"=>"", "comment"=>"", "visibility"=>"enable",     "associated-interface"=>"", "color"=>0, "obj-id"=>0, "list"=>[], "tags"=>[], "allow-routing"=>"disable"}

Accessing the attributes (set and get) is indifferent (attribute methods are generated on-the-fly).

- addresses.first.type    --> "wildcard-fqdn"
- addresses.first['type'] --> "wildcard-fqdn"
- addresses.first[:type]  --> "wildcard-fqdn"

You can access the objects with the original key delivered from the JSON API (object['start-ip']) or with smybols (object[:start_ip]) or with attribute methods (object.start_ip).
Note that you need to replace dashes with underscores in the latter two.

## Extensions

I created some extensions for FGT::RestApi. These will provide you shortcut methods for accessing some config objects.
Have a look at the policy_and_object extension and it's example use in bin/fgt_policy2xlsx.rb.

### system.rb

    irb(main):006:0> require 'fgt_rest_api/ext/system'

    irb(main):007:0>  p demo.hostname
    "Demo-NGFW-PRI"

    irb(main):007:0> p demo.vdoms
    ["root"]

### interface.rb

    irb(main):008:0> require 'fgt_rest_api/ext/interface'

    irb(main):009:0> p demo.interface.first
    {"name"=>"FITNUC", "q_origin_key"=>"FITNUC", "vdom"=>"root", "cli-conn-status"=>0, "fortilink"=>"disable", "mode"=>"static", "distance"=>5, "priority"=>0, "dhcp-relay-service"=>"disable", "dhcp-relay-ip"=>"", "dhcp-relay-type"=>"regular", "dhcp-relay-agent-option"=>"enable", "management-ip"=>"0.0.0.0 0.0.0.0", "ip"=>"10.100.1.254 255.255.255.0", "allowaccess"=>"ssh", "gwdetect"=>"disable", "ping-serv-status"=>0, "detectserver"=>"", "detectprotocol"=>"ping", "ha-priority"=>1, "fail-detect"=>"disable", "fail-detect-option"=>"link-down", "fail-alert-method"=>"link-down", "fail-action-on-extender"=>"soft-restart", "fail-alert-interfaces"=>[], "dhcp-client-identifier"=>"", "dhcp-renew-time"=>0, "ipunnumbered"=>"0.0.0.0", "username"=>"", "pppoe-unnumbered-negotiate"=>"enable", "password"=>"", "idle-timeout"=>0, "detected-peer-mtu"=>0, "disc-retry-timeout"=>1, "padt-retry-timeout"=>1, "service-name"=>"", "ac-name"=>"", "lcp-echo-interval"=>5, "lcp-max-echo-fails"=>3, "defaultgw"=>"enable", "dns-server-override"=>"enable", "auth-type"=>"auto", "pptp-client"=>"disable", "pptp-user"=>"", "pptp-password"=>"", "pptp-server-ip"=>"0.0.0.0", "pptp-auth-type"=>"auto", "pptp-timeout"=>0, "arpforward"=>"enable", "ndiscforward"=>"enable", "broadcast-forward"=>"disable", "bfd"=>"global", "bfd-desired-min-tx"=>250, "bfd-detect-mult"=>3, "bfd-required-min-rx"=>250, "l2forward"=>"disable", "icmp-redirect"=>"enable", "vlanforward"=>"disable", "stpforward"=>"disable", "stpforward-mode"=>"rpl-all-ext-id", "ips-sniffer-mode"=>"disable", "ident-accept"=>"disable", "ipmac"=>"disable", "subst"=>"disable", "macaddr"=>"00:00:00:00:00:00", "substitute-dst-mac"=>"00:00:00:00:00:00", "speed"=>"auto", "status"=>"up", "netbios-forward"=>"disable", "wins-ip"=>"0.0.0.0", "type"=>"vlan", "dedicated-to"=>"none", "trust-ip-1"=>"0.0.0.0 0.0.0.0", "trust-ip-2"=>"0.0.0.0 0.0.0.0", "trust-ip-3"=>"0.0.0.0 0.0.0.0", "trust-ip6-1"=>"::/0", "trust-ip6-2"=>"::/0", "trust-ip6-3"=>"::/0", "mtu-override"=>"disable", "mtu"=>1500, "wccp"=>"disable", "netflow-sampler"=>"disable", "sflow-sampler"=>"disable", "drop-overlapped-fragment"=>"disable", "drop-fragment"=>"disable", "scan-botnet-connections"=>"disable", "src-check"=>"enable", "sample-rate"=>2000, "polling-interval"=>20, "sample-direction"=>"both", "explicit-web-proxy"=>"disable", "explicit-ftp-proxy"=>"disable", "proxy-captive-portal"=>"disable", "tcp-mss"=>0, "mediatype"=>"serdes-sfp", "inbandwidth"=>0, "outbandwidth"=>0, "spillover-threshold"=>0, "ingress-spillover-threshold"=>0, "weight"=>0, "interface"=>"FSW-AGG", "external"=>"disable", "vlanid"=>111, "forward-domain"=>0, "remote-ip"=>"0.0.0.0 0.0.0.0", "member"=>[], "lacp-mode"=>"active", "lacp-ha-slave"=>"enable", "lacp-speed"=>"slow", "min-links"=>1, "min-links-down"=>"operational", "algorithm"=>"L4", "link-up-delay"=>50, "priority-override"=>"enable", "aggregate"=>"", "redundant-interface"=>"", "managed-device"=>[], "devindex"=>59, "vindex"=>0, "switch"=>"", "description"=>"", "alias"=>"", "security-mode"=>"none", "captive-portal"=>0, "security-mac-auth-bypass"=>"disable", "security-external-web"=>"", "security-external-logout"=>"", "replacemsg-override-group"=>"", "security-redirect-url"=>"", "security-exempt-list"=>"", "security-groups"=>[], "device-identification"=>"enable", "device-user-identification"=>"enable", "device-identification-active-scan"=>"enable", "device-access-list"=>"", "lldp-transmission"=>"vdom", "fortiheartbeat"=>"enable", "broadcast-forticlient-discovery"=>"disable", "endpoint-compliance"=>"disable", "estimated-upstream-bandwidth"=>0, "estimated-downstream-bandwidth"=>0, "vrrp-virtual-mac"=>"disable", "vrrp"=>[], "role"=>"lan", "snmp-index"=>54, "secondary-IP"=>"disable", "secondaryip"=>[], "preserve-session-route"=>"disable", "auto-auth-extension-device"=>"disable", "ap-discover"=>"enable", "fortilink-stacking"=>"enable", "fortilink-split-interface"=>"disable", "internal"=>0, "fortilink-backup-link"=>0, "switch-controller-access-vlan"=>"disable", "switch-controller-igmp-snooping"=>"disable", "switch-controller-dhcp-snooping"=>"disable", "switch-controller-dhcp-snooping-verify-mac"=>"disable", "switch-controller-dhcp-snooping-option82"=>"disable", "switch-controller-auth"=>"usergroup", "switch-controller-radius-server"=>"", "color"=>11, "ipv6"=>{"ip6-mode"=>"static", "nd-mode"=>"basic", "nd-cert"=>"", "nd-security-level"=>0, "nd-timestamp-delta"=>300, "nd-timestamp-fuzz"=>1, "nd-cga-modifier"=>"0065636473612D776974682D73686132", "ip6-dns-server-override"=>"enable", "ip6-address"=>"::/0", "ip6-extra-addr"=>[], "ip6-allowaccess"=>"", "ip6-send-adv"=>"disable", "ip6-manage-flag"=>"disable", "ip6-other-flag"=>"disable", "ip6-max-interval"=>600, "ip6-min-interval"=>198, "ip6-link-mtu"=>0, "ip6-reachable-time"=>0, "ip6-retrans-time"=>0, "ip6-default-life"=>1800, "ip6-hop-limit"=>0, "autoconf"=>"disable", "ip6-upstream-interface"=>"", "ip6-subnet"=>"::/0", "ip6-prefix-list"=>[], "ip6-delegated-prefix-list"=>[], "dhcp6-relay-service"=>"disable", "dhcp6-relay-type"=>"regular", "dhcp6-relay-ip"=>"", "dhcp6-client-options"=>"", "dhcp6-prefix-delegation"=>"disable", "dhcp6-information-request"=>"disable", "dhcp6-prefix-hint"=>"::/0", "dhcp6-prefix-hint-plt"=>604800, "dhcp6-prefix-hint-vlt"=>2592000}}

    irb(main):010:0> p demo.interface_by_name("FITNUC")
    {"name"=>"FITNUC", "q_origin_key"=>"FITNUC", "vdom"=>"root", "cli-conn-status"=>0, "fortilink"=>"disable", "mode"=>"static", "distance"=>5, "priority"=>0, "dhcp-relay-service"=>"disable", "dhcp-relay-ip"=>"", "dhcp-relay-type"=>"regular", "dhcp-relay-agent-option"=>"enable", "management-ip"=>"0.0.0.0 0.0.0.0", "ip"=>"10.100.1.254 255.255.255.0", "allowaccess"=>"ssh", "gwdetect"=>"disable", "ping-serv-status"=>0, "detectserver"=>"", "detectprotocol"=>"ping", "ha-priority"=>1, "fail-detect"=>"disable", "fail-detect-option"=>"link-down", "fail-alert-method"=>"link-down", "fail-action-on-extender"=>"soft-restart", "fail-alert-interfaces"=>[], "dhcp-client-identifier"=>"", "dhcp-renew-time"=>0, "ipunnumbered"=>"0.0.0.0", "username"=>"", "pppoe-unnumbered-negotiate"=>"enable", "password"=>"", "idle-timeout"=>0, "detected-peer-mtu"=>0, "disc-retry-timeout"=>1, "padt-retry-timeout"=>1, "service-name"=>"", "ac-name"=>"", "lcp-echo-interval"=>5, "lcp-max-echo-fails"=>3, "defaultgw"=>"enable", "dns-server-override"=>"enable", "auth-type"=>"auto", "pptp-client"=>"disable", "pptp-user"=>"", "pptp-password"=>"", "pptp-server-ip"=>"0.0.0.0", "pptp-auth-type"=>"auto", "pptp-timeout"=>0, "arpforward"=>"enable", "ndiscforward"=>"enable", "broadcast-forward"=>"disable", "bfd"=>"global", "bfd-desired-min-tx"=>250, "bfd-detect-mult"=>3, "bfd-required-min-rx"=>250, "l2forward"=>"disable", "icmp-redirect"=>"enable", "vlanforward"=>"disable", "stpforward"=>"disable", "stpforward-mode"=>"rpl-all-ext-id", "ips-sniffer-mode"=>"disable", "ident-accept"=>"disable", "ipmac"=>"disable", "subst"=>"disable", "macaddr"=>"00:00:00:00:00:00", "substitute-dst-mac"=>"00:00:00:00:00:00", "speed"=>"auto", "status"=>"up", "netbios-forward"=>"disable", "wins-ip"=>"0.0.0.0", "type"=>"vlan", "dedicated-to"=>"none", "trust-ip-1"=>"0.0.0.0 0.0.0.0", "trust-ip-2"=>"0.0.0.0 0.0.0.0", "trust-ip-3"=>"0.0.0.0 0.0.0.0", "trust-ip6-1"=>"::/0", "trust-ip6-2"=>"::/0", "trust-ip6-3"=>"::/0", "mtu-override"=>"disable", "mtu"=>1500, "wccp"=>"disable", "netflow-sampler"=>"disable", "sflow-sampler"=>"disable", "drop-overlapped-fragment"=>"disable", "drop-fragment"=>"disable", "scan-botnet-connections"=>"disable", "src-check"=>"enable", "sample-rate"=>2000, "polling-interval"=>20, "sample-direction"=>"both", "explicit-web-proxy"=>"disable", "explicit-ftp-proxy"=>"disable", "proxy-captive-portal"=>"disable", "tcp-mss"=>0, "mediatype"=>"serdes-sfp", "inbandwidth"=>0, "outbandwidth"=>0, "spillover-threshold"=>0, "ingress-spillover-threshold"=>0, "weight"=>0, "interface"=>"FSW-AGG", "external"=>"disable", "vlanid"=>111, "forward-domain"=>0, "remote-ip"=>"0.0.0.0 0.0.0.0", "member"=>[], "lacp-mode"=>"active", "lacp-ha-slave"=>"enable", "lacp-speed"=>"slow", "min-links"=>1, "min-links-down"=>"operational", "algorithm"=>"L4", "link-up-delay"=>50, "priority-override"=>"enable", "aggregate"=>"", "redundant-interface"=>"", "managed-device"=>[], "devindex"=>59, "vindex"=>0, "switch"=>"", "description"=>"", "alias"=>"", "security-mode"=>"none", "captive-portal"=>0, "security-mac-auth-bypass"=>"disable", "security-external-web"=>"", "security-external-logout"=>"", "replacemsg-override-group"=>"", "security-redirect-url"=>"", "security-exempt-list"=>"", "security-groups"=>[], "device-identification"=>"enable", "device-user-identification"=>"enable", "device-identification-active-scan"=>"enable", "device-access-list"=>"", "lldp-transmission"=>"vdom", "fortiheartbeat"=>"enable", "broadcast-forticlient-discovery"=>"disable", "endpoint-compliance"=>"disable", "estimated-upstream-bandwidth"=>0, "estimated-downstream-bandwidth"=>0, "vrrp-virtual-mac"=>"disable", "vrrp"=>[], "role"=>"lan", "snmp-index"=>54, "secondary-IP"=>"disable", "secondaryip"=>[], "preserve-session-route"=>"disable", "auto-auth-extension-device"=>"disable", "ap-discover"=>"enable", "fortilink-stacking"=>"enable", "fortilink-split-interface"=>"disable", "internal"=>0, "fortilink-backup-link"=>0, "switch-controller-access-vlan"=>"disable", "switch-controller-igmp-snooping"=>"disable", "switch-controller-dhcp-snooping"=>"disable", "switch-controller-dhcp-snooping-verify-mac"=>"disable", "switch-controller-dhcp-snooping-option82"=>"disable", "switch-controller-auth"=>"usergroup", "switch-controller-radius-server"=>"", "color"=>11, "ipv6"=>{"ip6-mode"=>"static", "nd-mode"=>"basic", "nd-cert"=>"", "nd-security-level"=>0, "nd-timestamp-delta"=>300, "nd-timestamp-fuzz"=>1, "nd-cga-modifier"=>"0065636473612D776974682D73686132", "ip6-dns-server-override"=>"enable", "ip6-address"=>"::/0", "ip6-extra-addr"=>[], "ip6-allowaccess"=>"", "ip6-send-adv"=>"disable", "ip6-manage-flag"=>"disable", "ip6-other-flag"=>"disable", "ip6-max-interval"=>600, "ip6-min-interval"=>198, "ip6-link-mtu"=>0, "ip6-reachable-time"=>0, "ip6-retrans-time"=>0, "ip6-default-life"=>1800, "ip6-hop-limit"=>0, "autoconf"=>"disable", "ip6-upstream-interface"=>"", "ip6-subnet"=>"::/0", "ip6-prefix-list"=>[], "ip6-delegated-prefix-list"=>[], "dhcp6-relay-service"=>"disable", "dhcp6-relay-type"=>"regular", "dhcp6-relay-ip"=>"", "dhcp6-client-options"=>"", "dhcp6-prefix-delegation"=>"disable", "dhcp6-information-request"=>"disable", "dhcp6-prefix-hint"=>"::/0", "dhcp6-prefix-hint-plt"=>604800, "dhcp6-prefix-hint-vlt"=>2592000}}

# use the power of ruby :-)

    irb(main):001:0> p demo.interface.map(&:name)
    ["FITNUC", "FSA-DMZ", "FSA-DMZ2", "FSW-AGG", "FWLC", "ISFW-HA", "P22", "mgmt1", "mgmt2", "modem", "port1", "port2", "port3", "port4", "port5", "port6", "port7", "port8", "port9", "port10", "port11", "port12", "port13", "port14", "port15", "port16", "port17", "port18", "port19", "port20", "port21", "port22", "port23", "port24", "port25", "port26", "port27", "port28", "port29", "port30", "port31", "port32", "port33", "port34", "port35", "port36", "port37", "port38", "port39", "port40", "qtn.FSW-AGG", "ssl.root", "vsw.FSW-AGG"]

    irb(main):002:0> p demo.interface.map { |i| i.select { |k,v| k == 'name' or k == 'type' } }
    ype"=>"aggregate"}, {"name"=>"FWLC", "type"=>"vlan"}, {"name"=>"ISFW-HA", "type"=>"vlan"}, {"name"=>"P22", "type"=>"vlan"}, {"name"=>"mgmt1", "type"=>"physical"}, {"name"=>"mgmt2", "type"=>"physical"}, {"name"=>"modem", "type"=>"physical"}, {"name"=>"port1", "type"=>"physical"}, {"name"=>"port2", "type"=>"physical"}, {"name"=>"port3", "type"=>"physical"}, {"name"=>"port4", "type"=>"physical"}, {"name"=>"port5", "type"=>"physical"}, {"name"=>"port6", "type"=>"physical"}, {"name"=>"port7", "type"=>"physical"}, {"name"=>"port8", "type"=>"physical"}, {"name"=>"port9", "type"=>"physical"}, {"name"=>"port10", "type"=>"physical"}, {"name"=>"port11", "type"=>"physical"}, {"name"=>"port12", "type"=>"physical"}, {"name"=>"port13", "type"=>"physical"}, {"name"=>"port14", "type"=>"physical"}, {"name"=>"port15", "type"=>"physical"}, {"name"=>"port16", "type"=>"physical"}, {"name"=>"port17", "type"=>"physical"}, {"name"=>"port18", "type"=>"physical"}, {"name"=>"port19", "type"=>"physical"}, {"name"=>"port20", "type"=>"physical"}, {"name"=>"port21", "type"=>"physical"}, {"name"=>"port22", "type"=>"physical"}, {"name"=>"port23", "type"=>"physical"}, {"name"=>"port24", "type"=>"physical"}, {"name"=>"port25", "type"=>"physical"}, {"name"=>"port26", "type"=>"physical"}, {"name"=>"port27", "type"=>"physical"}, {"name"=>"port28", "type"=>"physical"}, {"name"=>"port29", "type"=>"physical"}, {"name"=>"port30", "type"=>"physical"}, {"name"=>"port31", "type"=>"physical"}, {"name"=>"port32", "type"=>"physical"}, {"name"=>"port33", "type"=>"physical"}, {"name"=>"port34", "type"=>"physical"}, {"name"=>"port35", "type"=>"physical"}, {"name"=>"port36", "type"=>"physical"}, {"name"=>"port37", "type"=>"physical"}, {"name"=>"port38", "type"=>"physical"}, {"name"=>"port39", "type"=>"physical"}, {"name"=>"port40", "type"=>"physical"}, {"name"=>"qtn.FSW-AGG", "type"=>"vlan"}, {"name"=>"ssl.root", "type"=>"tunnel"}, {"name"=>"vsw.FSW-AGG", "type"=>"vlan"}]

### ipsec.rb

(obviously there is no tunnel configured at fortidemo, but here are the methods:)

    irb(main):011:0> require 'fgt_rest_api/ext/interface'

    irb(main):012:0> p demo.vpn_ipsec_phase1
    []

    irb(main):013:0> p demo.vpn_ipsec_phase1_interface
    []

    irb(main):014:0> p demo.vpn_ipsec_phase2
    []

    irb(main):015:0> p demo.vpn_ipsec_phase2_interface
    []

### router.rb



### policy_and_object.rb


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/fuegito/fgt_rest_api.
