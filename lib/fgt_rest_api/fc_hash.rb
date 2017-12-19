module FGT

  class FCHash < ::Hash

    def []=(key, value)
      raise(ArgumentError, 'key needs to be a string') unless key.is_a?(String)
      raise(ArgumentError, 'key needs to be downcase') unless key == key.downcase
      define_singleton_method(key.tr('-', '_')) do
        value
      end
      define_singleton_method(key.tr('-', '_') + '=') do |value|
        self[key] = value
      end
      super(key, value)
    end

    def [](key)
      if key.is_a?(String)
        raise(ArgumentError, 'key needs to be downcase') unless key == key.downcase
        super(key)
      elsif key.is_a?(Symbol)
        raise(ArgumentError, 'key needs to be downcase') unless key.to_s == key.to_s.downcase
        super(key.to_s) || super(key.to_s.tr('_', '-'))
      else
        raise(ArgumentError, 'key needs to be a downcase string or a symbol') unless key.is_a?(String)
      end
    end

  end

end