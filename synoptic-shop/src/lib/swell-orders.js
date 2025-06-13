// src/lib/swell-orders.js - Order management functions for Swell
import { swell, formatPrice } from './swell.js';

// =============================================================================
// ORDER MANAGEMENT FUNCTIONS
// =============================================================================

/**
 * Get orders for current account/customer
 * @param {Object} options - Query options
 * @returns {Promise<Object>} Orders result
 */
export async function getMyOrders(options = {}) {
  try {
    const {
      page = 1,
      limit = 20,
      sort = 'date_created',
      order = 'desc',
      status = null
    } = options;

    const queryOptions = {
      page,
      limit,
      sort: `${sort} ${order}`,
      expand: ['items.product', 'items.variant']
    };

    // Filter by status if provided
    if (status) {
      queryOptions.where = { status };
    }

    const orders = await swell.account.listOrders(queryOptions);
    
    return {
      success: true,
      orders: orders.results || [],
      pagination: {
        page: orders.page || 1,
        pages: orders.pages || 1,
        count: orders.count || 0
      },
      error: null
    };
  } catch (error) {
    console.error('Error fetching orders:', error);
    return {
      success: false,
      orders: [],
      pagination: null,
      error: error.message || 'Failed to fetch orders'
    };
  }
}

/**
 * Get a specific order by ID
 * @param {string} orderId - Order ID
 * @returns {Promise<Object>} Order result
 */
export async function getOrderById(orderId) {
  try {
    const order = await swell.account.getOrder(orderId, {
      expand: ['items.product', 'items.variant', 'shipments', 'billing', 'shipping']
    });
    
    return {
      success: true,
      order: order,
      error: null
    };
  } catch (error) {
    console.error('Error fetching order:', error);
    return {
      success: false,
      order: null,
      error: error.message || 'Failed to fetch order'
    };
  }
}

/**
 * Get order status display information
 * @param {string} status - Order status
 * @returns {Object} Status display info
 */
export function getOrderStatusInfo(status) {
  const statusMap = {
    'pending': {
      label: 'Pending',
      color: 'yellow',
      bgColor: 'bg-yellow-100',
      textColor: 'text-yellow-800',
      description: 'Order is being processed'
    },
    'draft': {
      label: 'Draft',
      color: 'gray',
      bgColor: 'bg-gray-100',
      textColor: 'text-gray-800',
      description: 'Order is in draft state'
    },
    'payment_pending': {
      label: 'Payment Pending',
      color: 'orange',
      bgColor: 'bg-orange-100',
      textColor: 'text-orange-800',
      description: 'Waiting for payment'
    },
    'delivery_pending': {
      label: 'Processing',
      color: 'blue',
      bgColor: 'bg-blue-100',
      textColor: 'text-blue-800',
      description: 'Order is being prepared for shipment'
    },
    'shipped': {
      label: 'Shipped',
      color: 'indigo',
      bgColor: 'bg-indigo-100',
      textColor: 'text-indigo-800',
      description: 'Order has been shipped'
    },
    'delivered': {
      label: 'Delivered',
      color: 'green',
      bgColor: 'bg-green-100',
      textColor: 'text-green-800',
      description: 'Order has been delivered'
    },
    'canceled': {
      label: 'Canceled',
      color: 'red',
      bgColor: 'bg-red-100',
      textColor: 'text-red-800',
      description: 'Order has been canceled'
    },
    'returned': {
      label: 'Returned',
      color: 'purple',
      bgColor: 'bg-purple-100',
      textColor: 'text-purple-800',
      description: 'Order has been returned'
    }
  };

  return statusMap[status] || {
    label: status || 'Unknown',
    color: 'gray',
    bgColor: 'bg-gray-100',
    textColor: 'text-gray-800',
    description: 'Status unknown'
  };
}

/**
 * Format order date for display
 * @param {string|Date} date - Date string or Date object
 * @returns {string} Formatted date
 */
export function formatOrderDate(date) {
  if (!date) return 'N/A';
  
  const orderDate = new Date(date);
  
  return orderDate.toLocaleDateString('de-DE', {
    year: 'numeric',
    month: 'long',
    day: 'numeric'
  });
}

/**
 * Format order time for display
 * @param {string|Date} date - Date string or Date object
 * @returns {string} Formatted time
 */
export function formatOrderTime(date) {
  if (!date) return 'N/A';
  
  const orderDate = new Date(date);
  
  return orderDate.toLocaleTimeString('de-DE', {
    hour: '2-digit',
    minute: '2-digit'
  });
}

