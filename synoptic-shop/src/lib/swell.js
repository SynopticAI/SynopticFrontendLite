// src/lib/swell.js - Enhanced version with options support
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