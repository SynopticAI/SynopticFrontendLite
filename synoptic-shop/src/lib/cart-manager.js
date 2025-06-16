// src/lib/cart-manager.js - Fixed version with proper error handling
import { 
  getCart, 
  addToCart, 
  removeFromCart, 
  updateCartItem, 
  clearCart,
  getCartItemCount,
  getCartSubtotal,
  formatPrice
} from './swell.js';
import authStateManager from './auth-state-manager.js';

class CartManager {
  constructor() {
    this.cart = null;
    this.isLoading = false;
    this.subscribers = new Set();
    this.currentUser = null;
    this.authUnsubscribe = null;
    this.swellAuthComplete = false;
    this.addToCartInProgress = false; // Prevent multiple simultaneous adds
    
    // Initialize cart
    this.init();
  }

  async init() {
    console.log('🛒 Initializing cart manager with centralized auth...');
    
    try {
      // Subscribe to centralized auth state changes
      this.authUnsubscribe = authStateManager.subscribe((user) => {
        console.log('🛒 Cart: Auth state changed:', user ? `✅ ${user.email}` : '❌ Not authenticated');
        this.handleAuthStateChange(user);
      });

      // Listen for Swell authentication completion
      window.addEventListener('swellAuthComplete', (e) => {
        console.log('🛒 Cart: Swell auth completed for account:', e.detail.account?.id);
        this.swellAuthComplete = true;
        this.handleSwellAuthComplete(e.detail.account);
      });

      // Wait for auth to be ready and then refresh cart
      await authStateManager.waitForReady();
      await this.refreshCart();
      
    } catch (error) {
      console.error('🛒 Error initializing cart manager:', error);
      // Still try to load cart even if auth fails
      await this.refreshCart();
    }
  }

  async handleAuthStateChange(user) {
    const previousUser = this.currentUser;
    this.currentUser = user;
    
    if (user && !previousUser) {
      // User just signed in - wait for Swell auth to complete
      console.log('🛒 User signed in, waiting for Swell authentication...');
      this.swellAuthComplete = false;
      
      // Wait up to 10 seconds for Swell auth to complete
      let attempts = 0;
      while (!this.swellAuthComplete && attempts < 100) { // 10 seconds
        await new Promise(resolve => setTimeout(resolve, 100));
        attempts++;
      }
      
      if (this.swellAuthComplete) {
        console.log('🛒 Swell auth completed, refreshing cart...');
      } else {
        console.log('🛒 Swell auth timeout, refreshing cart anyway...');
      }
      
      await this.refreshCart();
      
    } else if (!user && previousUser) {
      // User signed out - refresh cart to get guest cart
      console.log('🛒 User signed out, refreshing cart...');
      this.swellAuthComplete = false;
      await this.refreshCart();
      
    } else if (user && previousUser && user.uid !== previousUser.uid) {
      // Different user signed in - refresh cart for new user
      console.log('🛒 Different user signed in, refreshing cart...');
      this.swellAuthComplete = false;
      await this.refreshCart();
    }
  }

  async handleSwellAuthComplete(swellAccount) {
    console.log('🛒 Handling Swell auth completion...');
    
    try {
      // Force refresh cart to get the account-associated version
      await this.refreshCart();
      
      // Verify cart is properly associated
      if (this.cart && this.cart.account_id) {
        console.log('✅ Cart successfully associated with Swell account:', this.cart.account_id);
      } else {
        console.warn('⚠️ Cart may not be properly associated with account');
        
        // Try to force association
        if (window.swellAuthIntegration) {
          console.log('🛒 Attempting to force cart association...');
          await window.swellAuthIntegration.forceCartAssociation();
          await this.refreshCart();
        }
      }
      
    } catch (error) {
      console.error('🛒 Error handling Swell auth completion:', error);
    }
  }

