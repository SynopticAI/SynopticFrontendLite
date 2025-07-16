// src/scripts/cart-handler.js - Robust cart handler that prevents infinite loops
import { formatPrice, getProductImageUrl } from '../lib/swell.js';

class CartHandler {
  constructor() {
    this.isDrawerOpen = false;
    this.cart = null;
    this.isLoading = false;
    this.subscribers = new Set();
    
    // 🔧 SAFETY: Prevent infinite loops with operation tracking
    this.activeOperations = new Set();
    this.lastOperationTime = 0;
    this.operationCooldown = 1000; // 1 second between operations
    
    this.init();
  }

  init() {
    console.log('🛒 Initializing robust cart handler...');
    
    // Wait for DOM to be ready
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', () => this.setupDOM());
    } else {
      this.setupDOM();
    }
  }

  setupDOM() {
    this.setupDrawerEventListeners();
    this.setupProductPageIntegration();
    this.safeRefreshCart();
  }

  // 🔧 SAFETY: Prevent duplicate operations
  canPerformOperation(operationType) {
    const now = Date.now();
    const operationKey = `${operationType}_${now}`;
    
    // Check cooldown
    if (now - this.lastOperationTime < this.operationCooldown) {
      console.log('🛡️ Operation blocked by cooldown');
      return false;
    }
    
    // Check if same operation is already running
    if (this.activeOperations.has(operationType)) {
      console.log('🛡️ Operation already in progress:', operationType);
      return false;
    }
    
    this.activeOperations.add(operationType);
    this.lastOperationTime = now;
    return true;
  }

  finishOperation(operationType) {
    this.activeOperations.delete(operationType);
  }

  setupDrawerEventListeners() {
    // Open cart drawer
    const cartButton = document.getElementById('cart-button');
    if (cartButton) {
      const isCartPage = window.location.pathname === '/cart' || window.location.pathname === '/cart/';
      
      if (isCartPage) {
        cartButton.style.opacity = '0.5';
        cartButton.title = 'You are already viewing your cart';
        
        cartButton.replaceWith(cartButton.cloneNode(true));
        const newCartButton = document.getElementById('cart-button');
        
        newCartButton.addEventListener('click', (e) => {
          e.preventDefault();
          e.stopPropagation();
          return false;
        });
      } else {
        cartButton.addEventListener('click', () => this.openDrawer());
      }
    }

    // Close cart drawer
    const closeButton = document.getElementById('close-cart-drawer');
    const backdrop = document.getElementById('cart-backdrop');
    
    if (closeButton) {
      closeButton.addEventListener('click', () => this.closeDrawer());
    }
    
    if (backdrop) {
      backdrop.addEventListener('click', () => this.closeDrawer());
    }

    // Continue shopping
    const continueShoppingBtn = document.getElementById('continue-shopping');
    if (continueShoppingBtn) {
      continueShoppingBtn.addEventListener('click', () => this.closeDrawer());
    }

    // Clear cart
    const clearCartBtn = document.getElementById('clear-cart-button');
    if (clearCartBtn) {
      clearCartBtn.addEventListener('click', () => this.handleClearCart());
    }

    // View Cart button
    const viewCartButton = document.getElementById('view-cart-button');
    if (viewCartButton) {
      viewCartButton.addEventListener('click', () => {
        window.location.href = '/cart';
      });
    }

    // Checkout button
    const checkoutButton = document.getElementById('checkout-button');
    if (checkoutButton) {
      checkoutButton.addEventListener('click', () => {
        const validation = this.validateCartForCheckout();
        if (validation.valid) {
          this.goToCheckout();
        } else {
          this.showError(validation.error);
        }
      });
    }
  }

  setupProductPageIntegration() {
    const addToCartBtn = document.getElementById('add-to-cart-btn');
    
    if (addToCartBtn && !addToCartBtn.dataset.handlerAttached) {
      addToCartBtn.addEventListener('click', async (e) => {
        e.preventDefault();
        
        // 🔧 SAFETY: Prevent rapid clicking
        if (!this.canPerformOperation('add_to_cart')) {
          return;
        }
        
        try {
          const productData = window.productData;
          if (!productData) {
            this.showError('Product data not available');
            return;
          }
          
          const quantityInput = document.getElementById('quantity-input');
          const quantity = quantityInput ? parseInt(quantityInput.value) || 1 : 1;

          console.log('🛒 Adding product to cart:', {
            productId: productData.id,
            productSlug: productData.slug,
            quantity: quantity
          });

          await this.safeAddToCart(productData.id, quantity);
          
        } finally {
          this.finishOperation('add_to_cart');
        }
      });
      
      addToCartBtn.dataset.handlerAttached = 'true';
      console.log('🛒 Attached handler to add-to-cart-btn');
    }
  }

  // 🔧 ROBUST: Safe add to cart with no infinite loops
  async safeAddToCart(productId, quantity = 1) {
    try {
      this.setLoading(true);
      console.log('🛒 Safe add to cart:', { productId, quantity });
      
      // Wait for Swell
      await this.waitForSwell();
      
      // 🔧 SAFETY: Clear any problematic cookies first
      this.cleanupBadCookies();
      
      // Simple add item call - NO RETRIES to prevent loops
      const result = await window.swell.cart.addItem({
        product_id: productId,
        quantity: quantity
      });
      
      if (result && result.items && result.items.length > 0) {
        console.log('✅ Item added successfully');
        this.cart = result;
        this.updateCartUI();
        this.notifySubscribers();
        this.showSuccess('Item added to cart!');
        this.openDrawer();
      } else {
        throw new Error('No items returned from cart');
      }
      
    } catch (error) {
      console.error('🛒 Add to cart failed:', error);
      
      // 🔧 SAFETY: Handle specific errors without retries
      if (error.message.includes('Unable to create cart') || error.message.includes('500')) {
        this.handleCartCreationError();
      } else {
        this.showError('Failed to add item to cart. Please refresh the page and try again.');
      }
      
    } finally {
      this.setLoading(false);
    }
  }

  // 🔧 SAFETY: Handle cart creation errors without infinite loops
  handleCartCreationError() {
    console.log('🔧 Handling cart creation error...');
    
    try {
      // Clear problematic data
      this.cleanupBadCookies();
      
      // Reset cart state
      this.cart = null;
      this.updateCartUI();
      
      // Show helpful error message
      this.showError('Cart system needs refresh. Please reload the page and try again.');
      
      // Don't automatically retry - let user control the retry
      
    } catch (cleanupError) {
      console.error('Error during cleanup:', cleanupError);
    }
  }

  // 🔧 SAFETY: Clean up problematic cookies
  cleanupBadCookies() {
    try {
      // Check for malformed currency cookie
      if (document.cookie.includes('swell-currency=%5Bobject%20Promise%5D')) {
        console.log('🧹 Cleaning malformed currency cookie');
        document.cookie = 'swell-currency=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/;';
        
        // Set proper currency
        if (window.swell?.currency?.select) {
          window.swell.currency.select('EUR').catch(() => {
            // Ignore currency setting errors
          });
        }
      }
    } catch (error) {
      console.log('Cookie cleanup failed:', error);
    }
  }

  // 🔧 ROBUST: Safe cart refresh
  async safeRefreshCart() {
    if (!this.canPerformOperation('refresh_cart')) {
      return;
    }
    
    try {
      this.setLoading(true);
      console.log('🛒 Safe refresh cart...');
      
      await this.waitForSwell();
      
      const cart = await window.swell.cart.get();
      
      if (cart) {
        this.cart = cart;
        console.log('✅ Cart refreshed successfully');
      } else {
        console.log('📭 No cart found (empty cart)');
        this.cart = null;
      }
      
      this.updateCartUI();
      this.notifySubscribers();
      
    } catch (error) {
      console.error('🛒 Error refreshing cart:', error);
      // Don't throw - just set empty state
      this.cart = null;
      this.updateCartUI();
      
    } finally {
      this.setLoading(false);
      this.finishOperation('refresh_cart');
    }
  }

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

  subscribe(callback) {
    this.subscribers.add(callback);
    
    // Call immediately with current state
    if (typeof callback === 'function') {
      try {
        callback();
      } catch (error) {
        console.error('🛒 Error in cart subscriber:', error);
      }
    }
    
    return () => {
      this.subscribers.delete(callback);
    };
  }

  notifySubscribers() {
    this.subscribers.forEach(callback => {
      try {
        if (typeof callback === 'function') {
          callback();
        }
      } catch (error) {
        console.error('🛒 Error in cart subscriber callback:', error);
      }
    });
  }

  openDrawer() {
    console.log('🛒 Opening cart drawer...');
    
    const overlay = document.getElementById('cart-overlay');
    const drawer = document.getElementById('cart-drawer');
    
    if (overlay && drawer) {
      overlay.classList.remove('hidden');
      overlay.classList.add('open');
      
      setTimeout(() => {
        drawer.classList.remove('translate-x-full');
        drawer.classList.add('translate-x-0', 'open');
      }, 10);
      
      this.isDrawerOpen = true;
    }
  }

  closeDrawer() {
    console.log('🛒 Closing cart drawer...');
    
    const overlay = document.getElementById('cart-overlay');
    const drawer = document.getElementById('cart-drawer');
    
    if (overlay && drawer) {
      drawer.classList.remove('translate-x-0');
      drawer.classList.add('translate-x-full');
      drawer.classList.remove('open');
      
      setTimeout(() => {
        overlay.classList.add('hidden');
        overlay.classList.remove('open');
      }, 300);
      
      this.isDrawerOpen = false;
    }
  }

  async clearCart() {
    if (!this.canPerformOperation('clear_cart')) {
      return;
    }
    
    try {
      this.setLoading(true);
      
      const swell = window.swell;
      if (swell && this.cart && this.cart.items) {
        for (const item of this.cart.items) {
          await swell.cart.removeItem(item.id);
        }
      }
      
      await this.safeRefreshCart();
      console.log('🛒 Cart cleared successfully');
      
    } catch (error) {
      console.error('🛒 Error clearing cart:', error);
      this.showError('Failed to clear cart');
    } finally {
      this.setLoading(false);
      this.finishOperation('clear_cart');
    }
  }

  handleClearCart() {
    if (confirm('Are you sure you want to clear your cart? This cannot be undone.')) {
      this.clearCart();
    }
  }

  updateCartUI() {
    const cartItemsContainer = document.getElementById('cart-items-list');
    const cartSubtotal = document.getElementById('cart-subtotal');
    const cartHeaderCount = document.getElementById('cart-header-count');
    const cartEmpty = document.getElementById('cart-empty');
    const cartItems = document.getElementById('cart-items');
    
    if (!this.cart || !this.cart.items || this.cart.items.length === 0) {
      // Show empty state
      if (cartEmpty) cartEmpty.classList.remove('hidden');
      if (cartItems) cartItems.classList.add('hidden');
      if (cartHeaderCount) cartHeaderCount.textContent = '(0 items)';
      return;
    }
    
    // Show items
    if (cartEmpty) cartEmpty.classList.add('hidden');
    if (cartItems) cartItems.classList.remove('hidden');
    
    // Update header count
    if (cartHeaderCount) {
      cartHeaderCount.textContent = `(${this.cart.items.length} item${this.cart.items.length !== 1 ? 's' : ''})`;
    }
    
    // Update subtotal
    if (cartSubtotal) {
      const subtotal = this.cart.sub_total || this.cart.subtotal || 0;
      cartSubtotal.textContent = formatPrice(subtotal);
    }
    
    // Update items list
    if (cartItemsContainer) {
      cartItemsContainer.innerHTML = '';
      this.cart.items.forEach(item => {
        const itemElement = this.createCartItemElement(item);
        cartItemsContainer.appendChild(itemElement);
      });
    }
  }

  createCartItemElement(item) {
    const itemDiv = document.createElement('div');
    itemDiv.className = 'cart-item';
    
    // 🔧 FIX: Better image URL handling
    const imageUrl = this.getItemImageUrl(item);
    const productName = item.product?.name || 'Unknown Product';
    const quantity = item.quantity || 1;
    const price = item.price_total || item.price || 0;
    
    itemDiv.innerHTML = `
      <img src="${imageUrl}" alt="${productName}" class="cart-item-image" 
           onerror="this.src='data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAiIGhlaWdodD0iNDAiIHZpZXdCb3g9IjAgMCA0MCA0MCIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KPHJlY3Qgd2lkdGg9IjQwIiBoZWlnaHQ9IjQwIiBmaWxsPSIjRjNGNEY2Ii8+CjxwYXRoIGQ9Ik0yMCAxNkMyMS42NTY5IDE2IDIzIDEyLjY1NjkgMjMgMTFDMjMgOS4zNDMxNSAyMS42NTY5IDggMjAgOEMxOC4zNDMxIDggMTcgOS4zNDMxNSAxNyAxMUMxNyAxMi42NTY5IDE4LjM0MzEgMTYgMjAgMTZaIiBmaWxsPSIjOUI5QjlCIi8+CjxwYXRoIGQ9Ik0yNiAyNkgyNlYyNEgyNlYyNloiIGZpbGw9IiM5QjlCOUIiLz4KPC9zdmc+Cg=='" />
      <div class="cart-item-details">
        <h4 class="cart-item-title">${productName}</h4>
        <p class="cart-item-price">${formatPrice(price)}</p>
        <div class="cart-item-controls">
          <div class="quantity-control">
            <button class="quantity-btn" onclick="window.cartHandler.updateQuantity('${item.id}', ${quantity - 1})">-</button>
            <input type="number" class="quantity-input" value="${quantity}" min="1" 
                   onchange="window.cartHandler.updateQuantity('${item.id}', this.value)" />
            <button class="quantity-btn" onclick="window.cartHandler.updateQuantity('${item.id}', ${quantity + 1})">+</button>
          </div>
          <button class="remove-btn" onclick="window.cartHandler.removeItem('${item.id}')">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M3 6h18M8 6V4a2 2 0 012-2h4a2 2 0 012 2v2M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6"/>
            </svg>
          </button>
        </div>
      </div>
    `;
    
    return itemDiv;
  }

  // 🔧 FIX: Local image URL method that works reliably
  getItemImageUrl(item) {
    // Try multiple image sources in order of preference
    if (item.product?.images && item.product.images.length > 0) {
      const image = item.product.images[0];
      if (image.file?.url) return image.file.url;
      if (image.url) return image.url;
    }
    
    if (item.variant?.images && item.variant.images.length > 0) {
      const image = item.variant.images[0];
      if (image.file?.url) return image.file.url;
      if (image.url) return image.url;
    }
    
    // Fallback to a simple placeholder
    return 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAiIGhlaWdodD0iNDAiIHZpZXdCb3g9IjAgMCA0MCA0MCIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KPHJlY3Qgd2lkdGg9IjQwIiBoZWlnaHQ9IjQwIiBmaWxsPSIjRjNGNEY2Ii8+CjxwYXRoIGQ9Ik0yMCAxNkMyMS42NTY5IDE2IDIzIDEyLjY1NjkgMjMgMTFDMjMgOS4zNDMxNSAyMS42NTY5IDggMjAgOEMxOC4zNDMxIDggMTcgOS4zNDMxNSAxNyAxMUMxNyAxMi42NTY5IDE4LjM0MzEgMTYgMjAgMTZaIiBmaWxsPSIjOUI5QjlCIi8+CjxwYXRoIGQ9Ik0yNiAyNkgyNlYyNEgyNlYyNloiIGZpbGw9IiM5QjlCOUIiLz4KPC9zdmc+Cg==';
  }

  async updateQuantity(itemId, newQuantity) {
    if (!this.canPerformOperation(`update_${itemId}`)) {
      return;
    }
    
    try {
      const quantity = parseInt(newQuantity);
      if (quantity < 1) {
        await this.removeItem(itemId);
        return;
      }
      
      this.setLoading(true);
      
      const swell = window.swell;
      if (swell) {
        const updatedCart = await swell.cart.updateItem(itemId, { quantity });
        this.cart = updatedCart;
        this.updateCartUI();
        this.notifySubscribers();
      }
      
    } catch (error) {
      console.error('🛒 Error updating quantity:', error);
      this.showError('Failed to update quantity');
    } finally {
      this.setLoading(false);
      this.finishOperation(`update_${itemId}`);
    }
  }

  async removeItem(itemId) {
    if (!this.canPerformOperation(`remove_${itemId}`)) {
      return;
    }
    
    try {
      this.setLoading(true);
      
      const swell = window.swell;
      if (swell) {
        const updatedCart = await swell.cart.removeItem(itemId);
        this.cart = updatedCart;
        this.updateCartUI();
        this.notifySubscribers();
      }
      
    } catch (error) {
      console.error('🛒 Error removing item:', error);
      this.showError('Failed to remove item');
    } finally {
      this.setLoading(false);
      this.finishOperation(`remove_${itemId}`);
    }
  }

  setLoading(loading) {
    this.isLoading = loading;
    
    const loadingEl = document.getElementById('cart-loading');
    if (loadingEl) {
      if (loading) {
        loadingEl.classList.remove('hidden');
      } else {
        loadingEl.classList.add('hidden');
      }
    }
  }

  showSuccess(message) {
    console.log('✅', message);
    // Simple success feedback
  }

  showError(message) {
    console.error('❌', message);
    // Simple error feedback - could be enhanced with toast notifications
    alert(message);
  }

  // Checkout integration methods
  validateCartForCheckout() {
    if (!this.cart || !this.cart.items || this.cart.items.length === 0) {
      return { valid: false, error: 'Your cart is empty' };
    }
    return { valid: true };
  }

  async goToCheckout() {
    try {
      if (!this.cart || !this.cart.items || this.cart.items.length === 0) {
        this.showError('Your cart is empty');
        return;
      }
      
      console.log('🛒 Navigating to checkout with cart:', this.cart);
      sessionStorage.setItem('checkout_cart', JSON.stringify(this.cart));
      window.location.href = '/checkout';
      
    } catch (error) {
      console.error('🛒 Error navigating to checkout:', error);
      this.showError('Failed to proceed to checkout');
    }
  }
}

// Initialize cart handler
const cartHandler = new CartHandler();

// Make available globally
if (typeof window !== 'undefined') {
  window.cartHandler = cartHandler;
}

export default cartHandler;