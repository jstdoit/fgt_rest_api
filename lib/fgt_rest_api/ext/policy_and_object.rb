module FGT
  class FGT::RestApi

    %w( address addrgrp vip vipgrp policy ippool ).each do |name|
      define_method(name) do |vdom = use_vdom|
        memoize_results("@#{name}_response") do
          cmdb_get(path: 'firewall', name: name, vdom: vdom)[:results]
        end
      end
    end

    %w( custom group ).each do |name|
      define_method('service_' + name) do |vdom = use_vdom|
        memoize_results("@#{name}_response") do
          cmdb_get(path: 'firewall.service', name: name, vdom: vdom)[:results]
        end
      end
    end

    def clear_cache(inst_var = nil)
      set_inst_var = -> (i) { remove_instance_variable(i) if instance_variable_defined?(i) && @inst_var_refreshable.delete(i) }
      inst_var.nil? ? @inst_var_refreshable.each(&set_inst_var) : set_inst_var.call(inst_var) && @inst_var_refreshable
      #if inst_var.nil?
      #  #@inst_var_refreshable.each { |i| remove_instance_variable(i) if instance_variable_defined?(i) && @inst_var_refreshable.delete(i) }
      #  @inst_var_refreshable.each(&set_inst_var)
      #else
      #  remove_instance_variable(inst_var) if instance_variable_defined?(inst_var)
      #  @inst_var_refreshable.delete(inst_var)
      #end
    end

    def policy_object(object_name: nil, vdom: use_vdom)
      if object_name.nil?
        address(vdom) + addrgrp(vdom) + vip(vdom) + vipgrp(vdom) + ippool(vdom)
      else
        (address(vdom) + addrgrp(vdom) + vip(vdom) + vipgrp(vdom) + ippool(vdom)).find { |o| o[:name] == object_name }
      end
    end

    def find_address_object_by_name(name, vdom = use_vdom)
      policy_object(object_name: name, vdom: vdom)
    end

    def service_object(vdom = use_vdom)
      service_custom(vdom) + service_group(vdom)
    end

    def iprange(vdom = use_vdom)
      address(vdom).select { |o| o[:type] == 'iprange' }
    end

    def vip_loadbalancer(vdom = use_vdom)
      vip(vdom).select { |o| o[:type] == 'server-load-balance' }
    end

    def vip_dnat(vdom = use_vdom)
      vip(vdom).select { |o| o[:type] == 'static-nat' }
    end

    def ipaddress(vdom = use_vdom)
      address(vdom).select { |o| o[:type] == 'ipmask' && /255.255.255.255$/.match(o[:subnet]) }
    end

    def ipnetwork(vdom = use_vdom)
      address(vdom).select { |o| o[:type] == 'ipmask' && not(/255.255.255.255$/.match(o[:subnet])) }
    end

    def fqdn(vdom = use_vdom)
      address(vdom).select { |o| o[:type] == 'fqdn' }
    end

    def wildcard_fqdn(vdom = use_vdom)
      address(vdom).select { |o| o[:type] == 'wildcard-fqdn' }
    end


    def find_group_for_object(object, vdom = use_vdom)
      groups = (vipgrp(vdom) + addrgrp(vdom)).select {|o| o[:member].map { |m| m[:q_origin_key] }.include?(object) }
      groups.each do |group|
        grouped_groups = find_group_for_object(group[:name], vdom)
        next if grouped_groups.empty?
        groups += grouped_groups
      end
      groups.flatten.uniq.compact
    end

    def find_address_object_by_address(addr, vdom = use_vdom)
      addr = NetAddr::CIDR.create(addr)
      address(vdom).select do |o|
        if o[:type] == 'ipmask'
          NetAddr::CIDR.create(o[:subnet]).contains?(addr) || (NetAddr::CIDR.create(o[:subnet]) == addr)
        elsif o[:type] == 'iprange'
          (NetAddr::CIDR.create(o[:start_ip])..NetAddr::CIDR.create(o[:end_ip])).include?(addr)
        elsif /^\s*(?:wildcard(?:_|-))?fqdn\s*$/ === o[:type]
          next
        else
          raise(FGTAddressTypeError, "this is neither an iprange nor an ipmask: #{o.inspect}")
        end
      end.uniq
    end

    def find_vip_object_by_address(addr, vdom = use_vdom)
      addr = NetAddr::CIDR.create(addr)
      vip(vdom).select do |o|
        begin
          (
            NetAddr::CIDR.create(o[:extip]) == addr
          ) ||
          (
            if o[:type] == 'static-nat'
              o[:mappedip].find do |m|
                begin
                  NetAddr::CIDR.create(m[:range]).contains?(addr) || NetAddr::CIDR.create(m[:range]) == addr
                rescue NetAddr::ValidationError
                  (NetAddr::CIDR.create(m[:range].split(/\s+|-/)[0])..NetAddr::CIDR.create(m[:range].split(/\s+|-/)[1])).include?(addr)
                end
              end
            elsif o[:type] == 'server-load-balance'
              o[:realservers].find { |r| NetAddr::CIDR.create(r[:ip]) == addr }
            else
              raise(FGTVIPTypeError, "this is neither a static-nat nor a server-load-balance type: #{o.inspect}")
            end
          )
        rescue ArgumentError
          puts o.inspect
          raise
        end
      end.uniq
    end

    def find_ippool_object_by_address(addr, vdom = use_vdom)
      addr = NetAddr::CIDR.create(addr)
      objects = ippool(vdom).select do |o|
        (NetAddr::CIDR.create(o[:startip])..NetAddr::CIDR.create(o[:endip])).include?(addr) ||
        (NetAddr::CIDR.create(o[:source_startip])..NetAddr::CIDR.create(o[:source_endip])).include?(addr)
      end.uniq
    end

    def find_object_by_address(addr, vdom = use_vdom)
      objects = find_address_object_by_address(addr, vdom) + find_vip_object_by_address(addr, vdom) + find_ippool_object_by_address(addr, vdom)
      objects << objects.map { |o| find_group_for_object(o[:name]) }.uniq.flatten
      objects.flatten.uniq.compact
    end

    def find_src_policy_for_object(object, vdom = use_vdom)
      objects = Array.new
      rules = Array.new
      objects << policy_object(object_name: object, vdom: vdom)
      objects << find_group_for_object(object, vdom)
      objects.flatten.compact.uniq.each do |o|
        rules << policy(vdom).select do |p|
          (
            (p[:srcaddr].map { |m| m[:q_origin_key] }.include? o[:name]) ||
            (p[:poolname].map { |m| m[:q_origin_key] }.nil? ? false : (p[:poolname].map { |m| m[:q_origin_key] }.include? o[:name]))
          )
        end
      end
      rules.flatten.uniq.compact
    end

    def find_dst_policy_for_object(object, vdom = use_vdom)
      objects = Array.new
      rules = Array.new
      objects << policy_object(object_name: object, vdom: vdom)
      objects << find_group_for_object(object, vdom)
      objects.flatten.compact.uniq.each do |o|
        rules << policy(vdom).select do |p|
          (
            (p[:dstaddr].map { |m| m[:q_origin_key] }.include? o[:name])
          )
        end
      end
      rules.flatten.uniq.compact
    end

    def find_policy_for_object(object, vdom = use_vdom)
      (find_src_policy_for_object(object, vdom) + find_dst_policy_for_object(object, vdom)).flatten.uniq
    end

    def find_src_policy_for_address(addr, vdom = use_vdom)
      find_object_by_address(addr, vdom).map { |o| find_src_policy_for_object(o[:name], vdom) }.flatten.uniq
    end

    def find_dst_policy_for_address(addr, vdom = use_vdom)
      find_object_by_address(addr, vdom).map { |o| find_dst_policy_for_object(o[:name], vdom) }.flatten.uniq
    end

    def find_policy_for_address(addr, vdom = use_vdom)
      find_object_by_address(addr, vdom).map { |o| find_policy_for_object(o[:name], vdom) }.flatten.uniq
    end

    def search_object(*object_re, vdom: use_vdom, comment: false)
      object_re = Array(object_re).map { |re| re.is_a?(Regexp) ? re : Regexp.new(re.gsub(/\./, '\.')) }
      object_re = Regexp.union(object_re)
      with_name = -> (o) { object_re === o[:name] }
      with_name_and_comment = -> (o) { (object_re === o[:name]) || (object_re === o[:comment]) }
      search = comment ? with_name_and_comment : with_name
      with_groups = -> (o) { [o] << find_group_for_object(o[:name], vdom) }
      policy_object.select(&search).map(&with_groups).flatten.uniq.compact
    end

    # def find_object_by_address(address, vdom = use_vdom)
      # address = address.split('.').map { |o| o.to_i }
      # raise NotAnIPError if address.size != 4
      # rg = Regexp.new(/#{address[0]}\.#{address[1]}\.#{address[2]}\.#{address[3]}/)
      # address = address.join('.')
      # address_o = NetAddr::CIDR.create(address)
      # objects = policy_object(vdom: vdom).select do |o|
        # begin
          # ( (o[:subnet] && o[:subnet].split(/\s+/)[1].start_with?('255')) &&  NetAddr::CIDR.create(o[:subnet].split(/\s+/).join('/')).contains?(address_o) ) or
          # ( o[:start_ip] && (o[:start_ip] == address) ) or
          # ( o[:startip] && (o[:startip] == address) ) or
          # ( o[:source_startip] && (o[:source_startip] == address) ) or
          # ( o[:end_ip] && (o[:end_ip] == address) ) or
          # ( o[:endip] && (o[:endip] == address) ) or
          # ( o[:source_endip] && (o[:source_endip == address]) ) or
          # ( o[:extip] && (o[:extip] == address) ) or
          # ( o[:wildcard] && rg.match(o[:wildcard]) ) or
          # ( o[:mappedip] && o[:mappedip].find { |m| m[:range] == address } ) or
          # ( o[:realservers] && o[:realservers].map { |r| r[:ip] }.find { |e| e == address }) or
          # ( ( o[:start_ip] && o[:end_ip] && !o[:end_ip].start_with?('255') ) && (NetAddr::CIDR.create(o[:start_ip])..NetAddr::CIDR.create(o[:end_ip])).include?(address_o) ) or
          # ( (o[:startip] && o[:endip] && !o[:endip].start_with?('255') ) && (NetAddr::CIDR.create(o[:startip])..NetAddr::CIDR.create(o[:endip])).include?(address_o) ) or
          # ( (o[:mappedip] && o[:mappedip].find { |m| ( (a, b) = o[:mappedip].split(/-/) ) && !(b.nil? || b.empty?) && !b.start_with?('255') && (NetAddr::CIDR.create(a)..NetAddr::CIDR.create(b)).include?(address_o) } ) ) or
          # ( (o[:source_startip] && o[:source_endip] && !o[:source_endip].start_with?('255') ) && (NetAddr::CIDR.create(o[:source_startip])..NetAddr::CIDR.create(o[:source_endip])).include?(address_o) ) or
          # ( o[:wildcard] && ( (a, b) = o[:wildcard].split(/-/) ) && !(b.nil? || b.empty?) && !b.start_with?('255') && (NetAddr::CIDR.create(a)..NetAddr::CIDR.create(b)).include?(address_o) )
        # rescue TypeError => e
          # STDERR.puts o[:type]
          # STDERR.puts e.inspect
          # raise
        # end
      # end
      # objects << objects.map { |o| find_group_for_object(o[:name]) }.uniq.flatten
      # objects.flatten.uniq.compact
    # end

    # def find_policy_for_object(object, vdom = use_vdom, deepness = 5)
      # objects = Array.new
      # rules = Array.new
      # objects << policy_object(object_name: object, vdom: vdom)
      # objects << find_group_for_object(object, vdom)
      # #deepness.times do
        # objects.flatten.each do |o|
          # objects << find_group_for_object(o, vdom)
        # end
      # #end
      # objects.flatten.compact.uniq.each do |o|
        # rules << policy(vdom).select do |p|
          # (
            # (p[:dstaddr].map { |m| m[:q_origin_key] }.include? o[:name]) or
            # (p[:srcaddr].map { |m| m[:q_origin_key] }.include? o[:name]) or
            # (p[:poolname].map { |m| m[:q_origin_key] }.nil? ? false : (p[:poolname].map { |m| m[:q_origin_key] }.include? o[:name]))
          # )
        # end
      # end
      # rules.flatten.compact.uniq
    # end

    # def search_objects(*args)
      # search_strings = Array.new
      # objects = Array.new
      # args.flatten.each do |string|
        # rg = Regexp.new(/#{string}/i)
        # objects << policy_object.select do |o|
          # begin
            # rg.match(o['name']) or
            # ( o['subnet'] && rg.match(o['subnet']) ) or
            # ( o['start-ip'] && rg.match(o['start-ip']) ) or
            # ( o['end-ip'] && rg.match(o['end-ip']) ) or
            # ( o['extip'] && rg.match(o['extip']) ) or
            # ( o['mappedip'] && o['mappedip'].find { |e| rg =~ e } ) or
            # ( o['realservers'] && o['realservers'].map { |r| r['ip'] }.find { |e| rg =~ e }) or
            # ( o['member'] && o['member'].map { |m| m['q_origin_key'] }.find { |e| rg =~ e } ) or
            # rg.match(o['comment'])
          # rescue TypeError => e
            # STDERR.puts __callee__
            # STDERR.puts __caller__
            # STDERR.puts o.inspect
            # STDERR.puts e.inspect
            # raise
          # end
        # end
      # end
      # objects.flatten
    # end

    # def search_rules(*args)
      # rules = Array.new
      # args.flatten.each do |string|
        # search_objects(string).each { |o| rules << find_policy_for_object(o) }
      # end
      # rules.flatten.uniq.sort
    # end

  end
end