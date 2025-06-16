// src/scripts/cart-handler.js - Simple and robust cart handler
import { formatPrice, getProductImageUrl } from '../lib/swell.js';
import swell from 'swell-js';

class CartHandler {
  constructor() {
    this.isDrawerOpen = false;
    this.cart = null;
    this.isLoading = false;
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
      cartButton.addEventListener('click', () => this.openDrawer());
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

  async addProductToCart(productId, quantity = 1) {
    try {
      this.setLoading(true);
      
      console.log('🛒 Adding to cart:', { productId, quantity });

      // Simple Swell add to cart - no complex auth checking
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
      
      this.showError(error.message || 'Failed to add item to cart');
      return { success: false, error: error.message };
      
    } finally {
      this.setLoading(false);
    }
  }

  async refreshCart() {
    try {
      console.log('🛒 Refreshing cart...');
      this.cart = await swell.cart.get();
      this.updateCartUI();
    } catch (error) {
      console.error('🛒 Error refreshing cart:', error);
      this.cart = null;
      this.updateCartUI();
    }
  }

  async removeItem(itemId) {
    try {
      this.setLoading(true);
      console.log('🛒 Removing item:', itemId);
      
      const result = await swell.cart.removeItem(itemId);
      
      if (result) {
        this.cart = result;
        this.updateCartUI();
        this.showSuccess('Item removed from cart');
      }
      
    } catch (error) {
      console.error('🛒 Error removing item:', error);
      this.showError('Failed to remove item');
    } finally {
      this.setLoading(false);
    }
  }

  async updateQuantity(itemId, quantity) {
    try {
      this.setLoading(true);
      console.log('🛒 Updating quantity:', { itemId, quantity });
      
      const result = await swell.cart.updateItem(itemId, { quantity });
      
      if (result) {
        this.cart = result;
        this.updateCartUI();
      }
      
    } catch (error) {
      console.error('🛒 Error updating quantity:', error);
      this.showError('Failed to update quantity');
    } finally {
      this.setLoading(false);
    }
  }

  async clearCart() {
    try {
      this.setLoading(true);
      console.log('🛒 Clearing cart...');
      
      if (this.cart && this.cart.items) {
        // Remove all items
        for (const item of this.cart.items) {
          await swell.cart.removeItem(item.id);
        }
      }
      
      await this.refreshCart();
      this.showSuccess('Cart cleared');
      
    } catch (error) {
      console.error('🛒 Error clearing cart:', error);
      this.showError('Failed to clear cart');
    } finally {
      this.setLoading(false);
    }
  }

  updateCartUI() {
    const itemCount = this.getItemCount();
    const subtotal = this.getSubtotal();
    
    // Update cart count in header
    const cartCounts = document.querySelectorAll('.cart-count');
    cartCounts.forEach(el => {
      el.textContent = itemCount;
      if (itemCount > 0) {
        el.classList.remove('hidden');
      } else {
        el.classList.add('hidden');
      }
    });

    // Update cart drawer content
    this.updateCartContent();
    this.updateCartFooter();
  }

  updateCartContent() {
    const itemsList = document.getElementById('cart-items-list');
    const emptyEl = document.getElementById('cart-empty');
    const itemsEl = document.getElementById('cart-items');
    
    const itemCount = this.getItemCount();
    
    if (itemCount === 0) {
      if (emptyEl) emptyEl.classList.remove('hidden');
      if (itemsEl) itemsEl.classList.add('hidden');
    } else {
      if (emptyEl) emptyEl.classList.add('hidden');
      if (itemsEl) itemsEl.classList.remove('hidden');
    }

    if (itemsList && this.cart && this.cart.items) {
      itemsList.innerHTML = '';
      
      this.cart.items.forEach(item => {
        const itemEl = this.createCartItemElement(item);
        itemsList.appendChild(itemEl);
      });
    }
  }

  updateCartFooter() {
    const itemCount = this.getItemCount();
    const subtotal = this.getSubtotal();
    
    const footerEl = document.getElementById('cart-footer');
    const subtotalEl = document.getElementById('cart-subtotal');
    
    if (footerEl) {
      if (itemCount > 0) {
        footerEl.classList.remove('hidden');
      } else {
        footerEl.classList.add('hidden');
      }
    }

    if (subtotalEl) {
      subtotalEl.textContent = formatPrice(subtotal);
    }
  }

  createCartItemElement(item) {
    const itemDiv = document.createElement('div');
    itemDiv.className = 'cart-item border-b border-gray-200 py-4';
    itemDiv.dataset.itemId = item.id;

    const imageUrl = getProductImageUrl(item.product) || '/placeholder-product.jpg';
    const itemPrice = item.price || item.product?.price || 0;
    
    itemDiv.innerHTML = `
      <div class="flex items-start space-x-4">
        <img 
          src="${imageUrl}" 
          alt="${item.product?.name || 'Product'}"
          class="w-16 h-16 object-cover rounded-lg"
          onerror="this.src='/placeholder-product.jpg'"
        />
        
        <div class="flex-1 min-w-0">
          <h4 class="text-sm font-medium text-gray-900 truncate">
            ${item.product?.name || 'Product'}
          </h4>
          
          <p class="text-sm text-primary font-semibold mt-1">
            ${formatPrice(itemPrice)}
          </p>
          
          <div class="flex items-center mt-2 space-x-2">
            <button 
              type="button"
              class="quantity-btn"
              onclick="window.cartHandler.updateQuantity('${item.id}', ${Math.max(1, item.quantity - 1)})"
              ${item.quantity <= 1 ? 'disabled' : ''}
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 12H4"></path>
              </svg>
            </button>
            
            <span class="quantity-display px-3 py-1 text-sm bg-gray-100 rounded">
              ${item.quantity}
            </span>
            
            <button 
              type="button"
              class="quantity-btn"
              onclick="window.cartHandler.updateQuantity('${item.id}', ${item.quantity + 1})"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"></path>
              </svg>
            </button>
            
            <button 
              type="button"
              class="remove-btn ml-4"
              onclick="window.cartHandler.removeItem('${item.id}')"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path>
              </svg>
            </button>
          </div>
        </div>
      </div>
    `;

    return itemDiv;
  }

  openDrawer() {
    const drawer = document.getElementById('cart-drawer');
    const backdrop = document.getElementById('cart-backdrop');
    
    if (drawer && backdrop) {
      drawer.classList.remove('hidden');
      backdrop.classList.remove('hidden');
      this.isDrawerOpen = true;
      
      // Prevent body scroll
      document.body.style.overflow = 'hidden';
      
      console.log('🛒 Cart drawer opened');
    }
  }

  closeDrawer() {
    const drawer = document.getElementById('cart-drawer');
    const backdrop = document.getElementById('cart-backdrop');
    
    if (drawer && backdrop) {
      drawer.classList.add('hidden');
      backdrop.classList.add('hidden');
      this.isDrawerOpen = false;
      
      // Restore body scroll
      document.body.style.overflow = '';
      
      console.log('🛒 Cart drawer closed');
    }
  }

  handleClearCart() {
    if (confirm('Are you sure you want to clear your cart? This cannot be undone.')) {
      this.clearCart();
    }
  }

  handleCheckout() {
    this.closeDrawer();
    window.location.href = '/checkout';
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
    console.group('🛒 Simple Cart Handler Debug');
    console.log('Cart:', this.cart);
    console.log('Item Count:', this.getItemCount());
    console.log('Subtotal:', formatPrice(this.getSubtotal()));
    console.log('Is Loading:', this.isLoading);
    console.log('Drawer Open:', this.isDrawerOpen);
    console.groupEnd();
  }
}

// Initialize cart handler
const cartHandler = new CartHandler();

// Make available globally
if (typeof window !== 'undefined') {
  window.cartHandler = cartHandler;
}

export default cartHandler;