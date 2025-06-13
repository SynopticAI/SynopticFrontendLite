// src/lib/swell.js - Enhanced version with full cart functionality
import swell from 'swell-js';

// Initialize Swell client
swell.init('synoptic', 'pk_DUjtNbQywQglujuOK1Ykiqp6vcoSc7Kt');

/**
 * Fetch a single product by slug with expanded options
 * @param {string} slug - Product slug
 * @returns {Promise<Object|null>} Product data or null if not found
 */
export async function getProductBySlug(slug) {
  try {
    const products = await swell.products.list({
      where: {
        slug: slug
      },
      limit: 1,
      expand: ['variants', 'options', 'images'] // Expand related data
    });
    
    return products.results && products.results.length > 0 ? products.results[0] : null;
  } catch (error) {
    console.error('Error fetching product:', error);
    return null;
  }
}

/**
 * Get product pricing info - handles both simple products and products with options
 * @param {Object} product - Product object from Swell
 * @returns {Object} Pricing information
 */
export function getProductPricing(product) {
  if (!product) {
    return {
      hasOptions: false,
      price: null,
      priceRange: null,
      formattedPrice: 'Price unavailable',
      currency: 'EUR'
    };
  }

  const currency = product.currency || 'EUR';
  
  // Check if product has options/variants with different prices
  if (product.options && product.options.length > 0) {
    const optionValues = product.options.flatMap(option => option.values || []);
    const prices = optionValues
      .map(value => value.price)
      .filter(price => typeof price === 'number')
      .sort((a, b) => a - b);
    
    if (prices.length > 0) {
      const minPrice = prices[0];
      const maxPrice = prices[prices.length - 1];
      
      return {
        hasOptions: true,
        price: null,
        priceRange: { min: minPrice, max: maxPrice },
        formattedPrice: minPrice === maxPrice 
          ? formatPrice(minPrice, currency)
          : `${formatPrice(minPrice, currency)} - ${formatPrice(maxPrice, currency)}`,
        currency
      };
    }
  }
  
  // Check if product has variants with different prices
  if (product.variants && product.variants.length > 0) {
    const variantPrices = product.variants
      .map(variant => variant.price)
      .filter(price => typeof price === 'number')
      .sort((a, b) => a - b);
    
    if (variantPrices.length > 0) {
      const minPrice = variantPrices[0];
      const maxPrice = variantPrices[variantPrices.length - 1];
      
      return {
        hasOptions: true,
        price: null,
        priceRange: { min: minPrice, max: maxPrice },
        formattedPrice: minPrice === maxPrice 
          ? formatPrice(minPrice, currency)
          : `${formatPrice(minPrice, currency)} - ${formatPrice(maxPrice, currency)}`,
        currency
      };
    }
  }
  
  // Simple product with single price
  return {
    hasOptions: false,
    price: product.price,
    priceRange: null,
    formattedPrice: formatPrice(product.price, currency),
    currency
  };
}

/**
 * Format price for display
 * @param {number} price - Price in cents or currency units
 * @param {string} currency - Currency code (default: 'EUR')
 * @returns {string} Formatted price string
 */
export function formatPrice(price, currency = 'EUR') {
  if (typeof price !== 'number') return 'Price unavailable';
  
  return new Intl.NumberFormat('de-DE', {
    style: 'currency',
    currency: currency,
  }).format(price);
}

/**
 * Get the main product image URL
 * @param {Object} product - Product object from Swell
 * @returns {string} Image URL or placeholder
 */
export function getProductImageUrl(product) {
  if (product?.images && product.images.length > 0) {
    return product.images[0].file?.url || '/placeholder-product.jpg';
  }
  return '/placeholder-product.jpg';
}

/**
 * Get all product image URLs
 * @param {Object} product - Product object from Swell
 * @returns {Array<string>} Array of image URLs
 */
export function getProductImageUrls(product) {
  if (product?.images && product.images.length > 0) {
    return product.images.map(img => img.file?.url).filter(Boolean);
  }
  return ['/placeholder-product.jpg'];
}

/**
 * Get product description with proper HTML handling
 * @param {Object} product - Product object from Swell
 * @returns {string} HTML description or plain text
 */
