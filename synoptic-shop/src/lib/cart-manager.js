// src/lib/cart-manager.js - Fixed cart state management with correct Swell integration
import { 
  getCart, 
  addToCart, 
  removeFromCart, 
  updateCartItem, 
  clearCart,
  getCartItemCount,
  getCartSubtotal,
  associateCartWithAccount,
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
      // User just signed in - cart will be automatically associated via Swell auth integration
      console.log('🛒 User signed in, refreshing cart to get user-associated cart...');
      // Small delay to allow Swell auth integration to complete
      setTimeout(async () => {
        await this.refreshCart();
      }, 1000);
      
    } else if (!user && previousUser) {
      // User signed out - refresh cart to get guest cart
      console.log('🛒 User signed out, refreshing cart...');
      await this.refreshCart();
      
    } else if (user && previousUser && user.uid !== previousUser.uid) {
      // Different user signed in - refresh cart for new user
      console.log('🛒 Different user signed in, refreshing cart...');
      setTimeout(async () => {
        await this.refreshCart();
      }, 1000);
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
      isAuthenticated: !!this.currentUser
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
          console.log('🛒 Cart not associated with account, may need re-authentication');
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
   * Add item to cart with proper user context
   * @param {string} productId - Product ID
   * @param {number} quantity - Quantity
   * @param {Object} options - Options
   * @param {string} variantId - Variant ID
   * @returns {Promise<Object>} Result
   */
  async addItemToCart(productId, quantity = 1, options = {}, variantId = null) {
    try {
      this.isLoading = true;
      this.notifySubscribers();
      
      console.log('🛒 Adding item to cart:', { productId, quantity, variantId });
      
      // If user is authenticated, ensure Swell auth integration has completed
      if (this.currentUser) {
        console.log('🛒 User is authenticated, ensuring Swell integration is ready...');
        
        // Wait a moment for Swell auth integration to complete if needed
        await new Promise(resolve => setTimeout(resolve, 500));
        
        // Try to associate cart with account
        try {
          const associationResult = await associateCartWithAccount();
          if (associationResult.success) {
            console.log('✅ Cart associated with account before adding item');
          } else {
            console.log('⚠️ Cart association failed, but continuing with add to cart');
          }
        } catch (associationError) {
          console.log('⚠️ Cart association error:', associationError.message);
        }
      }
      
      const result = await addToCart(productId, quantity, options, variantId);
      
      if (result.success) {
        this.cart = result.cart;
        console.log('✅ Item added to cart successfully');
      } else {
        console.error('❌ Failed to add item to cart:', result.error);
      }
      
      return result;
      
    } catch (error) {
      console.error('🛒 Error adding item to cart:', error);
      return {
        success: false,
        cart: null,
        error: error.message || 'Failed to add item to cart'
      };
    } finally {
      this.isLoading = false;
      this.notifySubscribers();
    }
  }

  /**
   * Remove item from cart
   * @param {string} itemId - Item ID
   * @returns {Promise<Object>} Result
   */
  async removeItemFromCart(itemId) {
    try {
      this.isLoading = true;
      this.notifySubscribers();
      
      console.log('🛒 Removing item from cart:', itemId);
      const result = await removeFromCart(itemId);
      
      if (result.success) {
        this.cart = result.cart;
        console.log('✅ Item removed from cart successfully');
      }
      
      return result;
      
    } catch (error) {
      console.error('🛒 Error removing item from cart:', error);
      return {
        success: false,
        cart: null,
        error: error.message || 'Failed to remove item from cart'
      };
    } finally {
      this.isLoading = false;
      this.notifySubscribers();
    }
  }

  /**
   * Update cart item quantity
   * @param {string} itemId - Item ID
   * @param {number} quantity - New quantity
   * @returns {Promise<Object>} Result
   */
  async updateItemQuantity(itemId, quantity) {
    try {
      this.isLoading = true;
      this.notifySubscribers();
      
      console.log('🛒 Updating item quantity:', { itemId, quantity });
      const result = await updateCartItem(itemId, { quantity });
      
      if (result.success) {
        this.cart = result.cart;
        console.log('✅ Item quantity updated successfully');
      }
      
      return result;
      
    } catch (error) {
      console.error('🛒 Error updating item quantity:', error);
      return {
        success: false,
        cart: null,
        error: error.message || 'Failed to update item quantity'
      };
    } finally {
      this.isLoading = false;
      this.notifySubscribers();
    }
  }

  /**
   * Clear cart
   * @returns {Promise<Object>} Result
   */
  async clearCartItems() {
    try {
      this.isLoading = true;
      this.notifySubscribers();
      
      console.log('🛒 Clearing cart...');
      const result = await clearCart();
      
      if (result.success) {
        this.cart = result.cart;
        console.log('✅ Cart cleared successfully');
      }
      
      return result;
      
    } catch (error) {
      console.error('🛒 Error clearing cart:', error);
      return {
        success: false,
        cart: null,
        error: error.message || 'Failed to clear cart'
      };
    } finally {
      this.isLoading = false;
      this.notifySubscribers();
    }
  }

  /**
   * Get cart item count
   * @returns {number} Item count
   */
  getItemCount() {
    if (!this.cart || !this.cart.items) return 0;
    return this.cart.items.reduce((total, item) => total + (item.quantity || 0), 0);
  }

  /**
   * Get cart subtotal
   * @returns {number} Subtotal
   */
  getSubtotal() {
    if (!this.cart) return 0;
    return this.cart.sub_total || 0;
  }

  /**
   * Get formatted cart subtotal
   * @returns {string} Formatted subtotal
   */
  getFormattedSubtotal() {
    const subtotal = this.getSubtotal();
    return formatPrice(subtotal, this.cart?.currency || 'EUR');
  }

  /**
   * Get current user
   * @returns {Object|null} Current user
   */
  getCurrentUser() {
    return this.currentUser;
  }

  /**
   * Check if user is authenticated
   * @returns {boolean} Is authenticated
   */
  isAuthenticated() {
    return !!this.currentUser;
  }

  /**
   * Get cart for external access
   * @returns {Object|null} Cart object
   */
  getCart() {
    return this.cart;
  }

  /**
   * Force cart association with authenticated account
   * @returns {Promise<Object>} Result
   */
  async forceCartAssociation() {
    try {
      if (!this.currentUser) {
        return { success: false, error: 'No authenticated user' };
      }

      console.log('🛒 Forcing cart association with account...');
      const result = await associateCartWithAccount();
      
      if (result.success) {
        await this.refreshCart();
      }
      
      return result;
    } catch (error) {
      console.error('🛒 Error forcing cart association:', error);
      return { success: false, error: error.message };
    }
  }

  /**
   * Debug cart state
   */
  debug() {
    console.log('🛒 Cart Manager Debug:', {
      hasCart: !!this.cart,
      itemCount: this.getItemCount(),
      subtotal: this.getSubtotal(),
      currentUser: this.currentUser?.email || 'None',
      isAuthenticated: this.isAuthenticated(),
      subscriberCount: this.subscribers.size,
      isLoading: this.isLoading,
      cartAccountId: this.cart?.account_id || 'None',
      cartId: this.cart?.id || 'None'
    });
  }

  /**
   * Cleanup method
   */
  destroy() {
    if (this.authUnsubscribe) {
      this.authUnsubscribe();
    }
    this.subscribers.clear();
  }
}

// Create singleton instance
const cartManager = new CartManager();

// Make globally available for debugging
if (typeof window !== 'undefined') {
  window.cartManager = cartManager;
}

export default cartManager;