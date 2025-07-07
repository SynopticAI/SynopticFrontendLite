// src/lib/swell.js - Fixed Swell integration with correct initialization
import swell from 'swell-js';

// Initialize Swell client with correct pattern
swell.init('synoptic', 'pk_DUjtNbQywQglujuOK1Ykiqp6vcoSc7Kt');

// =============================================================================
// PRODUCT FUNCTIONS
// =============================================================================

/**
 * Get product by ID
 * @param {string} productId - Product ID
 * @returns {Promise<Object|null>} Product object or null
 */
export async function getProductById(productId) {
  try {
    const product = await swell.products.get(productId, {
      expand: ['variants', 'options', 'images']
    });
    return product;
  } catch (error) {
    console.error('Error fetching product:', error);
    return null;
  }
}

/**
 * Get product by slug
 * @param {string} slug - Product slug
 * @returns {Promise<Object|null>} Product object or null
 */
export async function getProductBySlug(slug) {
  try {
    const products = await swell.products.list({
      where: { slug: slug },
      limit: 1,
      expand: ['variants', 'options', 'images']
    });
    
    return products.results?.[0] || null;
  } catch (error) {
    console.error('Error fetching product by slug:', error);
    return null;
  }
}

/**
 * Format price with currency
 * @param {number} price - Price amount
 * @param {string} currency - Currency code (default: EUR)
 * @returns {string} Formatted price string
 */
export function formatPrice(price, currency = 'EUR') {
  if (typeof price !== 'number') return 'N/A';
  
  try {
    return new Intl.NumberFormat('de-DE', {
      style: 'currency',
      currency: currency
    }).format(price);
  } catch (error) {
    return `${currency} ${price.toFixed(2)}`;
  }
}

/**
 * Get product image URL with fallback
 * @param {Object} product - Product object
 * @param {number} index - Image index (default: 0)
 * @returns {string} Image URL or placeholder
 */
export function getProductImageUrl(product, index = 0) {
  if (!product) return '/placeholder-product.jpg';
  
  if (product.images && product.images.length > 0) {
    const image = product.images[index] || product.images[0];
    return image.url || image.file?.url || '/placeholder-product.jpg';
  }
  
  return '/placeholder-product.jpg';
}

/**
 * Get all product image URLs
 * @param {Object} product - Product object
 * @returns {Array<string>} Array of image URLs
 */