export function getProductDescription(product) {
  if (!product) return '';
  
  // Swell descriptions can be HTML or plain text
  return product.description || product.meta_description || '';
}

/**
 * Check if product is in stock
 * @param {Object} product - Product object from Swell
 * @returns {boolean} Stock availability
 */
export function isProductInStock(product) {
  if (!product) return false;
  
  // If stock_level is null, assume it's in stock (no inventory tracking)
  // If it's a number, check if it's greater than 0
  return product.stock_level === null || product.stock_level > 0;
}

/**
 * Get product options for display
 * @param {Object} product - Product object from Swell
 * @returns {Array} Array of product options
 */
export function getProductOptions(product) {
  if (!product || !product.options) return [];
  
  return product.options.map(option => ({
    id: option.id,
    name: option.name,
    type: option.input_type || 'select',
    required: option.required || false,
    values: (option.values || []).map(value => ({
      id: value.id,
      name: value.name,
      price: value.price || 0,
      formattedPrice: value.price ? formatPrice(value.price, product.currency || 'EUR') : null
    }))
  }));
}

/**
 * Fetch all products
 * @returns {Promise<Array>} Array of products
 */
export async function getAllProducts() {
  try {
    const products = await swell.products.list({
      limit: 25,
      expand: ['variants', 'options', 'images']
    });
    
    return products.results || [];
  } catch (error) {
    console.error('Error fetching products:', error);
    return [];
  }
}

// =============================================================================
// CART FUNCTIONALITY
// =============================================================================

/**
 * Get current cart
 * @returns {Promise<Object|null>} Cart object or null
 */
export async function getCart() {
  try {
    const cart = await swell.cart.get();
    return cart;
  } catch (error) {
    console.error('Error fetching cart:', error);
    return null;
  }
}

/**
 * Add item to cart
 * @param {string} productId - Product ID
 * @param {number} quantity - Quantity to add
 * @param {Object} options - Product options (optional)
 * @param {string} variantId - Variant ID (optional)
 * @returns {Promise<Object>} Result object
 */
export async function addToCart(productId, quantity = 1, options = {}, variantId = null) {
  try {
    const item = {
      product_id: productId,
      quantity: quantity
    };

    // Add variant if specified
    if (variantId) {
      item.variant_id = variantId;
    }

    // Add options if specified
    if (Object.keys(options).length > 0) {
      item.options = options;
    }

    const result = await swell.cart.addItem(item);
    
    return {
      success: true,
      cart: result,
      error: null
    };
  } catch (error) {
    console.error('Error adding item to cart:', error);
    return {
      success: false,
      cart: null,
      error: error.message || 'Failed to add item to cart'
    };
  }
}

/**
 * Remove item from cart
 * @param {string} itemId - Cart item ID
 * @returns {Promise<Object>} Result object
 */
export async function removeFromCart(itemId) {
  try {
    const result = await swell.cart.removeItem(itemId);
    
    return {
      success: true,
      cart: result,
      error: null
    };
  } catch (error) {
    console.error('Error removing item from cart:', error);
    return {
      success: false,
      cart: null,
      error: error.message || 'Failed to remove item from cart'
    };
  }
}

/**
 * Update cart item quantity
 * @param {string} itemId - Cart item ID
 * @param {number} quantity - New quantity
 * @returns {Promise<Object>} Result object
 */
export async function updateCartItem(itemId, quantity) {
  try {
    const result = await swell.cart.updateItem(itemId, {
      quantity: quantity
    });
    
    return {
      success: true,
      cart: result,
      error: null
    };
  } catch (error) {
    console.error('Error updating cart item:', error);
    return {
      success: false,
      cart: null,
      error: error.message || 'Failed to update cart item'
    };
  }
}

/**
 * Clear entire cart
 * @returns {Promise<Object>} Result object
 */
export async function clearCart() {
  try {
    const result = await swell.cart.setItems([]);
    
    return {
      success: true,
      cart: result,
      error: null
    };
  } catch (error) {
    console.error('Error clearing cart:', error);
    return {
      success: false,
      cart: null,
      error: error.message || 'Failed to clear cart'
    };
  }
}

