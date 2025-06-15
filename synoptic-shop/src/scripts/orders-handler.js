// src/scripts/orders-handler.js - Orders page functionality with centralized auth
import { 
  getMyOrders, 
  getOrderById, 
  searchOrders,
  getOrderStatusInfo,
  formatOrderDate,
  formatOrderTime,
  getOrderTotal,
  getOrderItemCount,
  getOrderTracking,
  canCancelOrder,
  canReturnOrder,
  getOrderDownloads,
  getFormattedShippingAddress,
  getFormattedBillingAddress
} from '../lib/swell-orders.js';

import { formatPrice, getProductImageUrl } from '../lib/swell.js';
import authStateManager from '../lib/auth-state-manager.js';

class OrdersHandler {
  constructor() {
    this.currentUser = null;
    this.orders = [];
    this.currentPage = 1;
    this.totalPages = 1;
    this.isLoading = false;
    this.currentFilter = '';
    this.currentSearch = '';
    this.authUnsubscribe = null;
    
    this.init();
  }

  init() {
    console.log('📦 Initializing orders handler...');
    
    // Wait for DOM to be ready
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', () => this.setupDOM());
    } else {
      this.setupDOM();
    }
  }

  async setupDOM() {
    // Check if we're on the orders page
    if (!window.location.pathname.includes('/orders')) {
      return;
    }

    console.log('📦 Setting up orders page...');
    this.setupEventListeners();
    
    // Subscribe to auth state changes
    this.authUnsubscribe = authStateManager.subscribe((user) => {
      console.log('📦 Orders page: Auth state changed:', user ? '✅ Authenticated' : '❌ Not authenticated');
      this.currentUser = user;
      this.handleAuthStateChange(user);
    });

    // Wait for auth to be ready and then load orders
    try {
      console.log('📦 Waiting for auth state...');
      const authState = await authStateManager.getAuthState();
      console.log('📦 Auth state ready:', authState);
      
      if (authState.isAuthenticated) {
        this.loadOrders();
      } else {
        this.showSection('auth-required');
      }
    } catch (error) {
      console.error('📦 Error getting auth state:', error);
      this.showError('Failed to check authentication status');
    }
  }

  handleAuthStateChange(user) {
    if (user) {
      // User is authenticated - load orders
      this.currentUser = user;
      this.loadOrders();
    } else {
      // User is not authenticated - show sign in required
      this.currentUser = null;
      this.showSection('auth-required');
    }
  }

  setupEventListeners() {
    // Search functionality
    const searchInput = document.getElementById('order-search');
    if (searchInput) {
      let searchTimeout;
      searchInput.addEventListener('input', (e) => {
        clearTimeout(searchTimeout);
        searchTimeout = setTimeout(() => {
          this.currentSearch = e.target.value;
          this.currentPage = 1;
          this.loadOrders();
        }, 500);
      });
    }

    // Status filter
    const statusFilter = document.getElementById('status-filter');
    if (statusFilter) {
      statusFilter.addEventListener('change', (e) => {
        this.currentFilter = e.target.value;
        this.currentPage = 1;
        this.loadOrders();
      });
    }

    // Sign in button
    const signInBtn = document.getElementById('sign-in-button');
    if (signInBtn) {
      signInBtn.addEventListener('click', () => {
        // Use global auth state to open modal
        if (window.authHandler) {
          window.authHandler.openModal('signin');
        } else if (window.authState) {
          // Fallback - dispatch event for auth modal
          window.dispatchEvent(new CustomEvent('openAuthModal', { detail: { mode: 'signin' } }));
        }
      });
    }

    // Retry button
    const retryBtn = document.getElementById('retry-button');
    if (retryBtn) {
      retryBtn.addEventListener('click', () => this.loadOrders());
    }

    // Pagination
    const prevBtn = document.getElementById('prev-page');
    const nextBtn = document.getElementById('next-page');
    
    if (prevBtn) {
      prevBtn.addEventListener('click', () => this.goToPage(this.currentPage - 1));
    }
    
    if (nextBtn) {
      nextBtn.addEventListener('click', () => this.goToPage(this.currentPage + 1));
    }

    // Modal events
    this.setupModalEvents();
  }

  async loadOrders() {
    // Check if user is authenticated using centralized auth
    if (!authStateManager.isAuthenticated()) {
      console.log('📦 No authenticated user, showing auth required');
      this.showSection('auth-required');
      return;
    }

    console.log('📦 Loading orders for authenticated user...');
    this.isLoading = true;
    this.showSection('orders-loading');

    try {
      const result = await getMyOrders({
        page: this.currentPage,
        limit: 10,
        filter: this.currentFilter,
        search: this.currentSearch
      });

      this.orders = result.orders || [];
      this.totalPages = result.totalPages || 1;
      
      console.log(`📦 Loaded ${this.orders.length} orders`);

      if (this.orders.length === 0) {
        this.showSection('orders-empty');
      } else {
        this.renderOrders();
        this.renderPagination();
        this.showSection('orders-list');
      }

    } catch (error) {
      console.error('📦 Error loading orders:', error);
      this.showError(`Failed to load orders: ${error.message}`);
    } finally {
      this.isLoading = false;
    }
  }

  renderOrders() {
    const ordersContainer = document.getElementById('orders-container');
    if (!ordersContainer) return;

    const ordersHtml = this.orders.map(order => {
      const statusInfo = getOrderStatusInfo(order);
      const orderDate = formatOrderDate(order.date_created);
      const orderTime = formatOrderTime(order.date_created);
      const total = getOrderTotal(order);
      const itemCount = getOrderItemCount(order);
      
      return `
        <div class="bg-white rounded-lg border border-gray-200 p-6 hover:shadow-md transition-shadow">
          <div class="flex justify-between items-start mb-4">
            <div>
              <h3 class="text-lg font-semibold text-gray-900">#${order.number}</h3>
              <p class="text-sm text-gray-500">${orderDate} at ${orderTime}</p>
            </div>
            <span class="px-3 py-1 rounded-full text-sm font-medium ${statusInfo.bgColor} ${statusInfo.textColor}">
              ${statusInfo.label}
            </span>
          </div>
          
          <div class="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-4">
            <div>
              <p class="text-sm text-gray-500">Items</p>
              <p class="font-medium">${itemCount} ${itemCount === 1 ? 'item' : 'items'}</p>
            </div>
            <div>
              <p class="text-sm text-gray-500">Total</p>
              <p class="font-medium">${formatPrice(total)}</p>
            </div>
            <div>
              <p class="text-sm text-gray-500">Status</p>
              <p class="font-medium">${statusInfo.label}</p>
            </div>
          </div>
          
          <div class="flex flex-wrap gap-2">
            <button 
              onclick="ordersHandler.viewOrder('${order.id}')"
              class="btn-secondary text-sm"
            >
              View Details
            </button>
            ${canCancelOrder(order) ? `
              <button 
                onclick="ordersHandler.cancelOrder('${order.id}')"
                class="btn-outline-red text-sm"
              >
                Cancel Order
              </button>
            ` : ''}
            ${order.tracking ? `
              <a 
                href="${getOrderTracking(order).url}" 
                target="_blank"
                class="btn-outline text-sm"
              >
                Track Package
              </a>
            ` : ''}
          </div>
        </div>
      `;
    }).join('');

    ordersContainer.innerHTML = ordersHtml;
  }

  renderPagination() {
    const paginationEl = document.getElementById('orders-pagination');
    if (!paginationEl || this.totalPages <= 1) {
      if (paginationEl) paginationEl.classList.add('hidden');
      return;
    }

    paginationEl.classList.remove('hidden');

    // Update pagination controls
    const prevBtn = document.getElementById('prev-page');
    const nextBtn = document.getElementById('next-page');
    const pageInfo = document.getElementById('page-info');

    if (prevBtn) {
      prevBtn.disabled = this.currentPage <= 1;
      prevBtn.className = this.currentPage <= 1 
        ? 'btn-disabled' 
        : 'btn-secondary';
    }

    if (nextBtn) {
      nextBtn.disabled = this.currentPage >= this.totalPages;
      nextBtn.className = this.currentPage >= this.totalPages 
        ? 'btn-disabled' 
        : 'btn-secondary';
    }

    if (pageInfo) {
      pageInfo.textContent = `Page ${this.currentPage} of ${this.totalPages}`;
    }

    // Update page numbers if container exists
    const pageNumbers = document.getElementById('page-numbers');
    if (pageNumbers) {
      pageNumbers.innerHTML = '';
      
      const startPage = Math.max(1, this.currentPage - 2);
      const endPage = Math.min(this.totalPages, this.currentPage + 2);
      
      for (let i = startPage; i <= endPage; i++) {
        const pageBtn = document.createElement('button');
        pageBtn.textContent = i;
        pageBtn.className = `px-3 py-1 mx-1 rounded ${
          i === this.currentPage 
            ? 'bg-primary text-white' 
            : 'text-gray-700 bg-white border border-gray-300 hover:bg-gray-50'
        }`;
        
        pageBtn.addEventListener('click', () => this.goToPage(i));
        pageNumbers.appendChild(pageBtn);
      }
    }
  }

  goToPage(page) {
    if (page < 1 || page > this.totalPages || page === this.currentPage) {
      return;
    }
    
    this.currentPage = page;
    this.loadOrders();
  }

  async viewOrder(orderId) {
    try {
      const order = await getOrderById(orderId);
      this.showOrderModal(order);
    } catch (error) {
      console.error('Error loading order details:', error);
      this.showError('Failed to load order details');
    }
  }

  showOrderModal(order) {
    // Implementation for order details modal
    this.openModal();
    // Add order details rendering here
  }

  setupModalEvents() {
    const modal = document.getElementById('order-modal');
    if (modal) {
      const closeBtn = modal.querySelector('.close-modal');
      if (closeBtn) {
        closeBtn.addEventListener('click', () => this.closeModal());
      }

      modal.addEventListener('click', (e) => {
        if (e.target === modal) {
          this.closeModal();
        }
      });
    }
  }

  openModal() {
    const modal = document.getElementById('order-modal');
    if (modal) {
      modal.classList.remove('hidden');
      modal.classList.add('show');
      document.body.style.overflow = 'hidden';
    }
  }

  closeModal() {
    const modal = document.getElementById('order-modal');
    if (modal) {
      modal.classList.remove('show');
      modal.classList.add('hidden');
      document.body.style.overflow = '';
    }
  }

  showSection(sectionId) {
    const sections = [
      'auth-required',
      'orders-loading', 
      'orders-error',
      'orders-empty',
      'orders-list'
    ];

    sections.forEach(id => {
      const el = document.getElementById(id);
      if (el) {
        if (id === sectionId) {
          el.classList.remove('hidden');
        } else {
          el.classList.add('hidden');
        }
      }
    });

    // Hide pagination when not showing orders list
    const paginationEl = document.getElementById('orders-pagination');
    if (paginationEl && sectionId !== 'orders-list') {
      paginationEl.classList.add('hidden');
    }
  }

  showError(message) {
    const errorSection = document.getElementById('orders-error');
    const errorMessage = document.getElementById('error-message');
    
    if (errorMessage) {
      errorMessage.textContent = message;
    }
    
    this.showSection('orders-error');
  }

  // Cleanup method
  destroy() {
    if (this.authUnsubscribe) {
      this.authUnsubscribe();
    }
  }
}

// Initialize orders handler
const ordersHandler = new OrdersHandler();

// Make available globally for debugging
if (typeof window !== 'undefined') {
  window.ordersHandler = ordersHandler;
}

export default ordersHandler;