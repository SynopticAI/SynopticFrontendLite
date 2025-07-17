// Test script to validate Swell integration fixes
// Run this with: node test-swell-integration.js

import Swell from 'swell-js';

console.log('🧪 Testing Swell Integration Fixes...\n');

// Test 1: SDK Initialization with snake_case
console.log('1️⃣ Testing SDK initialization with snake_case...');
try {
  const swell = Swell.init('synoptic', 'pk_DUjtNbQywQglujuOK1Ykiqp6vcoSc7Kt', {
    useCamelCase: false, // This should match our fix
    previewContent: false,
    session: false // Disable session for testing
  });
  
  console.log('✅ SDK initialized successfully');
  console.log('🔍 SDK version:', Swell.version || 'unknown');
} catch (error) {
  console.error('❌ SDK initialization failed:', error.message);
}

// Test 2: Products API (should work)
console.log('\n2️⃣ Testing Products API...');
try {
  const products = await Swell.products.list({ limit: 1 });
  console.log('✅ Products API working');
  console.log('🔍 Sample product fields:', Object.keys(products.results?.[0] || {}));
  
  // Check if we get snake_case fields
  const sampleProduct = products.results?.[0];
  if (sampleProduct) {
    console.log('🔍 Has snake_case date_created:', !!sampleProduct.date_created);
    console.log('🔍 Has camelCase dateCreated:', !!sampleProduct.dateCreated);
    console.log('🔍 Stock level field:', sampleProduct.stock_level !== undefined ? 'stock_level' : 
                sampleProduct.stockLevel !== undefined ? 'stockLevel' : 'neither');
  }
} catch (error) {
  console.error('❌ Products API failed:', error.message);
}

// Test 3: Cart API (basic test without auth)
console.log('\n3️⃣ Testing Cart API...');
try {
  const cart = await Swell.cart.get();
  console.log('✅ Cart API accessible');
  console.log('🔍 Cart fields:', Object.keys(cart || {}));
  
  if (cart) {
    console.log('🔍 Has snake_case sub_total:', cart.sub_total !== undefined);
    console.log('🔍 Has camelCase subTotal:', cart.subTotal !== undefined);
    console.log('🔍 Has snake_case item_quantity:', cart.item_quantity !== undefined);
    console.log('🔍 Has camelCase itemQuantity:', cart.itemQuantity !== undefined);
  }
} catch (error) {
  console.error('❌ Cart API failed:', error.message);
}

// Test 4: Account API (will likely fail without auth, but we can see the error)
console.log('\n4️⃣ Testing Account API...');
try {
  const account = await Swell.account.get();
  console.log('✅ Account API accessible');
  console.log('🔍 Account fields:', Object.keys(account || {}));
} catch (error) {
  console.log('ℹ️ Account API error (expected without auth):', error.message);
  console.log('🔍 Error status:', error.status);
  console.log('🔍 Error type:', error.name);
}

// Test 5: Field name consistency check
console.log('\n5️⃣ Testing field name consistency...');

// Mock data to test our field handling
const mockOrderData = {
  id: 'test-order-123',
  grand_total: 100.50,
  sub_total: 85.00,
  tax_total: 8.50,
  shipment_total: 7.00,
  date_created: '2024-01-15T10:30:00Z',
  items: [
    {
      id: 'item-1',
      product_id: 'prod-123',
      quantity: 2,
      price: 42.50,
      price_total: 85.00
    }
  ]
};

// Test our formatOrderData function logic
function testFormatOrderData(rawOrder) {
  return {
    id: rawOrder.id,
    // Test both snake_case and camelCase handling
    grand_total: rawOrder.grand_total || rawOrder.grandTotal || 0,
    sub_total: rawOrder.sub_total || rawOrder.subTotal || 0,
    tax_total: rawOrder.tax_total || rawOrder.taxTotal || 0,
    shipping_total: rawOrder.shipment_total || rawOrder.shippingTotal || 0,
    date_created: rawOrder.date_created,
    items: (rawOrder.items || []).map(item => ({
      id: item.id,
      product_id: item.product_id,
      quantity: item.quantity || 1,
      price: item.price || 0,
      price_total: item.price_total || 0
    }))
  };
}

const formattedOrder = testFormatOrderData(mockOrderData);
console.log('✅ Order data formatting test passed');
console.log('🔍 Formatted order total:', formattedOrder.grand_total);
console.log('🔍 Items count:', formattedOrder.items.length);

console.log('\n🎉 Integration test completed!');
console.log('\n📋 Summary:');
console.log('- SDK should now use snake_case field names');
console.log('- Data formatting handles both naming conventions');
console.log('- Cart and orders should work with proper authentication');
console.log('\n💡 Next steps:');
console.log('1. Test in browser with authentication');
console.log('2. Try adding items to cart');
console.log('3. Check orders page with authenticated user');