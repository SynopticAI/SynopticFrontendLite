// src/lib/payment-integration.js - Payment Processing with Swell

class PaymentManager {
  constructor() {
    this.isInitialized = false;
    this.currentPaymentMethod = null;
    this.paymentElement = null;
  }

  async initialize() {
    try {
      console.log('💳 Initializing payment manager...');
      
      // Wait for Swell to be available
      await this.waitForSwell();
      
      // Initialize payment methods
      await this.loadPaymentMethods();
      
      this.isInitialized = true;
      console.log('💳 Payment manager initialized');
      
    } catch (error) {
      console.error('💳 Error initializing payment manager:', error);
      throw error;
    }
  }

  async waitForSwell() {
    return new Promise((resolve) => {
      if (window.swell) {
        resolve(window.swell);
      } else {
        const checkSwell = () => {
          if (window.swell) {
            resolve(window.swell);
          } else {
            setTimeout(checkSwell, 100);
          }
        };
        checkSwell();
      }
    });
  }

  async loadPaymentMethods() {
    try {
      const swell = window.swell;
      if (!swell) {
        throw new Error('Swell not available');
      }

      // Get available payment methods from Swell settings
      const settings = await swell.settings.get();
      const paymentMethods = settings.payments?.methods || [];
      
      console.log('💳 Available payment methods:', paymentMethods);
      
      // Setup default payment method (usually card)
      this.currentPaymentMethod = 'card';
      
      return paymentMethods;
      
    } catch (error) {
      console.error('💳 Error loading payment methods:', error);
      return [];
    }
  }

  async setupPaymentElement() {
    try {
      const paymentContainer = document.getElementById('payment-element');
      if (!paymentContainer) {
        console.warn('💳 Payment element container not found');
        return;
      }

      // For now, show a simple card form
      // In a real implementation, you would integrate with Stripe Elements or another payment processor
      paymentContainer.innerHTML = `
        <div class="space-y-4">
          <div>
            <label for="card-number" class="block text-sm font-medium text-gray-700 dark:text-gray-300">
              Card Number *
            </label>
            <input
              type="text"
              id="card-number"
              name="card_number"
              placeholder="1234 5678 9012 3456"
              maxlength="19"
              class="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 shadow-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
              required
            />
          </div>
          
          <div class="grid grid-cols-2 gap-4">
            <div>
              <label for="card-expiry" class="block text-sm font-medium text-gray-700 dark:text-gray-300">
                Expiry Date *
              </label>
              <input
                type="text"
                id="card-expiry"
                name="card_expiry"
                placeholder="MM/YY"
                maxlength="5"
                class="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 shadow-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
                required
              />
            </div>
            
            <div>
              <label for="card-cvc" class="block text-sm font-medium text-gray-700 dark:text-gray-300">
                CVC *
              </label>
              <input
                type="text"
                id="card-cvc"
                name="card_cvc"
                placeholder="123"
                maxlength="4"
                class="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 shadow-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
                required
              />
            </div>
          </div>
          
          <div>
            <label for="card-name" class="block text-sm font-medium text-gray-700 dark:text-gray-300">
              Cardholder Name *
            </label>
            <input
              type="text"
              id="card-name"
              name="card_name"
              placeholder="John Doe"
              class="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 shadow-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
              required
            />
          </div>
        </div>
      `;

      // Add input formatting
      this.setupCardFormatting();
      
    } catch (error) {
      console.error('💳 Error setting up payment element:', error);
    }
  }

  setupCardFormatting() {
    // Card number formatting
    const cardNumberInput = document.getElementById('card-number');
    if (cardNumberInput) {
      cardNumberInput.addEventListener('input', (e) => {
        let value = e.target.value.replace(/\s/g, '').replace(/\D/g, '');
        value = value.replace(/(\d{4})(?=\d)/g, '$1 ');
        e.target.value = value;
      });
    }

    // Expiry date formatting
    const cardExpiryInput = document.getElementById('card-expiry');
    if (cardExpiryInput) {
      cardExpiryInput.addEventListener('input', (e) => {
        let value = e.target.value.replace(/\D/g, '');
        if (value.length >= 2) {
          value = value.substring(0, 2) + '/' + value.substring(2, 4);
        }
        e.target.value = value;
      });
    }

    // CVC formatting
    const cardCvcInput = document.getElementById('card-cvc');
    if (cardCvcInput) {
      cardCvcInput.addEventListener('input', (e) => {
        e.target.value = e.target.value.replace(/\D/g, '');
      });
    }
  }

  validatePaymentData() {
    const cardNumber = document.getElementById('card-number')?.value.replace(/\s/g, '');
    const cardExpiry = document.getElementById('card-expiry')?.value;
    const cardCvc = document.getElementById('card-cvc')?.value;
    const cardName = document.getElementById('card-name')?.value;

    const errors = [];

    // Basic validation
    if (!cardNumber || cardNumber.length < 13) {
      errors.push('Please enter a valid card number');
    }

    if (!cardExpiry || !/^\d{2}\/\d{2}$/.test(cardExpiry)) {
      errors.push('Please enter a valid expiry date (MM/YY)');
    }

    if (!cardCvc || cardCvc.length < 3) {
      errors.push('Please enter a valid CVC');
    }

    if (!cardName || cardName.trim().length < 2) {
      errors.push('Please enter the cardholder name');
    }

    // Check expiry date is in the future
    if (cardExpiry && /^\d{2}\/\d{2}$/.test(cardExpiry)) {
      const [month, year] = cardExpiry.split('/');
      const expiry = new Date(2000 + parseInt(year), parseInt(month) - 1);
      const now = new Date();
      
      if (expiry < now) {
        errors.push('Card has expired');
      }
    }

    return {
      valid: errors.length === 0,
      errors,
      data: errors.length === 0 ? {
        number: cardNumber,
        exp_month: cardExpiry ? cardExpiry.split('/')[0] : '',
        exp_year: cardExpiry ? cardExpiry.split('/')[1] : '',
        cvc: cardCvc,
        name: cardName
      } : null
    };
  }

  async processPayment(orderData) {
    try {
      console.log('💳 Processing payment...', orderData);

      const paymentValidation = this.validatePaymentData();
      if (!paymentValidation.valid) {
        throw new Error(paymentValidation.errors.join(', '));
      }

      const swell = window.swell;
      if (!swell) {
        throw new Error('Payment system not available');
      }

      // Prepare payment data for Swell
      const paymentData = {
        ...orderData,
        payment: {
          method: this.currentPaymentMethod,
          card: paymentValidation.data
        }
      };

      // Submit order with payment
      const result = await swell.cart.submitOrder(paymentData);

      if (result && result.id) {
        console.log('✅ Payment processed successfully:', result);
        return {
          success: true,
          order: result,
          error: null
        };
      } else {
        throw new Error('Payment failed - no order created');
      }

    } catch (error) {
      console.error('💳 Payment processing error:', error);
      return {
        success: false,
        order: null,
        error: error.message || 'Payment processing failed'
      };
    }
  }

  // Helper method to get payment status
  getPaymentStatus() {
    return {
      initialized: this.isInitialized,
      method: this.currentPaymentMethod,
      ready: this.isInitialized && this.currentPaymentMethod
    };
  }
}

// Create global payment manager instance
const paymentManager = new PaymentManager();

// Make available globally
if (typeof window !== 'undefined') {
  window.paymentManager = paymentManager;
}

export default paymentManager;