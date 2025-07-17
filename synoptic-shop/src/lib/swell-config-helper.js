// src/lib/swell-config-helper.js
// Helper functions to debug and fix Swell store configuration

export class SwellConfigHelper {
  constructor() {
    this.swell = window.swell;
  }

  /**
   * Run complete store configuration diagnostics
   */
  async runStoreDiagnostics() {
    console.log('🔍 Running Swell store diagnostics...');
    
    const results = {
      connection: await this.checkConnection(),
      store: await this.checkStoreSettings(),
      shipping: await this.checkShippingConfiguration(),
      products: await this.checkProductConfiguration(),
      coupons: await this.checkCouponsConfiguration(),
      payments: await this.checkPaymentConfiguration()
    };
    
    console.log('📊 Diagnostics complete:', results);
    return results;
  }

  /**
   * Check basic Swell connection
   */
  async checkConnection() {
    try {
      if (!this.swell) {
        return { success: false, error: 'Swell SDK not loaded' };
      }

      const settings = await this.swell.settings.get();
      
      return {
        success: true,
        store_id: settings.store?.id,
        store_name: settings.store?.name,
        currency: settings.store?.currency,
        api_version: settings.api?.version
      };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  /**
   * Check store settings and configuration
   */
  async checkStoreSettings() {
    try {
      const settings = await this.swell.settings.get();
      
      return {
        success: true,
        store: {
          id: settings.store?.id,
          name: settings.store?.name,
          currency: settings.store?.currency,
          timezone: settings.store?.timezone,
          url: settings.store?.url
        },
        features: {
          shipping: !!settings.shipping,
          payments: !!settings.payments,
          coupons: !!settings.coupons,
          subscriptions: !!settings.subscriptions
        }
      };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  /**
   * Check shipping configuration in detail
   */
  async checkShippingConfiguration() {
    try {
      const settings = await this.swell.settings.get();
      
      if (!settings.shipping) {
        return {
          success: false,
          error: 'Shipping not configured in store settings'
        };
      }

      const shipping = settings.shipping;
      
      // Check shipping zones
      const zones = shipping.zones || [];
      const services = shipping.services || [];
      
      console.log('🚚 Shipping zones:', zones);
      console.log('🚚 Shipping services:', services);
      
      return {
        success: true,
        enabled: shipping.enabled,
        zones: zones.map(zone => ({
          id: zone.id,
          name: zone.name,
          countries: zone.countries,
          services: zone.services?.map(service => ({
            id: service.id,
            name: service.name,
            price: service.price,
            enabled: service.enabled
          }))
        })),
        global_services: services.map(service => ({
          id: service.id,
          name: service.name,
          price: service.price,
          enabled: service.enabled
        }))
      };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  /**
   * Check product configuration for shipping
   */
  async checkProductConfiguration() {
    try {
      // Get some products to check their shipping settings
      const products = await this.swell.products.list({ limit: 5 });
      
      const productChecks = products.results.map(product => ({
        id: product.id,
        name: product.name,
        requires_shipping: product.requires_shipping,
        shipping_weight: product.shipping_weight,
        shipping_dimensions: product.shipping_dimensions,
        price: product.price
      }));

      return {
        success: true,
        total_products: products.count,
        sample_products: productChecks
      };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  /**
   * Check coupon/promotion configuration
   */
  async checkCouponsConfiguration() {
    try {
      const settings = await this.swell.settings.get();
      
      if (!settings.coupons) {
        return {
          success: false,
          error: 'Coupons not configured in store settings'
        };
      }

      // Try to get some coupons (this might fail if no coupons exist)
      try {
        const coupons = await this.swell.coupons.list({ limit: 5 });
        
        return {
          success: true,
          enabled: true,
          total_coupons: coupons.count,
          sample_coupons: coupons.results.map(coupon => ({
            id: coupon.id,
            code: coupon.code,
            type: coupon.type,
            value: coupon.value,
            active: coupon.active,
            date_start: coupon.date_start,
            date_end: coupon.date_end
          }))
        };
      } catch (couponError) {
        return {
          success: true,
          enabled: true,
          total_coupons: 0,
          note: 'No coupons found or insufficient permissions'
        };
      }
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  /**
   * Check payment configuration
   */
  async checkPaymentConfiguration() {
    try {
      const settings = await this.swell.settings.get();
      
      if (!settings.payments) {
        return {
          success: false,
          error: 'Payments not configured in store settings'
        };
      }

      return {
        success: true,
        methods: settings.payments.methods || [],
        gateways: settings.payments.gateways || [],
        currencies: settings.payments.currencies || []
      };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  /**
   * Test shipping calculation with various addresses
   */
  async testShippingCalculation() {
    console.log('🧪 Testing shipping calculation...');

    const testAddresses = [
      {
        name: 'Germany Test',
        address1: 'Teststraße 1',
        city: 'Berlin',
        zip: '10117',
        country: 'DE'
      },
      {
        name: 'Austria Test',
        address1: 'Testgasse 1',
        city: 'Vienna',
        zip: '1010',
        country: 'AT'
      },
      {
        name: 'Switzerland Test',
        address1: 'Testweg 1',
        city: 'Zurich',
        zip: '8001',
        country: 'CH'
      }
    ];

    const results = [];

    for (const address of testAddresses) {
      try {
        console.log(`🚚 Testing ${address.name}...`);
        
        const rates = await this.swell.cart.getShippingRates(address);
        
        results.push({
          address: address.name,
          success: true,
          rates: rates ? rates.map(rate => ({
            id: rate.id,
            name: rate.name,
            price: rate.price,
            currency: rate.currency
          })) : []
        });
      } catch (error) {
        results.push({
          address: address.name,
          success: false,
          error: error.message
        });
      }
    }

    console.log('📊 Shipping test results:', results);
    return results;
  }

  /**
   * Create default shipping configuration (if admin access available)
   */
  async createDefaultShippingConfig() {
    console.log('🛠️ Creating default shipping configuration...');
    
    try {
      // This would require admin API access
      const defaultConfig = {
        enabled: true,
        zones: [
          {
            name: 'Germany',
            countries: ['DE'],
            services: [
              {
                name: 'Standard Shipping',
                price: 4.99,
                enabled: true
              },
              {
                name: 'Express Shipping',
                price: 9.99,
                enabled: true
              }
            ]
          },
          {
            name: 'Europe',
            countries: ['AT', 'CH', 'FR', 'IT', 'ES', 'NL', 'BE'],
            services: [
              {
                name: 'Standard Shipping',
                price: 7.99,
                enabled: true
              },
              {
                name: 'Express Shipping',
                price: 14.99,
                enabled: true
              }
            ]
          }
        ]
      };

      console.log('📋 Default shipping config to create:', defaultConfig);
      console.log('⚠️ This requires admin API access and should be done in Swell dashboard');
      
      return defaultConfig;
    } catch (error) {
      console.error('❌ Failed to create default shipping config:', error);
      return null;
    }
  }

  /**
   * Get suggestions for fixing common issues
   */
  getSuggestions(diagnostics) {
    const suggestions = [];

    if (!diagnostics.connection.success) {
      suggestions.push({
        issue: 'Connection Failed',
        solution: 'Check Swell SDK initialization and API credentials'
      });
    }

    if (!diagnostics.shipping.success) {
      suggestions.push({
        issue: 'Shipping Not Configured',
        solution: 'Configure shipping zones and services in Swell dashboard'
      });
    } else if (diagnostics.shipping.zones.length === 0) {
      suggestions.push({
        issue: 'No Shipping Zones',
        solution: 'Create shipping zones for your target countries in Swell dashboard'
      });
    }

    if (!diagnostics.coupons.success) {
      suggestions.push({
        issue: 'Coupons Not Configured',
        solution: 'Enable coupons in Swell dashboard settings'
      });
    }

    if (!diagnostics.payments.success) {
      suggestions.push({
        issue: 'Payments Not Configured',
        solution: 'Configure payment methods in Swell dashboard'
      });
    }

    return suggestions;
  }
}

// Export utility functions for console use
export const swellDebug = {
  // Run full diagnostics
  diagnose: async () => {
    const helper = new SwellConfigHelper();
    const results = await helper.runStoreDiagnostics();
    const suggestions = helper.getSuggestions(results);
    
    console.log('🔧 Suggestions:', suggestions);
    return { results, suggestions };
  },

  // Quick shipping test
  testShipping: async () => {
    const helper = new SwellConfigHelper();
    return await helper.testShippingCalculation();
  },

  // Check specific configuration
  checkShipping: async () => {
    const helper = new SwellConfigHelper();
    return await helper.checkShippingConfiguration();
  },

  // Get default config template
  getDefaultConfig: async () => {
    const helper = new SwellConfigHelper();
    return await helper.createDefaultShippingConfig();
  }
};

// Make available globally for debugging
if (typeof window !== 'undefined') {
  window.swellDebug = swellDebug;
}

export default SwellConfigHelper;