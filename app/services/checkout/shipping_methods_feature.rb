module Checkout
  class ShippingMethodsFeature
    def self.enabled?
      ENV.fetch("CHECKOUT_SHIPPING_METHODS_ENABLED", "false") == "true"
    end
  end
end
