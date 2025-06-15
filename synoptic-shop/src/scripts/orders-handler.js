// src/scripts/orders-handler.js - Orders page functionality
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

class OrdersHandler {
  constructor() {
    this.currentUser = null;
    this.orders = [];
    this.currentPage = 1;
    this.totalPages = 1;
    this.isLoading = false;
    this.currentFilter = '';
    this.currentSearch = '';
    
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
    // Check if we're on the orders page
    if (!window.location.pathname.includes('/orders')) {
      return;
    }

    this.setupEventListeners();
    this.checkAuthAndLoadOrders();
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
        if (window.authHandler) {
          window.authHandler.openModal('signin');
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

    // Listen for auth state changes
    if (window.authHandler) {
      window.authHandler.onAuthStateChange?.((user) => {
        this.currentUser = user;
        this.checkAuthAndLoadOrders();
      });
    }
  }

  setupModalEvents() {
    const modal = document.getElementById('order-modal');
    const closeBtn = document.getElementById('close-order-modal');
    const backdrop = document.getElementById('order-modal-backdrop');

    if (closeBtn) {
      closeBtn.addEventListener('click', () => this.closeModal());
    }

    if (backdrop) {
      backdrop.addEventListener('click', () => this.closeModal());
    }

    // ESC key to close modal
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' && modal && !modal.classList.contains('hidden')) {
        this.closeModal();
      }
    });
  }

  checkAuthAndLoadOrders() {
    if (window.authHandler) {
      this.currentUser = window.authHandler.getCurrentUser();
    }

    if (this.currentUser) {
      this.showSection('orders-loading');
      this.loadOrders();
    } else {
      this.showSection('auth-required');
    }
  }

  async loadOrders() {
    if (!this.currentUser) {
      this.showSection('auth-required');
      return;
    }

    this.isLoading = true;
    this.showSection('orders-loading');

    try {
      let result;
      
      if (this.currentSearch) {
        result = await searchOrders(this.currentSearch, {
          page: this.currentPage,
          limit: 10
        });
      } else {
        result = await getMyOrders({
          page: this.currentPage,
          limit: 10,
          status: this.currentFilter || null
        });
      }

      if (result.success) {
        this.orders = result.orders;
        this.currentPage = result.pagination.page;
        this.totalPages = result.pagination.pages;

        if (this.orders.length === 0) {
          this.showSection('orders-empty');
        } else {
          this.renderOrders();
          this.renderPagination();
          this.showSection('orders-list');
        }
      } else {
        this.showError(result.error);
      }
    } catch (error) {
      console.error('Error loading orders:', error);
      this.showError('Failed to load orders. Please try again.');
    } finally {
      this.isLoading = false;
    }
  }

  renderOrders() {
    const ordersList = document.getElementById('orders-list');
    if (!ordersList) return;

    ordersList.innerHTML = '';

    this.orders.forEach(order => {
      const orderCard = this.createOrderCard(order);
      ordersList.appendChild(orderCard);
    });
  }

  createOrderCard(order) {
    const statusInfo = getOrderStatusInfo(order.status);
    const orderDate = formatOrderDate(order.date_created);
    const orderTotal = getOrderTotal(order);
    const itemCount = getOrderItemCount(order);

    const cardDiv = document.createElement('div');
    cardDiv.className = 'order-card cursor-pointer';
    cardDiv.dataset.orderId = order.id;

    cardDiv.innerHTML = `
      <div class="flex flex-col lg:flex-row lg:items-center lg:justify-between">
        <div class="flex-1">
          <div class="flex flex-col sm:flex-row sm:items-start sm:justify-between mb-4">
            <div>
              <h3 class="text-lg font-semibold text-gray-900 mb-1">
                Order #${order.number || order.id.substring(0, 8)}
              </h3>
              <p class="text-sm text-gray-600">
                Placed on ${orderDate} • ${itemCount} item${itemCount !== 1 ? 's' : ''}
              </p>
            </div>
            
            <div class="mt-2 sm:mt-0">
              <span class="order-status-badge ${statusInfo.bgColor} ${statusInfo.textColor}">
                ${statusInfo.label}
              </span>
            </div>
          </div>

          <!-- Order Items Preview -->
          <div class="flex items-center space-x-4 mb-4">
            ${order.items.slice(0, 3).map(item => `
              <div class="flex items-center space-x-2">
                <img 
                  src="${getProductImageUrl(item.product)}" 
                  alt="${item.product?.name || 'Product'}"
                  class="w-12 h-12 rounded-lg object-cover bg-gray-100"
                  onerror="this.src='/placeholder-product.jpg'"
                />
                <div class="hidden sm:block">
                  <p class="text-sm font-medium text-gray-900">${item.product?.name || 'Product'}</p>
                  <p class="text-xs text-gray-500">Qty: ${item.quantity}</p>
                </div>
              </div>
            `).join('')}
            ${order.items.length > 3 ? `
              <div class="text-sm text-gray-500">
                +${order.items.length - 3} more
              </div>
            ` : ''}
          </div>
        </div>

        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between lg:flex-col lg:items-end lg:justify-start lg:ml-8">
          <div class="mb-4 lg:mb-2">
            <p class="text-2xl font-bold text-primary">${orderTotal}</p>
          </div>
          
          <div class="flex space-x-2">
            <button 
              class="view-order-btn px-4 py-2 text-sm text-primary border border-primary rounded-lg hover:bg-primary hover:text-white transition-colors"
              data-order-id="${order.id}"
            >
              View Details
            </button>
            
            ${order.tracking_code ? `
              <button class="px-4 py-2 text-sm text-gray-600 border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors">
                Track Order
              </button>
            ` : ''}
          </div>
        </div>
      </div>
    `;

    // Add click handler for the card
    cardDiv.addEventListener('click', (e) => {
      // Don't trigger if clicking on buttons
      if (!e.target.closest('button')) {
        this.showOrderDetails(order.id);
      }
    });

    // Add click handler for view details button
    const viewBtn = cardDiv.querySelector('.view-order-btn');
    if (viewBtn) {
      viewBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        this.showOrderDetails(order.id);
      });
    }

    return cardDiv;
  }

  async showOrderDetails(orderId) {
    try {
      const result = await getOrderById(orderId);
      
      if (result.success) {
        this.renderOrderDetailsModal(result.order);
        this.openModal();
      } else {
        console.error('Failed to load order details:', result.error);
      }
    } catch (error) {
      console.error('Error loading order details:', error);
    }
  }

  renderOrderDetailsModal(order) {
    const modalTitle = document.getElementById('modal-title');
    const modalContent = document.getElementById('modal-content');
    
    if (modalTitle) {
      modalTitle.textContent = `Order #${order.number || order.id.substring(0, 8)}`;
    }

    if (!modalContent) return;

    const statusInfo = getOrderStatusInfo(order.status);
    const orderDate = formatOrderDate(order.date_created);
    const orderTime = formatOrderTime(order.date_created);
    const orderTotal = getOrderTotal(order);
    const tracking = getOrderTracking(order);
    const downloads = getOrderDownloads(order);

    modalContent.innerHTML = `
      <div class="p-6 space-y-6">
        
        <!-- Order Summary -->
        <div class="flex flex-col md:flex-row md:items-center md:justify-between">
          <div>
            <h3 class="text-lg font-semibold text-gray-900 mb-2">Order Summary</h3>
            <p class="text-gray-600">Placed on ${orderDate} at ${orderTime}</p>
          </div>
          <div class="mt-4 md:mt-0">
            <span class="order-status-badge ${statusInfo.bgColor} ${statusInfo.textColor}">
              ${statusInfo.label}
            </span>
          </div>
        </div>

        <!-- Order Items -->
        <div>
          <h4 class="text-md font-semibold text-gray-900 mb-4">Items Ordered</h4>
          <div class="border border-gray-200 rounded-lg overflow-hidden">
            <table class="order-items-table">
              <thead>
                <tr>
                  <th>Product</th>
                  <th>Quantity</th>
                  <th>Price</th>
                  <th>Total</th>
                </tr>
              </thead>
              <tbody>
                ${order.items.map(item => `
                  <tr>
                    <td>
                      <div class="flex items-center space-x-3">
                        <img 
                          src="${getProductImageUrl(item.product)}" 
                          alt="${item.product?.name || 'Product'}"
                          class="w-12 h-12 rounded-lg object-cover bg-gray-100"
                          onerror="this.src='/placeholder-product.jpg'"
                        />
                        <div>
                          <p class="font-medium text-gray-900">${item.product?.name || 'Product'}</p>
                          ${item.product?.sku ? `<p class="text-sm text-gray-500">SKU: ${item.product.sku}</p>` : ''}
                          ${item.options ? `<p class="text-sm text-gray-500">${Object.entries(item.options).map(([key, value]) => `${key}: ${value}`).join(', ')}</p>` : ''}
                        </div>
                      </div>
                    </td>
                    <td class="text-gray-900">${item.quantity}</td>
                    <td class="text-gray-900">${formatPrice(item.price, order.currency)}</td>
                    <td class="font-semibold text-gray-900">${formatPrice(item.price * item.quantity, order.currency)}</td>
                  </tr>
                `).join('')}
              </tbody>
            </table>
          </div>
        </div>

        <!-- Order Totals -->
        <div class="border-t border-gray-200 pt-6">
          <div class="max-w-md ml-auto space-y-2">
            <div class="flex justify-between">
              <span class="text-gray-600">Subtotal:</span>
              <span class="text-gray-900">${formatPrice(order.sub_total, order.currency)}</span>
            </div>
            ${order.shipping_total ? `
              <div class="flex justify-between">
                <span class="text-gray-600">Shipping:</span>
                <span class="text-gray-900">${formatPrice(order.shipping_total, order.currency)}</span>
              </div>
            ` : ''}
            ${order.tax_total ? `
              <div class="flex justify-between">
                <span class="text-gray-600">Tax:</span>
                <span class="text-gray-900">${formatPrice(order.tax_total, order.currency)}</span>
              </div>
            ` : ''}
            <div class="flex justify-between text-lg font-semibold border-t border-gray-200 pt-2">
              <span>Total:</span>
              <span class="text-primary">${orderTotal}</span>
            </div>
          </div>
        </div>

        <!-- Shipping Information -->
        ${order.shipping ? `
          <div class="border-t border-gray-200 pt-6">
            <h4 class="text-md font-semibold text-gray-900 mb-3">Shipping Information</h4>
            <div class="bg-gray-50 p-4 rounded-lg">
              <p class="font-medium text-gray-900 mb-1">${order.shipping.name}</p>
              <p class="text-gray-600">${getFormattedShippingAddress(order)}</p>
            </div>
          </div>
        ` : ''}

        <!-- Tracking Information -->
        ${tracking.length > 0 ? `
          <div class="border-t border-gray-200 pt-6">
            <h4 class="text-md font-semibold text-gray-900 mb-3">Tracking Information</h4>
            <div class="space-y-3">
              ${tracking.map(track => `
                <div class="bg-blue-50 p-4 rounded-lg">
                  <div class="flex items-center justify-between mb-2">
                    <span class="font-medium text-gray-900">${track.carrier} ${track.service}</span>
                    <span class="text-sm text-gray-500">${formatOrderDate(track.date_created)}</span>
                  </div>
                  <p class="text-gray-700 mb-2">Tracking Code: <span class="font-mono">${track.tracking_code}</span></p>
                  ${track.tracking_url ? `
                    <a href="${track.tracking_url}" target="_blank" class="text-primary hover:underline text-sm">
                      Track Package →
                    </a>
                  ` : ''}
                </div>
              `).join('')}
            </div>
          </div>
        ` : ''}

        <!-- Downloads -->
        ${downloads.length > 0 ? `
          <div class="border-t border-gray-200 pt-6">
            <h4 class="text-md font-semibold text-gray-900 mb-3">Downloads</h4>
            <div class="flex flex-wrap gap-3">
              ${downloads.map(download => `
                <a 
                  href="${download.url}" 
                  target="_blank"
                  class="inline-flex items-center px-4 py-2 text-sm text-primary border border-primary rounded-lg hover:bg-primary hover:text-white transition-colors"
                >
                  <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-4-4m4 4l4-4m-6 6h8a2 2 0 002-2V7a2 2 0 00-2-2H8a2 2 0 00-2 2v8a2 2 0 002 2z"></path>
                  </svg>
                  ${download.label}
                </a>
              `).join('')}
            </div>
          </div>
        ` : ''}

        <!-- Order Actions -->
        <div class="border-t border-gray-200 pt-6">
          <div class="flex flex-wrap gap-3">
            ${canCancelOrder(order) ? `
              <button class="px-4 py-2 text-sm text-red-600 border border-red-300 rounded-lg hover:bg-red-50 transition-colors">
                Cancel Order
              </button>
            ` : ''}
            
            ${canReturnOrder(order) ? `
              <button class="px-4 py-2 text-sm text-yellow-600 border border-yellow-300 rounded-lg hover:bg-yellow-50 transition-colors">
                Return Items
              </button>
            ` : ''}
            
            <button class="px-4 py-2 text-sm text-gray-600 border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors">
              Contact Support
            </button>
          </div>
        </div>
      </div>
    `;
  }

  renderPagination() {
    const paginationEl = document.getElementById('orders-pagination');
    const prevBtn = document.getElementById('prev-page');
    const nextBtn = document.getElementById('next-page');
    const pageNumbers = document.getElementById('page-numbers');

    if (!paginationEl || this.totalPages <= 1) {
      if (paginationEl) paginationEl.classList.add('hidden');
      return;
    }

    paginationEl.classList.remove('hidden');

    // Update prev/next buttons
    if (prevBtn) {
      prevBtn.disabled = this.currentPage <= 1;
    }
    
    if (nextBtn) {
      nextBtn.disabled = this.currentPage >= this.totalPages;
    }

    // Update page numbers
    if (pageNumbers) {
      pageNumbers.innerHTML = '';
      
      for (let i = 1; i <= Math.min(this.totalPages, 5); i++) {
        const pageBtn = document.createElement('button');
        pageBtn.textContent = i;
        pageBtn.className = `px-3 py-2 text-sm rounded-lg transition-colors ${
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
}

// Initialize orders handler
const ordersHandler = new OrdersHandler();

// Make available globally for debugging
if (typeof window !== 'undefined') {
  window.ordersHandler = ordersHandler;
}

export default ordersHandler;