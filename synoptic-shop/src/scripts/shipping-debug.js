// src/scripts/shipping-debug.js
// Debug script to investigate shipping rates issues

class ShippingDebugger {
  constructor() {
    this.swell = window.swell;
    this.debug = true;
  }
  
  async runFullDiagnostics() {
    console.log('🚚 Starting shipping diagnostics...');
    
    try {
      // 1. Check Swell connection
      await this.checkSwellConnection();
      
      // 2. Check store settings
      await this.checkStoreSettings();
      
      // 3. Check shipping zones
      await this.checkShippingZones();
      
      // 4. Check current cart
      await this.checkCurrentCart();
      
      // 5. Test shipping calculation
      await this.testShippingCalculation();
      
    } catch (error) {
      console.error('❌ Shipping diagnostics failed:', error);
    }
  }
  
  async checkSwellConnection() {
    console.log('🔍 Checking Swell connection...');
    
    if (!this.swell) {
      console.error('❌ Swell not available');
      return;
    }
    
    try {
      const settings = await this.swell.settings.get();
      console.log('✅ Swell connected');
      console.log('📊 Store settings:', {
        store_id: settings.store?.id,
        name: settings.store?.name,
        currency: settings.store?.currency,
        shipping_enabled: !!settings.shipping
      });
      
      return settings;
    } catch (error) {
      console.error('❌ Failed to get store settings:', error);
      throw error;
    }
  }
  
  async checkStoreSettings() {
    console.log('🔍 Checking store shipping settings...');
    
    try {
      const settings = await this.swell.settings.get();
      
      if (!settings.shipping) {
        console.error('❌ Shipping not configured in store settings');
        return;
      }
      
      console.log('✅ Shipping settings found:', {
        enabled: settings.shipping.enabled,
        zones: settings.shipping.zones?.length || 0,
        services: settings.shipping.services?.length || 0
      });
      
      // Check individual zones
      if (settings.shipping.zones) {
        settings.shipping.zones.forEach((zone, index) => {
          console.log(`🌍 Zone ${index + 1}:`, {
            id: zone.id,
            name: zone.name,
            countries: zone.countries,
            services: zone.services?.length || 0
          });
        });
      }
      
      return settings.shipping;
    } catch (error) {
      console.error('❌ Failed to check shipping settings:', error);
      throw error;
    }
  }
  
  async checkShippingZones() {
    console.log('🔍 Checking shipping zones configuration...');
    
    try {
      // Try to get shipping zones directly
      const zones = await this.swell.shipping.getZones();
      
      if (!zones || zones.length === 0) {
        console.error('❌ No shipping zones found');
        return;
      }
      
      console.log('✅ Shipping zones found:', zones.length);
      
      zones.forEach(zone => {
        console.log(`🌍 Zone: ${zone.name}`, {
          id: zone.id,
          countries: zone.countries,
          services: zone.services?.map(s => ({
            name: s.name,
            price: s.price,
            enabled: s.enabled
          }))
        });
      });
      
      return zones;
    } catch (error) {
      console.log('⚠️ Direct shipping zones call failed:', error);
      // This might be expected if the API method doesn't exist
    }
  }
  
  async checkCurrentCart() {
    console.log('🔍 Checking current cart...');
    
    try {
      const cart = await this.swell.cart.get();
      
      console.log('🛒 Current cart:', {
        id: cart.id,
        item_count: cart.item_count,
        grand_total: cart.grand_total,
        currency: cart.currency,
        shipping: cart.shipping,
        shipping_total: cart.shipping_total
      });
      
      if (cart.items) {
        console.log('📦 Cart items:', cart.items.map(item => ({
          id: item.id,
          product_id: item.product_id,
          quantity: item.quantity,
          price: item.price,
          price_total: item.price_total
        })));
      }
      
      return cart;
    } catch (error) {
      console.error('❌ Failed to get current cart:', error);
      throw error;
    }
  }
  
