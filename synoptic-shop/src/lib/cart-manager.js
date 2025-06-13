// src/lib/cart-manager.js - Cart state management and operations
import { 
  getCart, 
  addToCart, 
  removeFromCart, 
  updateCartItem, 
  clearCart,
  getCartItemCount,
  getCartSubtotal,
  setCartCustomer,
  formatPrice
} from './swell.js';

class CartManager {
  constructor() {
    this.cart = null;
    this.isLoading = false;
    this.subscribers = new Set();
    this.currentUser = null;
    
    // Initialize cart
    this.init();
  }

  async init() {
    try {
      await this.refreshCart();
      
      // Listen for auth state changes
      if (window.authHandler) {
        window.authHandler.onAuthStateChange?.((user) => {
          this.handleAuthStateChange(user);
        });
      }
    } catch (error) {
      console.error('Error initializing cart manager:', error);
    }
  }

  async handleAuthStateChange(user) {
    this.currentUser = user;
    
    if (user) {
      // User signed in - associate cart with user
      try {
        const result = await setCartCustomer(user);
        if (result.success) {
          this.cart = result.cart;
          this.notifySubscribers();
        }
      } catch (error) {
        console.error('Error setting cart customer:', error);
      }
    } else {
      // User signed out - refresh cart to clear customer association
      await this.refreshCart();
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
        console.error('Error in cart subscriber callback:', error);
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
      formattedSubtotal: this.getFormattedSubtotal()
    };
  }

  /**
   * Refresh cart from Swell
   */
  async refreshCart() {
    try {
      this.isLoading = true;
      this.notifySubscribers();
      
      this.cart = await getCart();
      
      this.isLoading = false;
      this.notifySubscribers();
    } catch (error) {
      this.isLoading = false;
      console.error('Error refreshing cart:', error);
      this.notifySubscribers();
    }
  }

  /**
   * Add item to cart
   * @param {string} productId - Product ID
   * @param {number} quantity - Quantity
   * @param {Object} options - Product options
   * @param {string} variantId - Variant ID
   * @returns {Promise<Object>} Result
   */
  async addItem(productId, quantity = 1, options = {}, variantId = null) {
    try {
      this.isLoading = true;
      this.notifySubscribers();

      const result = await addToCart(productId, quantity, options, variantId);
      
      if (result.success) {
        this.cart = result.cart;
        
        // Show success notification
        this.showNotification(`Added to cart successfully!`, 'success');
      } else {
        this.showNotification(result.error || 'Failed to add item to cart', 'error');
      }

      this.isLoading = false;
      this.notifySubscribers();
      
      return result;
    } catch (error) {
      this.isLoading = false;
      this.notifySubscribers();
      console.error('Error adding item to cart:', error);
      this.showNotification('Failed to add item to cart', 'error');
      
      return {
        success: false,
        error: error.message
      };
    }
  }

  /**
   * Remove item from cart
   * @param {string} itemId - Item ID
   * @returns {Promise<Object>} Result
   */
  async removeItem(itemId) {
    try {
      this.isLoading = true;
      this.notifySubscribers();

      const result = await removeFromCart(itemId);
      
      if (result.success) {
        this.cart = result.cart;
        this.showNotification('Item removed from cart', 'success');
      } else {
        this.showNotification(result.error || 'Failed to remove item', 'error');
      }

      this.isLoading = false;
      this.notifySubscribers();
      
      return result;
    } catch (error) {
      this.isLoading = false;
      this.notifySubscribers();
      console.error('Error removing item from cart:', error);
      this.showNotification('Failed to remove item', 'error');
      
      return {
        success: false,
        error: error.message
      };
    }
  }

  /**
   * Update item quantity
   * @param {string} itemId - Item ID
   * @param {number} quantity - New quantity
   * @returns {Promise<Object>} Result
   */
  async updateItemQuantity(itemId, quantity) {
    try {
      this.isLoading = true;
      this.notifySubscribers();

      const result = await updateCartItem(itemId, quantity);
      
      if (result.success) {
        this.cart = result.cart;
      } else {
        this.showNotification(result.error || 'Failed to update quantity', 'error');
      }

      this.isLoading = false;
      this.notifySubscribers();
      
      return result;
    } catch (error) {
      this.isLoading = false;
      this.notifySubscribers();
      console.error('Error updating item quantity:', error);
      this.showNotification('Failed to update quantity', 'error');
      
      return {
        success: false,
        error: error.message
      };
    }
  }

