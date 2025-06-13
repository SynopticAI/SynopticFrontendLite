// src/lib/swell.js
import swell from 'swell-js';

// Initialize Swell client
swell.init('synoptic', 'pk_DUjtNbQywQglujuOK1Ykiqp6vcoSc7Kt');

/**
 * Fetch a single product by slug
 * @param {string} slug - Product slug
 * @returns {Promise<Object|null>} Product data or null if not found
 */
export async function getProductBySlug(slug) {
  try {
    const products = await swell.products.list({
      where: {
        slug: slug
      },
      limit: 1
    });
    
    return products.results && products.results.length > 0 ? products.results[0] : null;
  } catch (error) {
    console.error('Error fetching product:', error);
    return null;
  }
}

/**
 * Fetch all products
 * @returns {Promise<Array>} Array of products
 */
export async function getAllProducts() {
  try {
    const products = await swell.products.list({
      limit: 25
    });
    
    return products.results || [];
  } catch (error) {
    console.error('Error fetching products:', error);
    return [];
  }
}

/**
 * Format price for display
 * @param {number} price - Price in cents
 * @param {string} currency - Currency code (default: 'USD')
 * @returns {string} Formatted price string
 */
export function formatPrice(price, currency = 'USD') {
  if (typeof price !== 'number') return 'Price unavailable';
  
  return new Intl.NumberFormat('en-US', {
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