  async testShippingCalculation() {
    console.log('🔍 Testing shipping calculation...');
    
    // Test with different addresses
    const testAddresses = [
      {
        name: 'Test Germany',
        address1: 'Teststraße 1',
        city: 'Berlin',
        zip: '10117',
        country: 'DE'
      },
      {
        name: 'Test Austria',
        address1: 'Testgasse 1',
        city: 'Vienna',
        zip: '1010',
        country: 'AT'
      },
      {
        name: 'Test Switzerland',
        address1: 'Testweg 1',
        city: 'Zurich',
        zip: '8001',
        country: 'CH'
      }
    ];
    
    for (const address of testAddresses) {
      console.log(`🚚 Testing shipping for ${address.name}...`);
      
      try {
        // Method 1: Try swell.cart.getShippingRates()
        const rates1 = await this.swell.cart.getShippingRates(address);
        console.log(`📊 Method 1 (getShippingRates): ${rates1 ? rates1.length : 0} rates`);
        if (rates1) {
          rates1.forEach(rate => {
            console.log(`  - ${rate.name}: ${rate.price} ${rate.currency || 'EUR'}`);
          });
        }
        
        // Method 2: Try swell.shipping.getQuote()
        try {
          const quote = await this.swell.shipping.getQuote(address);
          console.log(`📊 Method 2 (getQuote):`, quote);
        } catch (error) {
          console.log(`⚠️ Method 2 failed:`, error.message);
        }
        
        // Method 3: Try updating cart shipping and check rates
        try {
          await this.swell.cart.update({ shipping: address });
          const updatedCart = await this.swell.cart.get();
          console.log(`📊 Method 3 (cart update):`, {
            shipping_total: updatedCart.shipping_total,
            shipping_services: updatedCart.shipping_services
          });
        } catch (error) {
          console.log(`⚠️ Method 3 failed:`, error.message);
        }
        
        console.log('---');
        
      } catch (error) {
        console.error(`❌ Shipping calculation failed for ${address.name}:`, error);
      }
    }
  }
  
  // Helper method to check if shipping is available for a country
  async isShippingAvailable(country) {
    try {
      const settings = await this.swell.settings.get();
      
      if (!settings.shipping?.zones) {
        return false;
      }
      
      return settings.shipping.zones.some(zone => 
        zone.countries?.includes(country) || 
        zone.countries?.includes('*') // wildcard for all countries
      );
    } catch (error) {
      console.error('Error checking shipping availability:', error);
      return false;
    }
  }
  
  // Check if there are any products in cart that affect shipping
  async checkShippingableProducts() {
    console.log('🔍 Checking shippable products...');
    
    try {
      const cart = await this.swell.cart.get();
      
      if (!cart.items || cart.items.length === 0) {
        console.log('⚠️ No items in cart');
        return;
      }
      
      for (const item of cart.items) {
        console.log(`📦 Item ${item.id}:`, {
          product_id: item.product_id,
          quantity: item.quantity,
          price: item.price,
          shipping_weight: item.shipping_weight,
          shipping_dimensions: item.shipping_dimensions,
          requires_shipping: item.requires_shipping
        });
      }
      
    } catch (error) {
      console.error('❌ Failed to check shippable products:', error);
    }
  }
}

// Usage functions
window.debugShipping = function() {
  const shippingDebugger = new ShippingDebugger();
  shippingDebugger.runFullDiagnostics();
};

window.testShippingFor = function(country = 'DE') {
  const shippingDebugger = new ShippingDebugger();
  const testAddress = {
    name: `Test ${country}`,
    address1: 'Test Street 1',
    city: 'Test City',
    zip: country === 'DE' ? '10117' : '1010',
    country: country
  };
  
  shippingDebugger.testShippingCalculation([testAddress]);
};

// Quick shipping test for Germany
window.quickShippingTest = async function() {
  const swell = window.swell;
  if (!swell) {
    console.error('Swell not available');
    return;
  }
  
  const address = {
    address1: 'Teststraße 1',
    city: 'Berlin',
    zip: '10117',
    country: 'DE'
  };
  
  console.log('🚚 Quick shipping test for Germany...');
  
  try {
    // Test the exact method used in checkout
    const rates = await swell.cart.getShippingRates(address);
    console.log('📊 Shipping rates result:', rates);
    
    if (!rates || rates.length === 0) {
      console.log('⚠️ No rates returned - checking cart and settings...');
      
      const cart = await swell.cart.get();
      console.log('🛒 Cart info:', {
        id: cart.id,
        item_count: cart.item_count,
        total: cart.grand_total,
        currency: cart.currency
      });
      
      const settings = await swell.settings.get();
      console.log('⚙️ Shipping settings:', {
        enabled: settings.shipping?.enabled,
        zones: settings.shipping?.zones?.length || 0
      });
    }
    
  } catch (error) {
    console.error('❌ Quick test failed:', error);
  }
};

// Auto-run diagnostics when script loads (for development)
if (typeof window !== 'undefined' && window.location.pathname.includes('/checkout')) {
  console.log('🚚 Checkout page detected - shipping debug tools available');
  console.log('Run debugShipping() or quickShippingTest() in console to test shipping');
}

export default ShippingDebugger;