  /**
   * Clear cart
   * @returns {Promise<Object>} Result
   */
  async clearCart() {
    try {
      this.isLoading = true;
      this.notifySubscribers();

      const result = await clearCart();
      
      if (result.success) {
        this.cart = result.cart;
        this.showNotification('Cart cleared', 'success');
      } else {
        this.showNotification(result.error || 'Failed to clear cart', 'error');
      }

      this.isLoading = false;
      this.notifySubscribers();
      
      return result;
    } catch (error) {
      this.isLoading = false;
      this.notifySubscribers();
      console.error('Error clearing cart:', error);
      this.showNotification('Failed to clear cart', 'error');
      
      return {
        success: false,
        error: error.message
      };
    }
  }

  /**
   * Get cart item count
   * @returns {number} Number of items
   */
  getItemCount() {
    if (!this.cart || !this.cart.items) return 0;
    return this.cart.items.reduce((total, item) => total + (item.quantity || 0), 0);
  }

  /**
   * Get cart subtotal
   * @returns {number} Subtotal amount
   */
  getSubtotal() {
    return this.cart?.sub_total || 0;
  }

  /**
   * Get formatted cart subtotal
   * @returns {string} Formatted subtotal
   */
  getFormattedSubtotal() {
    return formatPrice(this.getSubtotal(), this.cart?.currency || 'EUR');
  }

  /**
   * Check if cart is empty
   * @returns {boolean} True if cart is empty
   */
  isEmpty() {
    return this.getItemCount() === 0;
  }

  /**
   * Get cart items
   * @returns {Array} Cart items
   */
  getItems() {
    return this.cart?.items || [];
  }

  /**
   * Show notification
   * @param {string} message - Notification message
   * @param {string} type - Notification type (success, error, info)
   */
  showNotification(message, type = 'info') {
    // Create and show a temporary notification
    const notification = document.createElement('div');
    notification.className = `fixed top-4 right-4 z-50 p-4 rounded-lg shadow-lg max-w-sm transition-all duration-300 ${
      type === 'success' ? 'bg-green-500 text-white' :
      type === 'error' ? 'bg-red-500 text-white' :
      'bg-blue-500 text-white'
    }`;
    
    notification.innerHTML = `
      <div class="flex items-center space-x-3">
        <svg class="w-5 h-5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          ${type === 'success' ? 
            '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>' :
            type === 'error' ?
            '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>' :
            '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>'
          }
        </svg>
        <span class="text-sm font-medium">${message}</span>
      </div>
    `;

    document.body.appendChild(notification);

    // Animate in
    setTimeout(() => {
      notification.style.transform = 'translateX(0)';
      notification.style.opacity = '1';
    }, 10);

    // Remove after delay
    setTimeout(() => {
      notification.style.transform = 'translateX(100%)';
      notification.style.opacity = '0';
      setTimeout(() => {
        if (notification.parentNode) {
          notification.parentNode.removeChild(notification);
        }
      }, 300);
    }, 3000);
  }

  /**
   * Require authentication for cart operations
   * @param {Function} callback - Function to execute after auth
   */
  requireAuth(callback) {
    if (this.currentUser) {
      callback();
    } else {
      // Open auth modal if available
      if (window.authHandler) {
        window.authHandler.openModal('signin');
        
        // Listen for successful auth
        const unsubscribe = window.authHandler.onAuthStateChange?.((user) => {
          if (user) {
            callback();
            unsubscribe?.();
          }
        });
      } else {
        this.showNotification('Please sign in to continue', 'error');
      }
    }
  }
}

// Create and export singleton instance
const cartManager = new CartManager();

// Make available globally for debugging
if (typeof window !== 'undefined') {
  window.cartManager = cartManager;
}

export default cartManager;