  /**
   * Add item to cart with proper error handling and validation
   * @param {string} productId - Product ID
   * @param {number} quantity - Quantity
   * @param {Object} options - Options
   * @param {string} variantId - Variant ID
   * @returns {Promise<Object>} Result
   */
  async addItemToCart(productId, quantity = 1, options = {}, variantId = null) {
    // Prevent multiple simultaneous add operations
    if (this.addToCartInProgress) {
      console.log('🛒 Add to cart already in progress, ignoring...');
      return { success: false, error: 'Add to cart operation already in progress' };
    }

    this.addToCartInProgress = true;

    try {
      this.isLoading = true;
      this.notifySubscribers();
      
      // ✅ FIX 1: Ensure productId is a string, not an object
      const cleanProductId = typeof productId === 'object' ? productId.id || productId.toString() : productId;
      
      console.log('🛒 Adding item to cart:', { 
        productId: cleanProductId, 
        quantity, 
        variantId,
        options 
      });

      // ✅ FIX 2: Validate inputs
      if (!cleanProductId) {
        throw new Error('Product ID is required');
      }

      if (quantity <= 0) {
        throw new Error('Quantity must be greater than 0');
      }

      // ✅ FIX 3: Check if product exists first
      try {
        const product = await swell.products.get(cleanProductId);
        if (!product) {
          throw new Error(`Product ${cleanProductId} not found`);
        }
        
        if (!product.active) {
          throw new Error(`Product ${product.name} is not active`);
        }
        
        console.log('✅ Product validation passed:', product.name);
      } catch (productError) {
        console.error('❌ Product validation failed:', productError);
        throw new Error(`Product validation failed: ${productError.message}`);
      }

      // Wait for Swell auth if user is authenticated
      if (this.currentUser && !this.swellAuthComplete) {
        console.log('🛒 User authenticated, waiting for Swell auth completion...');
        
        let attempts = 0;
        while (!this.swellAuthComplete && attempts < 30) { // 3 seconds max
          await new Promise(resolve => setTimeout(resolve, 100));
          attempts++;
        }
        
        if (!this.swellAuthComplete) {
          console.warn('⚠️ Swell auth not complete, proceeding anyway...');
        }
      }
      
      // ✅ FIX 4: Prepare item data with proper validation
      const itemData = {
        product_id: cleanProductId,
        quantity: parseInt(quantity)
      };
      
      if (variantId) {
        itemData.variant_id = variantId;
      }
      
      if (options && Object.keys(options).length > 0) {
        itemData.options = options;
      }
      
      console.log('🛒 Sending to Swell:', itemData);
      
      // ✅ FIX 5: Add to cart with better error handling
      const result = await addToCart(itemData);
      
      if (result) {
        console.log('✅ Item added to cart successfully');
        
        // Refresh cart to get updated state
        await this.refreshCart();
        
        // Emit custom event for UI updates
        window.dispatchEvent(new CustomEvent('cartItemAdded', { 
          detail: { productId: cleanProductId, quantity, cart: this.cart } 
        }));
        
        return { success: true, cart: this.cart, error: null };
      } else {
        throw new Error('Failed to add item to cart - no result returned');
      }
      
    } catch (error) {
      console.error('❌ Error adding item to cart:', error);
      
      // ✅ FIX 6: Better error messages
      let errorMessage = error.message || 'Failed to add item to cart';
      
      if (error.message?.includes('not found')) {
        errorMessage = 'This product is no longer available';
      } else if (error.message?.includes('not active')) {
        errorMessage = 'This product is currently unavailable';
      } else if (error.message?.includes('out of stock')) {
        errorMessage = 'This product is out of stock';
      }
      
      return { success: false, cart: null, error: errorMessage };
    } finally {
      this.isLoading = false;
      this.addToCartInProgress = false; // ✅ FIX 7: Always reset the flag
      this.notifySubscribers();
    }
  }

  /**
   * Subscribe to cart changes
   * @param {Function} callback - Callback function
   * @returns {Function} Unsubscribe function
   */
  subscribe(callback) {
    this.subscribers.add(callback);
    
    // Call immediately with current state
    callback(this.getState());
    
    // Return unsubscribe function
    return () => {
      this.subscribers.delete(callback);
    };
  }

  /**
   * Notify all subscribers of cart changes
   */
  notifySubscribers() {
    const state = this.getState();
    this.subscribers.forEach(callback => {
      try {
        callback(state);
      } catch (error) {
        console.error('🛒 Error in cart subscriber callback:', error);
      }
    });
  }

  /**
   * Get current cart state
   * @returns {Object} Cart state
   */
  getState() {
    return {
      cart: this.cart,
      isLoading: this.isLoading,
      itemCount: this.getItemCount(),
      subtotal: this.getSubtotal(),
      formattedSubtotal: this.getFormattedSubtotal(),
      currentUser: this.currentUser,
      isAuthenticated: !!this.currentUser,
      isAssociated: !!(this.cart?.account_id),
      swellAuthComplete: this.swellAuthComplete,
      addToCartInProgress: this.addToCartInProgress
    };
  }

  /**
   * Refresh cart from Swell
   */
  async refreshCart() {
    try {
      this.isLoading = true;
      this.notifySubscribers();
      
      console.log('🛒 Refreshing cart from Swell...');
      this.cart = await getCart();
      
      const itemCount = this.getItemCount();
      console.log('🛒 Cart refreshed:', this.cart ? `${itemCount} items` : 'Empty cart');
      
      // Check if cart is associated with authenticated user
      if (this.currentUser && this.cart) {
        const hasAccount = this.cart.account_id || this.cart.account;
        if (!hasAccount) {
          console.log('⚠️ Cart not associated with account');
          
          // If we have a current user but cart isn't associated, try to fix it
          if (this.swellAuthComplete && window.swellAuthIntegration) {
            console.log('🛒 Attempting to associate cart with authenticated user...');
            setTimeout(async () => {
              try {
                await window.swellAuthIntegration.forceCartAssociation();
                await this.refreshCart();
              } catch (error) {
                console.error('🛒 Failed to associate cart:', error);
              }
            }, 1000);
          }
        } else {
          console.log('✅ Cart properly associated with authenticated account');
        }
      }
      
    } catch (error) {
      console.error('🛒 Error refreshing cart:', error);
      this.cart = null;
    } finally {
      this.isLoading = false;
      this.notifySubscribers();
    }
  }

