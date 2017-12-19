require 'httpclient'
require 'json'
require 'ostruct'
require 'timeout'

module FGT
  class RestApi

    class << self

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


    attr_reader(:proxy, :use_proxy, :url_schema)
    attr_accessor(
      :api_version, :ip, :port,
      :username, :secretkey, :timeout,
      :ccsrftoken, :client, :debug,
      :safe_mode, :use_vdom, :retry_counter
    )

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
      retry_counter: 3,
      use_vdom: 'root'
    )
      self.url_schema = url_schema
      self.use_vdom = use_vdom
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
      self.retry_counter = retry_counter
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
        @url_schema = (schema == 'http' ? 'http' : 'https')
      end

      def new_httpclient
        unless use_proxy
          ENV['http_proxy'] = ''
          raise FGTPortNotOpenError unless self.class.tcp_port_open?(ip, port, timeout)
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
        unless mkey.empty?
          url_path += "#{mkey}/"
          unless child_name.empty?
            url_path += "#{child_name}/"
            unless child_mkey.empty?
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
        retries ||= retry_counter
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
            parsed_body = JSON.parse(response.body.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: ''), object_class: FGT::FCHash)
            #if rubyfi
            #  if method == 'get'
            #    retval = self.class.deep_rubyfi_parsed_json(parsed_body['results'])
            #  else
            #  self.class.deep_rubyfi_parsed_json(parsed_body)
            #  end
            #else
            #  if method == 'get'
            #    retval = parsed_body['results']
            #  else
            #  parsed_body
            #  end
            #end
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
        retries ||= retry_counter
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
        retries = retry_counter
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