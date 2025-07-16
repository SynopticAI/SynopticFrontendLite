// src/lib/cart-session-fix.js - Fix for stale cart sessions and service worker interference

class CartSessionManager {
  constructor() {
    this.CART_SESSION_KEY = 'swell-cart-id';
    this.CART_DATA_KEY = 'swell-cart-data';
    this.SESSION_TIMEOUT = 24 * 60 * 60 * 1000; // 24 hours
  }

  /**
   * Clear all stale cart sessions and force fresh start
   */
  async clearStaleCartSession() {
    console.log('🧹 Clearing stale cart session...');
    
    try {
      // 1. Clear localStorage cart data
      const keysToRemove = [
        this.CART_SESSION_KEY,
        this.CART_DATA_KEY,
        'swell-session',
        'swell-cart',
        'cart-id',
        'checkout_cart'
      ];
      
      keysToRemove.forEach(key => {
        localStorage.removeItem(key);
        sessionStorage.removeItem(key);
      });
      
      // 2. Clear cookies that might contain cart data
      this.clearSwellCookies();
      
      // 3. Clear service worker cache
      await this.clearServiceWorkerCache();
      
      // 4. Force Swell to forget current cart
      if (window.swell) {
        try {
          // Reset Swell's internal cart state
          await window.swell.cart.setItems([]);
          console.log('✅ Swell cart cleared');
        } catch (error) {
          console.log('🔄 Swell cart reset failed (expected):', error.message);
        }
      }
      
      console.log('✅ Cart session cleared successfully');
      
    } catch (error) {
      console.error('❌ Error clearing cart session:', error);
    }
  }

  /**
   * Clear Swell-related cookies
   */
  clearSwellCookies() {
    const cookiesToClear = [
      'swell-cart',
      'swell-session',
      'swell-cart-id',
      'cart-id'
    ];
    
    cookiesToClear.forEach(cookieName => {
      // Clear for current domain
      document.cookie = `${cookieName}=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/;`;
      
      // Clear for all subdomains
      const domain = window.location.hostname.replace(/^[^.]*\./, '.');
      document.cookie = `${cookieName}=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/; domain=${domain};`;
    });
    
    console.log('🍪 Swell cookies cleared');
  }

  /**
   * Clear service worker cache that might be interfering
   */
  async clearServiceWorkerCache() {
    try {
      if ('serviceWorker' in navigator) {
        const registrations = await navigator.serviceWorker.getRegistrations();
        
        for (const registration of registrations) {
          console.log('🔄 Found service worker:', registration.scope);
          
          // Unregister Flutter service worker if it exists
          if (registration.scope.includes('app') || registration.scope.includes('flutter')) {
            console.log('🔄 Unregistering Flutter service worker...');
            await registration.unregister();
          }
        }
      }
      
      // Clear all caches
      if ('caches' in window) {
        const cacheNames = await caches.keys();
        
        for (const cacheName of cacheNames) {
          console.log('🧹 Clearing cache:', cacheName);
          await caches.delete(cacheName);
        }
      }
      
      console.log('✅ Service worker cache cleared');
      
    } catch (error) {
      console.error('❌ Error clearing service worker cache:', error);
    }
  }

  /**
   * Force a fresh cart fetch from Swell
   */
  async getFreshCart() {
    try {
      console.log('🔄 Fetching fresh cart from Swell...');
      
      // Wait for Swell to be ready
      await this.waitForSwell();
      
      // Get fresh cart data
      const freshCart = await window.swell.cart.get();
      
      console.log('✅ Fresh cart fetched:', freshCart);
      return freshCart;
      
    } catch (error) {
      console.error('❌ Error fetching fresh cart:', error);
      return null;
    }
  }

  /**
   * Wait for Swell to be available
   */
  async waitForSwell() {
    return new Promise((resolve) => {
      if (window.swell) {
        resolve(window.swell);
      } else {
        const checkSwell = () => {
          if (window.swell) {
            resolve(window.swell);
          } else {
            setTimeout(checkSwell, 100);
          }
        };
        checkSwell();
      }
    });
  }

  /**
   * Add item to cart with fresh session handling
   */
  async addItemWithFreshSession(productId, quantity = 1) {
    try {
      console.log('🛒 Adding item with fresh session handling...');
      
      // First try normal add
      let result = await window.swell.cart.addItem({
        product_id: productId,
        quantity: quantity
      });
      
      if (result && result.items) {
        console.log('✅ Item added successfully on first try');
        return result;
      }
      
      // If that failed, clear stale session and try again
      console.log('🔄 First attempt failed, clearing stale session...');
      await this.clearStaleCartSession();
      
      // Wait a moment for session to clear
      await new Promise(resolve => setTimeout(resolve, 500));
      
      // Try again with fresh session
      result = await window.swell.cart.addItem({
        product_id: productId,
        quantity: quantity
      });
      
      if (result && result.items) {
        console.log('✅ Item added successfully after session refresh');
        return result;
      }
      
      throw new Error('Failed to add item even after session refresh');
      
    } catch (error) {
      console.error('❌ Error adding item with fresh session:', error);
      throw error;
    }
  }

  /**
   * Debug cart session state
   */
  debugCartSession() {
    console.group('🔍 Cart Session Debug');
    
    // Check localStorage
    console.log('LocalStorage cart data:', {
      cartId: localStorage.getItem(this.CART_SESSION_KEY),
      cartData: localStorage.getItem(this.CART_DATA_KEY),
      swellSession: localStorage.getItem('swell-session'),
      swellCart: localStorage.getItem('swell-cart')
    });
    
    // Check sessionStorage
    console.log('SessionStorage cart data:', {
      checkoutCart: sessionStorage.getItem('checkout_cart'),
      synopticUser: sessionStorage.getItem('synoptic_user')
    });
    
    // Check cookies
    console.log('Cookies:', document.cookie);
    
    // Check service workers
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.getRegistrations().then(registrations => {
        console.log('Service Workers:', registrations.map(r => r.scope));
      });
    }
    
    console.groupEnd();
  }
}

// Create global instance
const cartSessionManager = new CartSessionManager();

// Make available globally
if (typeof window !== 'undefined') {
  window.cartSessionManager = cartSessionManager;
}

export default cartSessionManager;