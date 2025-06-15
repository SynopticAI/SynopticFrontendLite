// src/scripts/cart-handler.js - Cart UI management with updated cart manager integration
import cartManager from '../lib/cart-manager.js';
import { formatPrice, getProductImageUrl } from '../lib/swell.js';

class CartHandler {
  constructor() {
    this.isDrawerOpen = false;
    this.cartSubscription = null;
    this.init();
  }

  init() {
    console.log('🛒 Initializing cart handler...');
    
    // Wait for DOM to be ready
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', () => this.setupDOM());
    } else {
      this.setupDOM();
    }
  }

  setupDOM() {
    this.setupDrawerEventListeners();
    this.setupCartSubscription();
    this.setupHeaderIntegration();
    this.setupProductPageIntegration();
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

    // View cart
    const viewCartBtn = document.getElementById('view-cart-button');
    if (viewCartBtn) {
      viewCartBtn.addEventListener('click', () => {
        this.closeDrawer();
        window.location.href = '/cart';
      });
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

  setupCartSubscription() {
    // Subscribe to cart state changes
    this.cartSubscription = cartManager.subscribe((state) => {
      this.updateCartUI(state);
    });
  }

  setupHeaderIntegration() {
    // Cart header integration is handled in updateCartUI
    console.log('🛒 Cart header integration ready');
  }

  setupProductPageIntegration() {
    // Setup add to cart buttons on product pages
    const addToCartBtns = document.querySelectorAll('[data-product-id]');
    
    addToCartBtns.forEach(btn => {
      if (btn.dataset.cartHandlerAttached) return; // Avoid duplicate listeners
      
      btn.addEventListener('click', async (e) => {
        e.preventDefault();
        
        const productId = btn.dataset.productId;
        const variantId = btn.dataset.variantId || null;
        const quantity = parseInt(btn.dataset.quantity) || 1;
        
        // Get options from form if exists
        const options = this.getProductOptions(productId);
        
        await this.addProductToCart(productId, quantity, options, variantId);
      });
      
      btn.dataset.cartHandlerAttached = 'true';
    });
  }

  getProductOptions(productId) {
    const form = document.getElementById(`product-form-${productId}`);
    if (!form) return {};
    
    const options = {};
    const selects = form.querySelectorAll('select[data-option]');
    
    selects.forEach(select => {
      if (select.value && select.dataset.option) {
        options[select.dataset.option] = select.value;
      }
    });
    
    return options;
  }

  openDrawer() {
    const overlay = document.getElementById('cart-overlay');
    const drawer = document.getElementById('cart-drawer');
    
    if (overlay && drawer) {
      this.isDrawerOpen = true;
      overlay.classList.remove('hidden');
      overlay.classList.add('open');
      
      // Small delay for smooth animation
      setTimeout(() => {
        drawer.classList.add('open');
      }, 10);
      
      // Prevent body scroll
      document.body.style.overflow = 'hidden';
      
      console.log('🛒 Cart drawer opened');
    }
  }

  closeDrawer() {
    const overlay = document.getElementById('cart-overlay');
    const drawer = document.getElementById('cart-drawer');
    
    if (overlay && drawer) {
      this.isDrawerOpen = false;
      drawer.classList.remove('open');
      
      setTimeout(() => {
        overlay.classList.remove('open');
        overlay.classList.add('hidden');
      }, 300);
      
      // Restore body scroll
      document.body.style.overflow = '';
      
      console.log('🛒 Cart drawer closed');
    }
  }

  updateCartUI(state) {
    this.updateCartCount(state.itemCount);
    this.updateCartHeader(state.itemCount);
    this.updateCartContent(state);
    this.updateCartFooter(state);
  }

  updateCartCount(itemCount) {
    const cartCount = document.getElementById('cart-count');
    
    if (cartCount) {
      if (itemCount > 0) {
        cartCount.textContent = itemCount;
        cartCount.classList.remove('hidden');
      } else {
        cartCount.classList.add('hidden');
      }
    }
  }

  updateCartHeader(itemCount) {
    const headerCount = document.getElementById('cart-header-count');
    
    if (headerCount) {
      headerCount.textContent = `(${itemCount} item${itemCount !== 1 ? 's' : ''})`;
    }
  }

  updateCartContent(state) {
    const { cart, isLoading, itemCount } = state;
    
    // Show/hide loading
    const loadingEl = document.getElementById('cart-loading');
    if (loadingEl) {
      if (isLoading) {
        loadingEl.classList.remove('hidden');
      } else {
        loadingEl.classList.add('hidden');
      }
    }

    // Show/hide empty state
    const emptyEl = document.getElementById('cart-empty');
    const itemsEl = document.getElementById('cart-items');
    
    if (itemCount === 0 && !isLoading) {
      if (emptyEl) emptyEl.classList.remove('hidden');
      if (itemsEl) itemsEl.classList.add('hidden');
    } else {
      if (emptyEl) emptyEl.classList.add('hidden');
      if (itemsEl) itemsEl.classList.remove('hidden');
    }

    // Update cart items
    if (cart && cart.items) {
      this.renderCartItems(cart.items);
    }
  }

  updateCartFooter(state) {
    const { itemCount, formattedSubtotal } = state;
    
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
      subtotalEl.textContent = formattedSubtotal;
    }
  }

  renderCartItems(items) {
    const itemsList = document.getElementById('cart-items-list');
    
    if (!itemsList) return;

    itemsList.innerHTML = '';

    items.forEach(item => {
      const itemEl = this.createCartItemElement(item);
      itemsList.appendChild(itemEl);
    });
  }

  createCartItemElement(item) {
    const itemDiv = document.createElement('div');
    itemDiv.className = 'cart-item border-b border-gray-200 py-4';
    itemDiv.dataset.itemId = item.id;

    // Product image
    const imageUrl = getProductImageUrl(item.product);
    
    // Product options display
    const optionsText = item.options ? 
      Object.entries(item.options)
        .map(([key, value]) => `${key}: ${value}`)
        .join(', ') : '';

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
          
          ${optionsText ? `
            <p class="text-xs text-gray-500 mt-1">${optionsText}</p>
          ` : ''}
          
          <div class="flex items-center justify-between mt-2">
            <div class="flex items-center space-x-2">
              <button 
                class="quantity-decrease w-8 h-8 flex items-center justify-center border border-gray-300 rounded text-gray-500 hover:text-gray-700"
                data-item-id="${item.id}"
              >
                -
              </button>
              
              <input 
                type="number" 
                value="${item.quantity}" 
                min="1" 
                max="99"
                class="quantity-input w-12 text-center border border-gray-300 rounded text-sm"
                data-item-id="${item.id}"
              />
              
              <button 
                class="quantity-increase w-8 h-8 flex items-center justify-center border border-gray-300 rounded text-gray-500 hover:text-gray-700"
                data-item-id="${item.id}"
              >
                +
              </button>
            </div>
            
            <div class="text-right">
              <p class="text-sm font-medium text-gray-900">
                ${formatPrice(item.price_total, item.currency || 'EUR')}
              </p>
              <button 
                class="remove-item text-xs text-red-600 hover:text-red-800 mt-1"
                data-item-id="${item.id}"
              >
                Remove
              </button>
            </div>
          </div>
        </div>
      </div>
    `;

    // Add event listeners
    this.attachItemEventListeners(itemDiv, item);

    return itemDiv;
  }

  attachItemEventListeners(itemEl, item) {
    const decreaseBtn = itemEl.querySelector('.quantity-decrease');
    const increaseBtn = itemEl.querySelector('.quantity-increase');
    const quantityInput = itemEl.querySelector('.quantity-input');
    const removeBtn = itemEl.querySelector('.remove-item');

    if (decreaseBtn) {
      decreaseBtn.addEventListener('click', async () => {
        const newQuantity = Math.max(1, item.quantity - 1);
        if (newQuantity !== item.quantity) {
          await cartManager.updateItemQuantity(item.id, newQuantity);
        }
      });
    }

    if (increaseBtn) {
      increaseBtn.addEventListener('click', async () => {
        const newQuantity = Math.min(99, item.quantity + 1);
        if (newQuantity !== item.quantity) {
          await cartManager.updateItemQuantity(item.id, newQuantity);
        }
      });
    }

    if (quantityInput) {
      quantityInput.addEventListener('change', async (e) => {
        const newQuantity = parseInt(e.target.value) || 1;
        const clampedQuantity = Math.max(1, Math.min(99, newQuantity));
        
        if (clampedQuantity !== item.quantity) {
          await cartManager.updateItemQuantity(item.id, clampedQuantity);
        }
        
        // Reset input to valid value
        e.target.value = clampedQuantity;
      });

      quantityInput.addEventListener('blur', (e) => {
        // Ensure valid value on blur
        const value = parseInt(e.target.value) || 1;
        e.target.value = Math.max(1, Math.min(99, value));
      });
    }

    if (removeBtn) {
      removeBtn.addEventListener('click', async () => {
        if (confirm('Remove this item from your cart?')) {
          await cartManager.removeItemFromCart(item.id);
        }
      });
    }
  }

  async handleClearCart() {
    if (confirm('Are you sure you want to clear your cart? This cannot be undone.')) {
      await cartManager.clearCartItems();
    }
  }

  handleCheckout() {
    // Close drawer and redirect to checkout
    this.closeDrawer();
    window.location.href = '/checkout';
  }

  // Public methods for product page integration
  async addProductToCart(productId, quantity = 1, options = {}, variantId = null) {
    console.log('🛒 Adding product to cart:', { productId, quantity, options, variantId });
    
    try {
      const result = await cartManager.addItemToCart(productId, quantity, options, variantId);
      
      if (result.success) {
        console.log('✅ Product added to cart successfully');
        
        // Show success feedback
        this.showAddToCartSuccess();
        
        // Open cart drawer after a short delay
        setTimeout(() => {
          this.openDrawer();
        }, 500);
        
        return result;
      } else {
        console.error('❌ Failed to add product to cart:', result.error);
        this.showAddToCartError(result.error);
        return result;
      }
    } catch (error) {
      console.error('🛒 Error adding product to cart:', error);
      this.showAddToCartError('Failed to add item to cart');
      return {
        success: false,
        error: error.message
      };
    }
  }

  showAddToCartSuccess() {
    // Create temporary success notification
    const notification = document.createElement('div');
    notification.className = 'fixed top-4 right-4 bg-green-500 text-white px-4 py-2 rounded-lg shadow-lg z-50 transform translate-x-full transition-transform duration-300';
    notification.textContent = 'Item added to cart!';
    
    document.body.appendChild(notification);
    
    // Animate in
    setTimeout(() => {
      notification.classList.remove('translate-x-full');
    }, 100);
    
    // Animate out and remove
    setTimeout(() => {
      notification.classList.add('translate-x-full');
      setTimeout(() => {
        document.body.removeChild(notification);
      }, 300);
    }, 2000);
  }

  showAddToCartError(message) {
    // Create temporary error notification
    const notification = document.createElement('div');
    notification.className = 'fixed top-4 right-4 bg-red-500 text-white px-4 py-2 rounded-lg shadow-lg z-50 transform translate-x-full transition-transform duration-300';
    notification.textContent = message || 'Failed to add item to cart';
    
    document.body.appendChild(notification);
    
    // Animate in
    setTimeout(() => {
      notification.classList.remove('translate-x-full');
    }, 100);
    
    // Animate out and remove
    setTimeout(() => {
      notification.classList.add('translate-x-full');
      setTimeout(() => {
        document.body.removeChild(notification);
      }, 300);
    }, 3000);
  }

  // Method to be called from product pages
  openCartAfterAdd() {
    setTimeout(() => {
      this.openDrawer();
    }, 500);
  }
}

// Initialize cart handler
const cartHandler = new CartHandler();

// Make available globally
if (typeof window !== 'undefined') {
  window.cartHandler = cartHandler;
}

export default cartHandler;