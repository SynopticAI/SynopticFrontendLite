// src/scripts/cart-handler.js - Cart UI management and interactions
import cartManager from '../lib/cart-manager.js';
import { formatPrice, getProductImageUrl } from '../lib/swell.js';

class CartHandler {
  constructor() {
    this.isDrawerOpen = false;
    this.cartSubscription = null;
    this.init();
  }

  init() {
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

    // View cart (future enhancement)
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
    // Update cart button in header with count
    const updateCartButton = (itemCount) => {
      const cartButton = document.getElementById('cart-button');
      const cartCount = document.getElementById('cart-count');
      
      if (cartCount) {
        if (itemCount > 0) {
          cartCount.textContent = itemCount;
          cartCount.classList.remove('hidden');
        } else {
          cartCount.classList.add('hidden');
        }
      }
    };

    // Initial update
    updateCartButton(cartManager.getItemCount());
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
    itemDiv.className = 'cart-item';
    itemDiv.dataset.itemId = item.id;

    // Product image
    const imageUrl = getProductImageUrl(item.product);
    
    // Product options display
    const optionsText = item.options ? 
      Object.entries(item.options)
        .map(([key, value]) => `${key}: ${value}`)
        .join(', ') : '';

    itemDiv.innerHTML = `
      <img 
        src="${imageUrl}" 
        alt="${item.product?.name || 'Product'}"
        class="cart-item-image"
        onerror="this.src='/placeholder-product.jpg'"
      />
      
      <div class="cart-item-details">
        <h4 class="cart-item-title">${item.product?.name || 'Product'}</h4>
        ${optionsText ? `<div class="cart-item-options">${optionsText}</div>` : ''}
        <div class="cart-item-price">${formatPrice(item.price, item.currency || 'EUR')}</div>
        
        <div class="cart-item-controls">
          <div class="quantity-control">
            <button class="quantity-btn decrease" data-action="decrease" data-item-id="${item.id}">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 12H4"></path>
              </svg>
            </button>
            <input 
              type="number" 
              class="quantity-input" 
              value="${item.quantity}" 
              min="1" 
              max="99"
              data-item-id="${item.id}"
            />
            <button class="quantity-btn increase" data-action="increase" data-item-id="${item.id}">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"></path>
              </svg>
            </button>
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
    this.setupCartItemEventListeners(itemDiv, item);

    return itemDiv;
  }

  setupCartItemEventListeners(itemElement, item) {
    // Quantity controls
    const decreaseBtn = itemElement.querySelector('.quantity-btn.decrease');
    const increaseBtn = itemElement.querySelector('.quantity-btn.increase');
    const quantityInput = itemElement.querySelector('.quantity-input');
    const removeBtn = itemElement.querySelector('.remove-btn');

    if (decreaseBtn) {
      decreaseBtn.addEventListener('click', () => {
        const newQuantity = Math.max(1, item.quantity - 1);
        if (newQuantity !== item.quantity) {
          cartManager.updateItemQuantity(item.id, newQuantity);
        }
      });
    }

    if (increaseBtn) {
      increaseBtn.addEventListener('click', () => {
        const newQuantity = Math.min(99, item.quantity + 1);
        if (newQuantity !== item.quantity) {
          cartManager.updateItemQuantity(item.id, newQuantity);
        }
      });
    }

    if (quantityInput) {
      quantityInput.addEventListener('change', (e) => {
        const newQuantity = parseInt(e.target.value) || 1;
        const clampedQuantity = Math.max(1, Math.min(99, newQuantity));
        
        if (clampedQuantity !== item.quantity) {
          cartManager.updateItemQuantity(item.id, clampedQuantity);
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
      removeBtn.addEventListener('click', () => {
        if (confirm('Remove this item from your cart?')) {
          cartManager.removeItem(item.id);
        }
      });
    }
  }

  async handleClearCart() {
    if (confirm('Are you sure you want to clear your cart? This cannot be undone.')) {
      await cartManager.clearCart();
    }
  }

  handleCheckout() {
    // For now, require authentication
    cartManager.requireAuth(() => {
      // Redirect to checkout page (to be implemented)
      window.location.href = '/checkout';
    });
  }

  // Public methods for product page integration
  async addProductToCart(productId, quantity = 1, options = {}, variantId = null) {
    return await cartManager.addItem(productId, quantity, options, variantId);
  }

  openCartAfterAdd() {
    // Open drawer after a short delay to show the add animation
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