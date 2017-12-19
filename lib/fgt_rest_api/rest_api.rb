module Fgt
  class RestApi
    require 'httpclient'
    require 'json'
    require 'active_support/core_ext/array'
    require 'active_support/core_ext/hash'
    require 'timeout'

    Retries = 3

    class << self

      def typecast(value)
        if value.is_a? String
          if /^(?:([1-9]\d+)|\d)$/ === value
            value.to_i
          elsif /^(\d+)?\.(\d+)$/ === value
            value.to_f
          elsif /^true$/i === value
            value = true
          elsif /^false$/i === value
            value = false
          else
            value
          end
        else
          value
        end
      end
      private :typecast

      def deep_rubyfi_parsed_json(parsed_json)
        if parsed_json.is_a?(String)
          parsed_json.replace(typecast(parsed_json))
        elsif parsed_json.is_a?(Array)
          parsed_json.each do |e|
            e.replace(deep_rubyfi_parsed_json(e))
          end
        elsif parsed_json.is_a?(Hash)
          parsed_json.transform_values! { |v| typecast(v) }
          parsed_json.transform_keys! { |key| key.gsub(/-/, '_') if key.is_a?(String) }
          parsed_json.symbolize_keys!
          parsed_json.each { |k,v| deep_rubyfi_parsed_json(v) if ( v.is_a?(Hash) || v.is_a?(Array) ) }
        else
          raise DeepRubyfiError
        end
      end

      def tcp_port_open?(ip, port, timeout = 2)
        begin
          Timeout::timeout(timeout) do
            begin
              s = TCPSocket.new(ip, port)
              s.close
              return true
            rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
              return false
            end
          end
        rescue Timeout::Error
          return false
        end
        false
      end
    end

    attr_reader :proxy, :use_proxy, :url_schema
    attr_accessor :api_version, :ip, :port, :username, :secretkey, :timeout, :ccsrftoken, :client, :debug, :safe_mode, :rubyfi, :use_vdom

    def initialize(
      api_version: 'v2',
      url_schema: 'https',
      ip:,
      port: 4434,
      username:,
      password:,
      timeout: 5,
      proxy: ENV['http_proxy'],
      use_proxy: false,
      debug: false,
      safe_mode: true,
      rubyfi: false,
      use_vdom: 'root'
    )
      self.url_schema = url_schema
      self.use_vdom = use_vdom
      self.rubyfi = rubyfi
      self.safe_mode = safe_mode
      self.debug = debug
      self.timeout = timeout
      self.api_version = api_version
      self.ip = ip
      self.port = port
      self.proxy = proxy
      self.use_proxy = use_proxy
      self.client = new_httpclient
      self.username = username
      self.secretkey = password
      self.ccsrftoken = String.new
    end

    def use_proxy=(boolean)
      @use_proxy = !!boolean
      self.client = new_httpclient
    end

    def proxy=(proxy)
      @proxy = proxy
      self.client = new_httpclient if use_proxy
    end

    %w( get post ).each do |request_method|
      define_method('monitor_' + request_method) do |path, params = {}|
        raise SafeModeActiveError if (request_method != 'get' && safe_mode)
        path.gsub!(/\/*$/, '')
        url_path = "api/#{api_version}/monitor/#{path}/"
        params[:vdom] = use_vdom unless params.key?(:vdom)
        begin
          request(request_method, url_path, params)
        #rescue HTTP405MethodNotAllowedError => e
        #  STDERR.puts "method #{request_method} not allowed for this api_method"
        #  raise
        #rescue HTTP403ForbiddenError => e
        #  STDERR.puts "current user not authorized for this api_method"
        #  raise
        #rescue HTTP404ResourceNotFoundError => e
        #  STDERR.puts "resource does not exist"
        #  raise
        end
      end
    end

    %w( get post put delete ).each do |request_method|
      define_method('cmdb_' + request_method) do |args_hash|
        args_hash[:request_method] = request_method
        cmdb(args_hash)
      end
    end

    def vdoms
      cmdb_get(path: 'system', name: 'vdom')[:results].map { |v| v[:name] }
    end

    def hostname
      cmdb_get(path: 'system', name: 'global')[:results][:hostname]
    end

    def interface_by_name(interface, vdom = use_vdom)
      cmdb_get(path: 'system', name: 'interface', vdom: vdom, params: { filter: ["name==#{interface}", "vdom==#{vdom}"] })[:results].find do |i|
        i[:vdom] == vdom && i[:name] == interface
      end
    end

    # Interface types: %w[vlan physical aggregate tunnel]
    def interfaces(vdom = use_vdom, *interface_types)
      interface_types = %w[vlan physical aggregate tunnel] if interface_types.empty?
      cmdb_get(path: 'system', name: 'interface', vdom: vdom, params: { filter: "vdom==#{vdom}" })[:results].select do |n|
        interface_types.include?(n[:type]) && n[:vdom] == vdom
      end
    end

    #vpn ipsec
    %w( phase1 phase1_interface phase2 phase2_interface forticlient ).each do |name|
      define_method('vpn_ipsec_' + name) do |vdom = use_vdom|
        response = cmdb_get(path: 'vpn.ipsec', name: name.gsub('_', '-'), vdom: vdom)
      end
    end

    #router
    %w( static policy ospf bgp isis rip ).each do |name|
      define_method('router_' + name) do |vdom = use_vdom|
        response = cmdb_get(path: 'router', name: name, vdom: vdom)
      end
    end

    private :client

    private

      def url_schema=(schema)
        if schema == 'http'
          @url_schema = 'http'
        else
          @url_schema = 'https'
        end
      end

      def new_httpclient
        if not use_proxy
          ENV['http_proxy'] = ''
          raise FGTPortNotOpenError if not self.class.tcp_port_open?(ip, port, timeout)
        else
          ENV['http_proxy'] = proxy
        end
        client = HTTPClient.new(nil)
        client.set_cookie_store('/dev/null')
        client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE if url_schema == 'https'
        client
      end

      def cmdb(request_method: 'get', path:, name:, mkey: '', child_name: '', child_mkey: '', vdom: use_vdom, params: {})
        raise SafeModeActiveError if (request_method != 'get' && safe_mode)
        raise CMDBPathError unless /^\w*\.?\w+$/ === path
        raise CMDBNameError unless /^[^\/]+$/ === name
        raise CMDBMKeyError unless /^[^\/]*$/ === mkey
        raise CMDBChildNameError unless /^[^\/]*$/ === child_name
        raise CMDBChildMKeyError unless /^[^\/]*$/ === child_mkey
        url_path = "api/#{api_version}/cmdb/#{path}/#{name}/"
        if not mkey.empty?
          url_path += "#{mkey}/"
          if not child_name.empty?
            url_path += "#{child_name}/"
            if not child_mkey.empty?
              url_path += "#{child_mkey}/"
            end
          end
        end
        url_path += "?vdom=#{vdom}" if %w( put delete ).include?(request_method)
        params[:vdom] = vdom if %w( post get ).include?(request_method)
        begin
          request(request_method, url_path, params)
        #rescue HTTP405MethodNotAllowedError => e
        #  STDERR.puts "method #{request_method} not allowed for this api_method"
        #  raise
        #rescue HTTP403ForbiddenError => e
        #  STDERR.puts "current user not authorized for this api_method"
        #  raise
        #rescue HTTP404ResourceNotFoundError => e
        #  STDERR.puts "resource does not exist"
        #  raise
        #rescue HTTP424FailedDependencyError => e
        #  STDERR.puts "object does not exist"
        #  raise
        end
      end

      def request(method, path, params = {})
        retries ||= self.class::Retries
        url = "#{url_schema}://#{ip}:#{port}/#{path}"
        Timeout::timeout(timeout) do
          begin
            login
            if method == 'get'
              response = client.get(url, params)
            elsif method == 'post'
              response = client.post(url, params.to_json, 'X-CSRFTOKEN' => ccsrftoken)
            elsif method == 'put'
              response = client.put(url, body: params.to_json, header: {'X-CSRFTOKEN' => ccsrftoken})
            elsif method == 'delete'
              response = client.delete(url, query: params, header: {'X-CSRFTOKEN' => ccsrftoken})
            else
              raise HTTPMethodUnknownError
            end
            #raise HTTP302FoundMovedError if response.status_code == 302
            #raise HTTP400BadRequestError if response.status_code == 400
            #raise HTTP401NotAuthorizedError if response.status_code == 401
            #raise HTTP403ForbiddenError if response.status_code == 403
            #raise HTTP404ResourceNotFoundError if response.status_code == 404
            #raise HTTP405MethodNotAllowedError if response.status_code == 405
            #raise HTTP413RequestEntitiyToLargeError if response.status_code == 413
            #raise HTTP424FailedDependencyError if response.status_code == 424
            #raise HTTP500InternalServerError if response.status_code == 500
            #raise HTTPStatusNot200Error if response.status_code != 200
            parsed_body = JSON.parse(response.body.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: ''))
            if rubyfi
            #  if method == 'get'
            #    retval = self.class.deep_rubyfi_parsed_json(parsed_body['results'])
            #  else
              self.class.deep_rubyfi_parsed_json(parsed_body)
            #  end
            else
            #  if method == 'get'
            #    retval = parsed_body['results']
            #  else
              parsed_body
            #  end
            end
          #rescue HTTP302FoundMovedError => e
          #  # ToDo: get new location from Location Header and retry
          #  STDERR.puts "302: #{response.backtrace} " + e.inspect if debug
          #  raise
          #rescue HTTP400BadRequestError, HTTP401NotAuthorizedError, HTTP403ForbiddenError, HTTP413RequestEntitiyToLargeError => e
          #  STDERR.puts "40x Error, retrying... => #{e.backtrace}" if debug
          #  retry if (retries -= 1) > 0
          #  raise # TooManyRetriesError
          #rescue HTTP424FailedDependencyError => e
          #  STDERR.puts "response_body: #{response.body}" if debug
          #  raise
          #rescue HTTP404ResourceNotFoundError => e
          #  STDERR.puts "404 not found: #{url} => #{e.backtrace}" if debug
          #  STDERR.puts "response_body: #{response.body}" if debug
          #  raise
          #rescue HTTP405MethodNotAllowedError => e
          #  STDERR.puts "405 request method not allowed => #{e.backtrace}" if debug
          #  STDERR.puts "response_body: #{response.body}" if debug
          #  raise
          #rescue HTTP500InternalServerError => e
          #  STDERR.puts "500 Server Error, retrying... => #{e.backtrace}" if debug
          #  STDERR.puts "response_body: #{response.body}" if debug
          #  retry if (retries -= 1) > 0
          #  raise # TooManyRetriesError
          #rescue HTTPStatusNot200Error => e
          #  STDERR.puts "other Error #{e.inspect}, retrying... => #{e.backtrace}" if debug
          #  STDERR.puts "response_body: #{response.body}" if debug
          #  retry if (retries -= 1) > 0
          #  raise # TooManyRetriesError
          rescue JSON::ParserError => e
            STDERR.puts "#{e.inspect} => #{e.backtrace}" if debug
            STDERR.puts "response_body: #{response.body}" if debug
            retry if (retries -= 1) > 0
            raise # TooManyRetriesError
          rescue Java::JavaNet::SocketException, SocketError => e
            #STDERR.puts "SocketError: #{e.inspect} => #{e.backtrace}" if debug
            retry if (retries -= 1) > 0
            raise # TooManyRetriesError
          ensure
            logout
          end
        end
      end

      def login
        retries ||= self.class::Retries
        Timeout::timeout(timeout) do
          begin
            url = "https://#{ip}:#{port}/logincheck"
            params = { username: username, secretkey: secretkey }
            client.post(url, params)
          rescue Java::JavaNet::SocketException, SocketError => e
            STDERR.puts '#login: ' + e.inspect if debug
            retry if (retries -= 1) > 0
            raise # TooManyRetriesError
          rescue JSON::ParserError => e
            STDERR.puts '#login post: JSON::ParserError' + e.inspect if debug
            retry if (retries -= 1) > 0
            raise # TooManyRetriesError
          end
          client.cookies.each do |cookie|
            self.ccsrftoken = cookie.value if cookie.name == 'ccsrftoken'
          end
        end
      end

      def logout
        retries = self.class::Retries
        Timeout::timeout(@timeout) do
          begin
            url = "https://#{@ip}:#{@port}/logout"
            client.get(url)
          rescue Java::JavaNet::SocketException, SocketError => e
            STDERR.puts '#logout: ' + e.inspect if debug
            retry if (retries -= 1) > 0
            raise # TooManyRetriesError
          end
          client.cookies.clear
        end
      end
  end
end