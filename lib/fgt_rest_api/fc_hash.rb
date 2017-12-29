module FGT

  class FCHash < ::Hash

    def []=(key, value)
      raise(ArgumentError, 'key needs to be a string') unless key.is_a?(String)
      raise(ArgumentError, "key needs start with downcase: >>#{key}<<") unless key[0] == key[0].downcase
      define_singleton_method(key.tr('-', '_')) do
        value
      end
      define_singleton_method(key.tr('-', '_') + '=') do |value|
        self[key] = value
      end
      super(key, value)
    end

    def [](key)
      raise(ArgumentError, "key needs start with downcase: >>#{key}<<") unless key.to_s[0] == key.to_s[0].downcase
      if key.is_a?(String)
        super(key)
      elsif key.is_a?(Symbol)
        super(key.to_s) || super(key.to_s.tr('_', '-'))
      else
        raise(ArgumentError, "'key needs to be a string and key needs start with downcase: >>#{key.inspect}<<") unless key.is_a?(String)
      end
    end

  end

end