/**
 * Get order total with currency
 * @param {Object} order - Order object
 * @returns {string} Formatted total
 */
export function getOrderTotal(order) {
  if (!order) return 'N/A';
  
  return formatPrice(order.grand_total || order.total || 0, order.currency || 'EUR');
}

/**
 * Get order item count
 * @param {Object} order - Order object
 * @returns {number} Total item count
 */
export function getOrderItemCount(order) {
  if (!order || !order.items) return 0;
  
  return order.items.reduce((total, item) => total + (item.quantity || 0), 0);
}

/**
 * Get tracking information for an order
 * @param {Object} order - Order object
 * @returns {Array} Tracking information
 */
export function getOrderTracking(order) {
  if (!order || !order.shipments) return [];
  
  return order.shipments.map(shipment => ({
    id: shipment.id,
    carrier: shipment.carrier,
    service: shipment.service,
    tracking_code: shipment.tracking_code,
    tracking_url: shipment.tracking_url,
    date_created: shipment.date_created
  }));
}

/**
 * Check if order can be canceled
 * @param {Object} order - Order object
 * @returns {boolean} True if order can be canceled
 */
export function canCancelOrder(order) {
  if (!order) return false;
  
  const cancelableStatuses = ['pending', 'payment_pending', 'delivery_pending'];
  return cancelableStatuses.includes(order.status);
}

/**
 * Check if order can be returned
 * @param {Object} order - Order object
 * @returns {boolean} True if order can be returned
 */
export function canReturnOrder(order) {
  if (!order) return false;
  
  const returnableStatuses = ['delivered'];
  if (!returnableStatuses.includes(order.status)) return false;
  
  // Check if order is within return window (30 days)
  const orderDate = new Date(order.date_created);
  const now = new Date();
  const daysDiff = Math.floor((now - orderDate) / (1000 * 60 * 60 * 24));
  
  return daysDiff <= 30;
}

/**
 * Get downloadable files for an order (invoices, receipts)
 * @param {Object} order - Order object
 * @returns {Array} Array of downloadable files
 */
export function getOrderDownloads(order) {
  if (!order) return [];
  
  const downloads = [];
  
  // Add invoice if available
  if (order.invoice_url) {
    downloads.push({
      type: 'invoice',
      label: 'Download Invoice',
      url: order.invoice_url,
      icon: 'document'
    });
  }
  
  // Add receipt if available
  if (order.receipt_url) {
    downloads.push({
      type: 'receipt',
      label: 'Download Receipt',
      url: order.receipt_url,
      icon: 'receipt'
    });
  }
  
  return downloads;
}

/**
 * Get shipping address formatted for display
 * @param {Object} order - Order object
 * @returns {string} Formatted address
 */
export function getFormattedShippingAddress(order) {
  if (!order || !order.shipping) return 'N/A';
  
  const shipping = order.shipping;
  const parts = [
    shipping.name,
    shipping.address1,
    shipping.address2,
    `${shipping.zip} ${shipping.city}`,
    shipping.state,
    shipping.country
  ].filter(Boolean);
  
  return parts.join(', ');
}

/**
 * Get billing address formatted for display
 * @param {Object} order - Order object
 * @returns {string} Formatted address
 */
export function getFormattedBillingAddress(order) {
  if (!order || !order.billing) return 'N/A';
  
  const billing = order.billing;
  const parts = [
    billing.name,
    billing.address1,
    billing.address2,
    `${billing.zip} ${billing.city}`,
    billing.state,
    billing.country
  ].filter(Boolean);
  
  return parts.join(', ');
}

/**
 * Search orders by text
 * @param {string} searchTerm - Search term
 * @param {Object} options - Search options
 * @returns {Promise<Object>} Search results
 */
export async function searchOrders(searchTerm, options = {}) {
  try {
    const {
      page = 1,
      limit = 20
    } = options;

    // Swell search implementation
    const orders = await swell.account.listOrders({
      page,
      limit,
      search: searchTerm,
      expand: ['items.product', 'items.variant']
    });
    
    return {
      success: true,
      orders: orders.results || [],
      pagination: {
        page: orders.page || 1,
        pages: orders.pages || 1,
        count: orders.count || 0
      },
      error: null
    };
  } catch (error) {
    console.error('Error searching orders:', error);
    return {
      success: false,
      orders: [],
      pagination: null,
      error: error.message || 'Failed to search orders'
    };
  }
}