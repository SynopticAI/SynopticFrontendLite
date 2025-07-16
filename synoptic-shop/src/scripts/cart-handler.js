// src/scripts/cart-handler.js - Complete cart handler with fixed drawer
import { formatPrice, getProductImageUrl } from '../lib/swell.js';

class CartHandler {
  constructor() {
    this.isDrawerOpen = false;
    this.cart = null;
    this.isLoading = false;
    this.subscribers = new Set();
    this.init();
  }

  init() {
    console.log('🛒 Initializing simple cart handler...');
    
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
    this.refreshCart();
  }

  setupDrawerEventListeners() {
    // Open cart drawer
    const cartButton = document.getElementById('cart-button');
    if (cartButton) {
      // 🔧 FIXED: Check for cart page properly (with AND without trailing slash)
      const isCartPage = window.location.pathname === '/cart' || window.location.pathname === '/cart/';
      
      if (isCartPage) {
        cartButton.style.opacity = '0.5';
        //cartButton.style.cursor = 'not-allowed';
        cartButton.title = 'You are already viewing your cart';
        
        // 🔧 FIXED: Remove ALL existing event listeners first
        cartButton.replaceWith(cartButton.cloneNode(true));
        const newCartButton = document.getElementById('cart-button');
        
        newCartButton.addEventListener('click', (e) => {
          e.preventDefault();
          e.stopPropagation();
          console.log('🛒 Cart button disabled on cart page');
          return false;
        });
      } else {
        // Normal cart button behavior
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

    // View Cart (go to cart page)
    const viewCartBtn = document.getElementById('view-cart-button');
    if (viewCartBtn) {
      viewCartBtn.addEventListener('click', () => this.handleViewCart());
    }


    // Checkout
    const checkoutBtn = document.getElementById('checkout-button');
    if (checkoutBtn) {
      checkoutBtn.addEventListener('click', () => this.handleCheckout());
    }

    // ESC key to close drawer
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' && this.isDrawerOpen) {
        this.closeDrawer();
      }
    });
  }

  setupProductPageIntegration() {
    // Handle add to cart button
    const addToCartBtn = document.getElementById('add-to-cart-btn');
    if (addToCartBtn && !addToCartBtn.dataset.handlerAttached) {
      
      addToCartBtn.addEventListener('click', async (e) => {
        e.preventDefault();
        
        // Get product data from window (set by product page)
        const productData = window.productData;
        
        if (!productData || !productData.id) {
          console.error('🛒 No product data available');
          this.showError('Product information not available');
          return;
        }

        // Get quantity
        const quantityInput = document.getElementById('quantity');
        const quantity = quantityInput ? parseInt(quantityInput.value) || 1 : 1;

        console.log('🛒 Adding product to cart:', {
          productId: productData.id,
          productSlug: productData.slug,
          quantity: quantity
        });

        await this.addProductToCart(productData.id, quantity);
      });
      
      addToCartBtn.dataset.handlerAttached = 'true';
      console.log('🛒 Attached handler to add-to-cart-btn');
    }
  }

  /**
   * Subscribe to cart changes (for AuthHeader compatibility)
   * @param {Function} callback - Callback function
   * @returns {Function} Unsubscribe function
   */
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
    
    // Return unsubscribe function
    return () => {
      this.subscribers.delete(callback);
    };
  }

  /**
   * Notify all subscribers of cart changes
   */
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


  async addProductToCart(productId, quantity = 1) {
    try {
      this.setLoading(true);
      
      console.log('🛒 Adding to cart:', { productId, quantity });

      // Get swell instance
      const swell = window.swell;
      if (!swell) {
        throw new Error('Swell not available');
      }

      // Simple Swell add to cart
      const result = await swell.cart.addItem({
        product_id: productId,
        quantity: quantity
      });

      if (result && result.items) {
        console.log('✅ Successfully added to cart');
        
        // Update cart state
        this.cart = result;
        this.updateCartUI();
        
        // Show success
        this.showSuccess('Item added to cart!');
        
        // Open cart drawer
        setTimeout(() => {
          this.openDrawer();
        }, 500);
        
        return { success: true, cart: result };
      } else {
        throw new Error('Invalid cart response');
      }
      
    } catch (error) {
      console.error('🛒 Error adding to cart:', error);
      
      // Try alternative method with different product reference
      if (error.message?.includes('not found') || error.message?.includes('not active')) {
        console.log('🛒 Trying alternative product lookup...');
        
        try {
          // Get product by slug instead
          const productData = window.productData;
          if (productData?.slug) {
            const swell = window.swell;
            const products = await swell.products.list({
              where: { slug: productData.slug },
              limit: 1
            });
            
            if (products.results && products.results.length > 0) {
              const foundProduct = products.results[0];
              console.log('🛒 Found product by slug:', foundProduct.id);
              
              const retryResult = await swell.cart.addItem({
                product_id: foundProduct.id,
                quantity: quantity
              });
              
              if (retryResult && retryResult.items) {
                console.log('✅ Successfully added to cart via slug lookup');
                this.cart = retryResult;
                this.updateCartUI();
                this.showSuccess('Item added to cart!');
                setTimeout(() => this.openDrawer(), 500);
                return { success: true, cart: retryResult };
              }
            }
          }
        } catch (retryError) {
          console.error('🛒 Retry also failed:', retryError);
        }
      }
      
      this.showError('Failed to add item to cart');
      return { success: false, error: error.message };
      
    } finally {
      this.setLoading(false);
    }
  }

  async refreshCart() {
    try {
      this.setLoading(true);
      
      const swell = window.swell;
      if (!swell) {
        console.warn('🛒 Swell not available for cart refresh');
        return;
      }

      this.cart = await swell.cart.get();
      console.log('🛒 Cart refreshed:', this.cart ? `${this.getItemCount()} items` : 'Empty');
      
      this.updateCartUI();
      this.notifySubscribers();
      
    } catch (error) {
      console.error('🛒 Error refreshing cart:', error);
    } finally {
      this.setLoading(false);
    }
  }

  async updateCartItem(itemId, quantity) {
    try {
      this.setLoading(true);
      
      const swell = window.swell;
      if (!swell) {
        throw new Error('Swell not available');
      }

      if (quantity <= 0) {
        return await this.removeCartItem(itemId);
      }

      const result = await swell.cart.updateItem(itemId, { quantity });
      
      if (result) {
        this.cart = result;
        this.updateCartUI();
        this.notifySubscribers();
        console.log('🛒 Cart item updated');
      }
      
      return result;
    } catch (error) {
      console.error('🛒 Error updating cart item:', error);
      this.showError('Failed to update item');
      throw error;
    } finally {
      this.setLoading(false);
    }
  }

  async removeCartItem(itemId) {
    try {
      this.setLoading(true);
      
      const swell = window.swell;
      if (!swell) {
        throw new Error('Swell not available');
      }

      const result = await swell.cart.removeItem(itemId);
      
      if (result) {
        this.cart = result;
        this.updateCartUI();
        this.notifySubscribers();
        console.log('🛒 Cart item removed');
      }
      
      return result;
    } catch (error) {
      console.error('🛒 Error removing cart item:', error);
      this.showError('Failed to remove item');
      throw error;
    } finally {
      this.setLoading(false);
    }
  }


  async openDrawer() {
    console.log('🛒 Opening cart drawer...');
    
    // 🔧 FIXED: Refresh cart data BEFORE opening drawer
    await this.refreshCart();
    
    const overlay = document.getElementById('cart-overlay');
    const drawer = document.getElementById('cart-drawer');
    
    if (overlay && drawer) {
      // Step 1: Show the overlay (remove hidden class)
      overlay.classList.remove('hidden');
      
      // Step 2: Add CSS class for overlay visibility
      overlay.classList.add('open');
      
      // Step 3: Slide in the drawer (remove translate-x-full, add translate-x-0)
      drawer.classList.remove('translate-x-full');
      drawer.classList.add('translate-x-0');
      
      // Step 4: Add CSS class for drawer
      drawer.classList.add('open');
      
      this.isDrawerOpen = true;
      console.log('🛒 Cart drawer opened with', this.getItemCount(), 'items');
      
      // 🔧 FIXED: Update drawer content after drawer is visible
      setTimeout(() => {
        this.updateDrawerContent();
      }, 150); // Small delay to ensure drawer is fully open
      
    } else {
      console.error('🛒 Cart drawer elements not found:', { overlay: !!overlay, drawer: !!drawer });
    }
  }

  // 🔧 FIXED: Proper drawer closing that handles both overlay and drawer
  closeDrawer() {
    console.log('🛒 Closing cart drawer...');
    
    const overlay = document.getElementById('cart-overlay');
    const drawer = document.getElementById('cart-drawer');
    
    if (overlay && drawer) {
      // Step 1: Slide out the drawer
      drawer.classList.remove('translate-x-0');
      drawer.classList.add('translate-x-full');
      drawer.classList.remove('open');
      
      // Step 2: Hide overlay after animation completes
      setTimeout(() => {
        overlay.classList.add('hidden');
        overlay.classList.remove('open');
      }, 300); // Match the transition duration
      
      this.isDrawerOpen = false;
      console.log('🛒 Cart drawer closed');
    }
  }

  async clearCart() {
    try {
      this.setLoading(true);
      
      const swell = window.swell;
      if (!swell || !this.cart || !this.cart.items) {
        return;
      }
      
      // Remove all items
      for (const item of this.cart.items) {
        await swell.cart.removeItem(item.id);
      }
      
      await this.refreshCart();
      console.log('🛒 Cart cleared');
      
    } catch (error) {
      console.error('🛒 Error clearing cart:', error);
      this.showError('Failed to clear cart');
      throw error;
    } finally {
      this.setLoading(false);
    }
  }

  handleClearCart() {
    if (confirm('Are you sure you want to clear your cart? This cannot be undone.')) {
      this.clearCart();
    }
  }

  handleViewCart() {
    this.closeDrawer();
    window.location.href = '/cart';
  }

  handleCheckout() {
    this.closeDrawer();
    window.location.href = '/checkout';
  }

  updateCartUI() {
    const itemCount = this.getItemCount();
    
    // Update cart count in header
    const cartCounts = document.querySelectorAll('#cart-count, .cart-count');
    cartCounts.forEach(el => {
      el.textContent = itemCount;
      if (itemCount > 0) {
        el.classList.remove('hidden');
      } else {
        el.classList.add('hidden');
      }
    });

    // Update cart drawer content if open
    if (this.isDrawerOpen) {
      this.updateDrawerContent();
    }
  }

  updateDrawerContent() {
    console.log('🛒 Updating drawer content with cart:', this.cart);
    
    const headerCount = document.getElementById('cart-header-count');
    const itemsList = document.getElementById('cart-items-list');
    const emptyEl = document.getElementById('cart-empty');
    const itemsEl = document.getElementById('cart-items');
    const subtotalEl = document.getElementById('cart-subtotal');
    const cartFooter = document.getElementById('cart-footer');
    
    const itemCount = this.getItemCount();
    const subtotal = this.getSubtotal();
    
    console.log('🛒 Drawer update - Items:', itemCount, 'Subtotal:', subtotal);
    
    // Update header count
    if (headerCount) {
      headerCount.textContent = `(${itemCount} item${itemCount !== 1 ? 's' : ''})`;
    }
    
    // 🔧 FIXED: Better empty/items state management
    if (!this.cart || !this.cart.items || itemCount === 0) {
      // Show empty state
      if (emptyEl) emptyEl.classList.remove('hidden');
      if (itemsEl) itemsEl.classList.add('hidden');
      if (cartFooter) cartFooter.classList.add('hidden');
      
      console.log('🛒 Drawer showing empty state');
      return;
    }
    
    // Show items state
    if (emptyEl) emptyEl.classList.add('hidden');
    if (itemsEl) itemsEl.classList.remove('hidden');
    if (cartFooter) cartFooter.classList.remove('hidden');
    
    // Update subtotal
    if (subtotalEl) {
      subtotalEl.textContent = this.formatPrice(subtotal);
    }
    
    // Update items list
    if (itemsList && this.cart.items) {
      itemsList.innerHTML = this.cart.items.map(item => this.createCartItemHTML(item)).join('');
      
      // Add event listeners for quantity controls
      this.addDrawerItemEventListeners();
    }
    
    console.log('🛒 Drawer content updated successfully');
  }

  // 🔧 NEW: Helper method to create cart item HTML for drawer
  createCartItemHTML(item) {
    // Handle different image URL structures
    let imageUrl = '/images/placeholder.png';
    
    if (item.product?.images && item.product.images.length > 0) {
      imageUrl = item.product.images[0].file?.url || item.product.images[0].url;
    } else if (item.images && item.images.length > 0) {
      imageUrl = item.images[0].file?.url || item.images[0].url;
    }
    
    const itemPrice = this.formatPrice((item.price || 0) * item.quantity);
    const productName = item.product?.name || item.name || 'Product';
    
    return `
      <div class="cart-item" data-item-id="${item.id}">
        <img 
          src="${imageUrl}" 
          alt="${productName}"
          class="cart-item-image"
          onerror="this.src='/images/placeholder.png'"
        />
        <div class="cart-item-details">
          <div class="cart-item-title">${productName}</div>
          <div class="cart-item-price">${itemPrice}</div>
          <div class="cart-item-controls">
            <div class="quantity-control">
              <button class="quantity-btn quantity-decrease" data-item-id="${item.id}">-</button>
              <input type="number" class="quantity-input" value="${item.quantity}" min="1" readonly>
              <button class="quantity-btn quantity-increase" data-item-id="${item.id}">+</button>
            </div>
            <button class="remove-btn" data-item-id="${item.id}">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M3 6h18M8 6V4a2 2 0 012-2h4a2 2 0 012 2v2M19 6l-1 14a2 2 0 01-2 2H8a2 2 0 01-2-2L5 6"></path>
              </svg>
            </button>
          </div>
        </div>
      </div>
    `;
  }

  // 🔧 NEW: Add event listeners for drawer item controls
  addDrawerItemEventListeners() {
    // Quantity decrease
    document.querySelectorAll('.quantity-decrease').forEach(btn => {
      btn.addEventListener('click', async (e) => {
        const itemId = e.target.dataset.itemId;
        const item = this.cart?.items?.find(i => i.id === itemId);
        if (item && item.quantity > 1) {
          await this.updateCartItem(itemId, item.quantity - 1);
        }
      });
    });
    
    // Quantity increase
    document.querySelectorAll('.quantity-increase').forEach(btn => {
      btn.addEventListener('click', async (e) => {
        const itemId = e.target.dataset.itemId;
        const item = this.cart?.items?.find(i => i.id === itemId);
        if (item) {
          await this.updateCartItem(itemId, item.quantity + 1);
        }
      });
    });
    
    // Remove item
    document.querySelectorAll('.remove-btn').forEach(btn => {
      btn.addEventListener('click', async (e) => {
        const itemId = e.target.dataset.itemId;
        if (confirm('Remove this item from your cart?')) {
          await this.removeCartItem(itemId);
        }
      });
    });
  }

  // 🔧 NEW: Helper method to format price
  formatPrice(amount) {
    return new Intl.NumberFormat('de-DE', {
      style: 'currency',
      currency: 'EUR'
    }).format(amount || 0);
  }

  createCartItemElement(item) {
    const itemEl = document.createElement('div');
    itemEl.className = 'cart-item';
    itemEl.innerHTML = `
      <img 
        src="${getProductImageUrl(item.product) || '/placeholder-image.jpg'}" 
        alt="${item.product?.name || 'Product'}"
        class="cart-item-image"
      />
      <div class="cart-item-details">
        <h4 class="cart-item-title">${item.product?.name || 'Unknown Product'}</h4>
        ${item.variant ? `<p class="cart-item-options">${item.variant.name}</p>` : ''}
        <p class="cart-item-price">${formatPrice(item.price_total)}</p>
        <div class="cart-item-controls">
          <div class="quantity-control">
            <button class="quantity-btn" data-action="decrease" data-item-id="${item.id}">-</button>
            <input type="number" class="quantity-input" value="${item.quantity}" min="1" data-item-id="${item.id}" readonly />
            <button class="quantity-btn" data-action="increase" data-item-id="${item.id}">+</button>
          </div>
          <button class="remove-btn" data-item-id="${item.id}" title="Remove item">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path>
            </svg>
          </button>
        </div>
      </div>
    `;
    
    // Add event listeners
    const decreaseBtn = itemEl.querySelector('[data-action="decrease"]');
    const increaseBtn = itemEl.querySelector('[data-action="increase"]');
    const removeBtn = itemEl.querySelector('.remove-btn');
    
    if (decreaseBtn) {
      decreaseBtn.addEventListener('click', () => {
        const newQuantity = Math.max(0, item.quantity - 1);
        if (newQuantity === 0) {
          this.removeCartItem(item.id);
        } else {
          this.updateCartItem(item.id, newQuantity);
        }
      });
    }
    
    if (increaseBtn) {
      increaseBtn.addEventListener('click', () => {
        this.updateCartItem(item.id, item.quantity + 1);
      });
    }
    
    if (removeBtn) {
      removeBtn.addEventListener('click', () => {
        this.removeCartItem(item.id);
      });
    }
    
    return itemEl;
  }

  setLoading(loading) {
    this.isLoading = loading;
    
    // Update loading state in UI
    const loadingEl = document.getElementById('cart-loading');
    if (loadingEl) {
      if (loading) {
        loadingEl.classList.remove('hidden');
      } else {
        loadingEl.classList.add('hidden');
      }
    }
    
    // Disable/enable buttons during loading
    const buttons = document.querySelectorAll('#add-to-cart-btn, .quantity-btn, .remove-btn');
    buttons.forEach(btn => {
      btn.disabled = loading;
    });
  }

  showSuccess(message) {
    this.showNotification(message, 'success');
  }

  showError(message) {
    this.showNotification(message, 'error');
  }

  showNotification(message, type = 'info') {
    const notification = document.createElement('div');
    notification.className = `fixed top-4 right-4 px-4 py-2 rounded-lg shadow-lg z-50 transform translate-x-full transition-transform duration-300 ${
      type === 'success' ? 'bg-green-500 text-white' : 
      type === 'error' ? 'bg-red-500 text-white' : 
      'bg-blue-500 text-white'
    }`;
    notification.textContent = message;
    
    document.body.appendChild(notification);
    
    // Animate in
    setTimeout(() => {
      notification.classList.remove('translate-x-full');
    }, 100);
    
    // Animate out and remove
    setTimeout(() => {
      notification.classList.add('translate-x-full');
      setTimeout(() => {
        if (document.body.contains(notification)) {
          document.body.removeChild(notification);
        }
      }, 300);
    }, type === 'error' ? 4000 : 2000);
  }

  getItemCount() {
    if (!this.cart || !this.cart.items) return 0;
    return this.cart.items.reduce((total, item) => total + (item.quantity || 0), 0);
  }

  getSubtotal() {
    return this.cart?.sub_total || 0;
  }

  // Debug method
  debug() {
    console.group('🛒 Cart Handler Debug');
    console.log('Cart:', this.cart);
    console.log('Item Count:', this.getItemCount());
    console.log('Subtotal:', formatPrice(this.getSubtotal()));
    console.log('Is Loading:', this.isLoading);
    console.log('Drawer Open:', this.isDrawerOpen);
    console.groupEnd();
  }
}

// Initialize cart handler and expose globally
const cartHandler = new CartHandler();

// Make available globally (this is what AuthHeader needs)
if (typeof window !== 'undefined') {
  window.cartManager = cartHandler;  // AuthHeader looks for this
  window.cartHandler = cartHandler;  // Also expose as cartHandler
  console.log('🛒 Cart handler exposed as window.cartManager and window.cartHandler');
}

export default cartHandler;