  /**
   * Remove item from cart
   * @param {string} itemId - Cart item ID
   * @returns {Promise<Object>} Result
   */
  async removeItemFromCart(itemId) {
    try {
      this.isLoading = true;
      this.notifySubscribers();
      
      console.log('🛒 Removing item from cart:', itemId);
      
      const result = await removeFromCart(itemId);
      
      if (result) {
        console.log('✅ Item removed from cart successfully');
        await this.refreshCart();
        
        window.dispatchEvent(new CustomEvent('cartItemRemoved', { 
          detail: { itemId, cart: this.cart } 
        }));
        
        return { success: true, cart: this.cart, error: null };
      } else {
        throw new Error('Failed to remove item from cart');
      }
      
    } catch (error) {
      console.error('🛒 Error removing item from cart:', error);
      return { success: false, cart: null, error: error.message };
    } finally {
      this.isLoading = false;
      this.notifySubscribers();
    }
  }

  /**
   * Update cart item quantity
   * @param {string} itemId - Cart item ID
   * @param {number} quantity - New quantity
   * @returns {Promise<Object>} Result
   */
  async updateItemQuantity(itemId, quantity) {
    try {
      this.isLoading = true;
      this.notifySubscribers();
      
      console.log('🛒 Updating cart item quantity:', { itemId, quantity });
      
      const result = await updateCartItem(itemId, { quantity });
      
      if (result) {
        console.log('✅ Cart item quantity updated successfully');
        await this.refreshCart();
        
        window.dispatchEvent(new CustomEvent('cartItemUpdated', { 
          detail: { itemId, quantity, cart: this.cart } 
        }));
        
        return { success: true, cart: this.cart, error: null };
      } else {
        throw new Error('Failed to update cart item');
      }
      
    } catch (error) {
      console.error('🛒 Error updating cart item:', error);
      return { success: false, cart: null, error: error.message };
    } finally {
      this.isLoading = false;
      this.notifySubscribers();
    }
  }

  /**
   * Clear entire cart
   * @returns {Promise<Object>} Result
   */
  async clearEntireCart() {
    try {
      this.isLoading = true;
      this.notifySubscribers();
      
      console.log('🛒 Clearing entire cart...');
      
      const result = await clearCart();
      
      if (result) {
        console.log('✅ Cart cleared successfully');
        await this.refreshCart();
        
        window.dispatchEvent(new CustomEvent('cartCleared', { 
          detail: { cart: this.cart } 
        }));
        
        return { success: true, cart: this.cart, error: null };
      } else {
        throw new Error('Failed to clear cart');
      }
      
    } catch (error) {
      console.error('🛒 Error clearing cart:', error);
      return { success: false, cart: null, error: error.message };
    } finally {
      this.isLoading = false;
      this.notifySubscribers();
    }
  }

  /**
   * Get cart item count
   * @returns {number} Number of items in cart
   */
  getItemCount() {
    if (!this.cart || !this.cart.items) return 0;
    return this.cart.items.reduce((total, item) => total + (item.quantity || 0), 0);
  }

  /**
   * Get cart subtotal
   * @returns {number} Cart subtotal
   */
  getSubtotal() {
    return this.cart?.sub_total || 0;
  }

  /**
   * Get formatted cart subtotal
   * @returns {string} Formatted cart subtotal
   */
  getFormattedSubtotal() {
    return formatPrice(this.getSubtotal());
  }

  /**
   * Check if cart is empty
   * @returns {boolean} True if cart is empty
   */
  isEmpty() {
    return this.getItemCount() === 0;
  }

  /**
   * Debug method
   */
  debug() {
    console.group('🛒 Cart Manager Debug');
    console.log('Current User:', this.currentUser?.email || 'None');
    console.log('Swell Auth Complete:', this.swellAuthComplete);
    console.log('Is Loading:', this.isLoading);
    console.log('Add to Cart in Progress:', this.addToCartInProgress);
    console.log('Cart:', this.cart ? {
      id: this.cart.id,
      account_id: this.cart.account_id,
      items: this.cart.items?.length || 0,
      subtotal: this.getFormattedSubtotal()
    } : 'No cart');
    console.log('Subscribers:', this.subscribers.size);
    console.groupEnd();
  }

  /**
   * Cleanup method
   */
  destroy() {
    if (this.authUnsubscribe) {
      this.authUnsubscribe();
    }
    
    window.removeEventListener('swellAuthComplete', this.handleSwellAuthComplete);
  }
}

// Create singleton instance
const cartManager = new CartManager();

// Make available globally for debugging
if (typeof window !== 'undefined') {
  window.cartManager = cartManager;
}

export default cartManager;