/**
 * Get cart item count
 * @returns {Promise<number>} Number of items in cart
 */
export async function getCartItemCount() {
  try {
    const cart = await getCart();
    if (!cart || !cart.items) return 0;
    
    return cart.items.reduce((total, item) => total + (item.quantity || 0), 0);
  } catch (error) {
    console.error('Error getting cart item count:', error);
    return 0;
  }
}

/**
 * Get cart subtotal
 * @returns {Promise<number>} Cart subtotal
 */
export async function getCartSubtotal() {
  try {
    const cart = await getCart();
    return cart?.sub_total || 0;
  } catch (error) {
    console.error('Error getting cart subtotal:', error);
    return 0;
  }
}

// =============================================================================
// CUSTOMER FUNCTIONS
// =============================================================================

/**
 * Create or update customer from Firebase user data
 * @param {Object} firebaseUser - Firebase user object
 * @returns {Promise<Object>} Result object
 */
export async function createOrUpdateCustomer(firebaseUser) {
  try {
    const customerData = {
      email: firebaseUser.email,
      first_name: firebaseUser.displayName?.split(' ')[0] || '',
      last_name: firebaseUser.displayName?.split(' ').slice(1).join(' ') || '',
      email_verified: firebaseUser.emailVerified,
      metadata: {
        firebase_uid: firebaseUser.uid,
        auth_provider: 'firebase'
      }
    };

    // Check if customer already exists
    const existingCustomers = await swell.customers.list({
      where: {
        email: firebaseUser.email
      },
      limit: 1
    });

    let customer;
    if (existingCustomers.results && existingCustomers.results.length > 0) {
      // Update existing customer
      customer = await swell.customers.update(existingCustomers.results[0].id, customerData);
    } else {
      // Create new customer
      customer = await swell.customers.create(customerData);
    }

    return {
      success: true,
      customer: customer,
      error: null
    };
  } catch (error) {
    console.error('Error creating/updating customer:', error);
    return {
      success: false,
      customer: null,
      error: error.message || 'Failed to create/update customer'
    };
  }
}

/**
 * Set customer for cart (authentication)
 * @param {Object} firebaseUser - Firebase user object
 * @returns {Promise<Object>} Result object
 */
export async function setCartCustomer(firebaseUser) {
  try {
    // First create/update customer
    const customerResult = await createOrUpdateCustomer(firebaseUser);
    
    if (!customerResult.success) {
      return customerResult;
    }

    // Set customer for current cart
    const result = await swell.cart.update({
      account_id: customerResult.customer.id
    });

    return {
      success: true,
      cart: result,
      customer: customerResult.customer,
      error: null
    };
  } catch (error) {
    console.error('Error setting cart customer:', error);
    return {
      success: false,
      cart: null,
      customer: null,
      error: error.message || 'Failed to set cart customer'
    };
  }
}

// =============================================================================
// CHECKOUT FUNCTIONS
// =============================================================================

/**
 * Get available payment methods
 * @returns {Promise<Array>} Array of payment methods
 */
export async function getPaymentMethods() {
  try {
    const settings = await swell.settings.get();
    return settings.payments?.methods || [];
  } catch (error) {
    console.error('Error fetching payment methods:', error);
    return [];
  }
}

/**
 * Submit order (checkout)
 * @param {Object} orderData - Order data including shipping, billing, payment
 * @returns {Promise<Object>} Result object
 */
export async function submitOrder(orderData) {
  try {
    const order = await swell.cart.submitOrder(orderData);
    
    return {
      success: true,
      order: order,
      error: null
    };
  } catch (error) {
    console.error('Error submitting order:', error);
    return {
      success: false,
      order: null,
      error: error.message || 'Failed to submit order'
    };
  }
}

/**
 * Calculate shipping rates
 * @param {Object} shippingAddress - Shipping address
 * @returns {Promise<Array>} Array of shipping options
 */
export async function getShippingRates(shippingAddress) {
  try {
    const rates = await swell.cart.getShippingRates(shippingAddress);
    return rates || [];
  } catch (error) {
    console.error('Error getting shipping rates:', error);
    return [];
  }
}

// Export swell instance for advanced usage
export { swell };