export function getProductImageUrls(product) {
  if (!product) return ['/placeholder-product.jpg'];
  
  if (product.images && product.images.length > 0) {
    return product.images.map(img => img.url || img.file?.url).filter(Boolean);
  }
  
  return ['/placeholder-product.jpg'];
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
 * Get product options for display a
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
 * Get product variant by options
 * @param {Object} product - Product object
 * @param {Object} selectedOptions - Selected options object
 * @returns {Object|null} Matching variant or null
 */
export function getProductVariant(product, selectedOptions = {}) {
  if (!product.variants || product.variants.length === 0) {
    return null;
  }

  const optionKeys = Object.keys(selectedOptions);
  
  if (optionKeys.length === 0) {
    return product.variants[0]; // Return first variant if no options selected
  }

  return product.variants.find(variant => {
    if (!variant.option_value_ids) return false;
    
    return optionKeys.every(optionName => {
      const option = product.options?.find(opt => opt.name === optionName);
      if (!option) return false;
      
      const selectedValue = selectedOptions[optionName];
      const valueObj = option.values?.find(val => val.name === selectedValue);
      if (!valueObj) return false;
      
      return variant.option_value_ids.includes(valueObj.id);
    });
  }) || null;
}

/**
 * Get product variants with formatted data
 * @param {Object} product - Product object
 * @returns {Array} Array of formatted variants
 */
export function getFormattedVariants(product) {
  if (!product.variants) return [];
  
  return product.variants.map(variant => ({
    id: variant.id,
    name: variant.name || 'Default',
    price: variant.price,
    formattedPrice: formatPrice(variant.price, product.currency || 'EUR'),
    stock: variant.stock_level,
    options: variant.option_value_ids || []
  }));
}

/**
 * Get product options with formatted data
 * @param {Object} product - Product object
 * @returns {Array} Array of formatted options
 */
export function getFormattedOptions(product) {
  if (!product.options) return [];
  
  return product.options.map(option => ({
    id: option.id,
    name: option.name,
    type: option.input_type || 'select',
    required: option.required || false,
    values: option.values?.map(value => ({
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
    console.log('🛒 Swell: Adding item to cart:', { productId, quantity, options, variantId });
    
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
    
    console.log('✅ Swell: Item added to cart successfully');
    return {
      success: true,
      cart: result,
      error: null
    };
  } catch (error) {
    console.error('❌ Swell: Error adding item to cart:', error);
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
 * Update cart item
 * @param {string} itemId - Cart item ID
 * @param {Object} updates - Updates object (quantity, options, etc.)
 * @returns {Promise<Object>} Result object
 */
export async function updateCartItem(itemId, updates) {
  try {
    const result = await swell.cart.updateItem(itemId, updates);
    
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
 * Clear all items from cart
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
 * @param {Object} cart - Cart object (optional, will fetch if not provided)
 * @returns {Promise<number>} Total item count
 */
export async function getCartItemCount(cart = null) {
  try {
    if (!cart) {
      cart = await getCart();
    }
    
    if (!cart || !cart.items) return 0;
    
    return cart.items.reduce((total, item) => total + (item.quantity || 0), 0);
  } catch (error) {
    console.error('Error getting cart item count:', error);
    return 0;
  }
}

/**
 * Get cart subtotal
 * @param {Object} cart - Cart object (optional, will fetch if not provided)
 * @returns {Promise<number>} Cart subtotal
 */
export async function getCartSubtotal(cart = null) {
  try {
    if (!cart) {
      cart = await getCart();
    }
    
    return cart?.sub_total || 0;
  } catch (error) {
    console.error('Error getting cart subtotal:', error);
    return 0;
  }
}

// =============================================================================
// ACCOUNT & AUTHENTICATION FUNCTIONS
// =============================================================================

/**
 * Associate cart with current logged-in account
 * @returns {Promise<Object>} Result object
 */
export async function associateCartWithAccount() {
  try {
    console.log('🔗 Associating cart with authenticated account...');
    
    // Get current account to verify authentication
    const account = await swell.account.get();
    if (!account) {
      return {
        success: false,
        cart: null,
        account: null,
        error: 'No authenticated account found'
      };
    }

    // Get current cart and associate with account
    const cart = await swell.cart.get();
    
    console.log('✅ Cart successfully associated with account:', account.email);
    return {
      success: true,
      cart: cart,
      account: account,
      error: null
    };
  } catch (error) {
    console.error('❌ Error associating cart with account:', error);
    return {
      success: false,
      cart: null,
      account: null,
      error: error.message || 'Failed to associate cart with account'
    };
  }
}

/**
 * Set cart customer using Firebase user (deprecated - use associateCartWithAccount)
 * @param {Object} firebaseUser - Firebase user object
 * @returns {Promise<Object>} Result object
 */
export async function setCartCustomer(firebaseUser) {
  console.warn('🔗 setCartCustomer is deprecated, cart association happens automatically when account is logged in');
  
  try {
    // Just verify that user is authenticated with Swell
    const account = await swell.account.get();
    if (!account) {
      return {
        success: false,
        cart: null,
        account: null,
        error: 'User not authenticated with Swell'
      };
    }

    const cart = await swell.cart.get();
    
    return {
      success: true,
      cart: cart,
      account: account,
      error: null
    };
  } catch (error) {
    console.error('❌ Error in setCartCustomer:', error);
    return {
      success: false,
      cart: null,
      account: null,
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
export default swell;