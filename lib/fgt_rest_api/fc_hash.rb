module FGT

  class FCHash < ::Hash

    def attribute_methods(key, value)
      method_name = key.to_s.tr('-', '_')
      return nil if respond_to?(method_name.to_sym)
      define_singleton_method(method_name) { value }
      define_singleton_method("#{method_name}=") { |value| self[key] = value }
    end

    def []=(key, value)
      raise(ArgumentError, "key needs start with downcase letter: >>#{key}<<") unless key[0] == key[0].downcase
      attribute_methods(key, value)
      if key.is_a?(String)
        super(key, value)
      elsif key.is_a?(Symbol)
        super(key.to_s.tr('_', '-'), value)
      else
        raise(ArgumentError, "'key needs to be a string and key needs start with downcase letter: >>#{key.inspect}<<") unless key.is_a?(String)
      end
    end

    def [](key)
      raise(ArgumentError, "key needs start with downcase: >>#{key}<<") unless key.to_s[0] == key.to_s[0].downcase
        super(key)
      elsif key.is_a?(Symbol)
        super(key.to_s) || super(key.to_s.tr('_', '-'))
      else
        raise(ArgumentError, "'key needs to be a string and key needs start with downcase letter: >>#{key.inspect}<<") unless key.is_a?(String)
      end
    end

  end

end