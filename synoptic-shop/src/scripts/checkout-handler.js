// src/scripts/checkout-handler.js - Enhanced Checkout Handler with Complete Integration
import authStateManager from '../lib/auth-state-manager.js';
import { getUserDataForSwell } from '../lib/firebase.js';
import { formatPrice } from '../lib/swell.js';

class CheckoutHandler {
  constructor() {
    this.currentUser = null;
    this.checkoutData = {};
    this.authUnsubscribe = null;
    this.isInitialized = false;
    this.currentStep = 'guest-selection'; // guest-selection, form, processing, complete
    this.init();
  }

  init() {
    console.log('🛒 Initializing enhanced checkout handler...');
    
    // Only initialize on checkout-related pages
    if (!this.isCheckoutPage()) {
      console.log('🛒 Not a checkout page, skipping initialization');
      return;
    }

    // Wait for DOM to be ready
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', () => this.setupCheckout());
    } else {
      this.setupCheckout();
    }
  }

  isCheckoutPage() {
    const path = window.location.pathname;
    return path.includes('/checkout') || 
           path.includes('/order-confirmation');
  }

  async setupCheckout() {
    console.log('🛒 Setting up enhanced checkout page...');
    
    try {
      // Setup auth integration first
      this.setupAuthIntegration();
      
      // Wait for auth to be ready
      await authStateManager.waitForReady();
      
      // Get current auth state
      this.currentUser = authStateManager.getCurrentUser();
      console.log('🛒 Initial auth state:', this.currentUser ? `✅ ${this.currentUser.email}` : '❌ Guest');
      
      // Setup event listeners
      this.setupEventListeners();
      
      // Initialize based on auth state
      if (this.currentUser) {
        this.handleAuthenticatedFlow();
      } else {
        this.handleGuestFlow();
      }
      
      this.isInitialized = true;
      console.log('🛒 Checkout handler initialized successfully');
      
    } catch (error) {
      console.error('🛒 Error initializing checkout:', error);
      this.showError('Failed to initialize checkout. Please refresh the page.');
    }
  }

  setupAuthIntegration() {
    // Subscribe to auth state changes
    this.authUnsubscribe = authStateManager.subscribe((user) => {
      console.log('🛒 Checkout: Auth state changed:', user ? `✅ ${user.email}` : '❌ Guest');
      
      const previousUser = this.currentUser;
      this.currentUser = user;
      
      // Only handle changes after initial setup
      if (this.isInitialized) {
        this.handleAuthStateChange(user, previousUser);
      }
    });
  }

  setupEventListeners() {
    // Guest checkout section buttons
    this.setupGuestCheckoutListeners();
    
    // Form validation and interaction
    this.setupFormListeners();
    
    // Auth modal integration
    this.setupAuthModalListeners();
  }

  setupGuestCheckoutListeners() {
    // Sign in button
    const signInBtn = document.getElementById('checkout-sign-in-btn');
    if (signInBtn) {
      signInBtn.addEventListener('click', () => {
        this.openAuthModal('signin');
      });
    }

    // Create account button
    const createAccountBtn = document.getElementById('checkout-create-account-btn');
    if (createAccountBtn) {
      createAccountBtn.addEventListener('click', () => {
        this.openAuthModal('signup');
      });
    }

    // Continue as guest button
    const guestBtn = document.getElementById('continue-as-guest-btn');
    if (guestBtn) {
      guestBtn.addEventListener('click', () => {
        this.continueAsGuest();
      });
    }
  }

  setupFormListeners() {
    // Email field for returning customer detection
    const emailInput = document.getElementById('checkout-email');
    if (emailInput) {
      emailInput.addEventListener('blur', () => {
        if (!this.currentUser) {
          this.checkReturningCustomer(emailInput.value);
        }
      });
      
      // Clear returning customer prompt when email changes
      emailInput.addEventListener('input', () => {
        this.hideReturningCustomerPrompt();
      });
    }

    // Phone number formatting
    const phoneInput = document.getElementById('checkout-phone');
    if (phoneInput) {
      phoneInput.addEventListener('input', (e) => {
        this.formatPhoneNumber(e.target);
      });
    }

    // Address validation and formatting
    this.setupAddressValidation();
  }

  setupAuthModalListeners() {
    // Listen for auth modal events
    document.addEventListener('authModalClosed', () => {
      console.log('🛒 Auth modal closed');
    });

    document.addEventListener('authSuccess', (e) => {
      console.log('🛒 Auth success event received:', e.detail);
      // Auth state change will be handled by authStateManager subscription
    });
  }

  setupAddressValidation() {
    // Add validation for required fields
    const requiredFields = [
      'checkout-first-name',
      'checkout-last-name', 
      'checkout-address1',
      'checkout-city',
      'checkout-zip',
      'checkout-country'
    ];

    requiredFields.forEach(fieldId => {
      const field = document.getElementById(fieldId);
      if (field) {
        field.addEventListener('blur', () => {
          this.validateField(field);
        });
        
        field.addEventListener('input', () => {
          this.clearFieldError(field);
        });
      }
    });

    // Postal code formatting
    const zipInput = document.getElementById('checkout-zip');
    if (zipInput) {
      zipInput.addEventListener('input', (e) => {
        this.formatPostalCode(e.target);
      });
    }
  }

  handleAuthenticatedFlow() {
    console.log('🛒 Handling authenticated checkout flow');
    
    // Skip guest selection, go straight to form
    this.hideGuestSelection();
    this.showCheckoutForm();
    
    // Populate user data
    this.populateUserData(this.currentUser);
    
    // Update UI to show authenticated state
    this.updateAuthenticatedUI();
  }

  handleGuestFlow() {
    console.log('🛒 Handling guest checkout flow');
    
    // Show guest checkout options
    this.showGuestSelection();
    this.hideCheckoutForm();
    
    // Update UI to show guest state
    this.updateGuestUI();
  }

  handleAuthStateChange(user, previousUser) {
    if (user && !previousUser) {
      // User just signed in
      console.log('🛒 User signed in during checkout');
      this.handleAuthenticatedFlow();
      this.showMessage('Welcome! Your information has been filled in automatically.', 'success');
      
    } else if (!user && previousUser) {
      // User signed out
      console.log('🛒 User signed out during checkout');
      this.handleGuestFlow();
      this.clearUserData();
      this.showMessage('You have been signed out. Continue as guest or sign in again.', 'info');
    }
  }

  populateUserData(user) {
    console.log('🛒 Populating checkout form with user data');
    
    try {
      const userData = getUserDataForSwell();
      
      // Populate email (readonly for authenticated users)
      const emailInput = document.getElementById('checkout-email');
      if (emailInput) {
        emailInput.value = user.email;
        emailInput.setAttribute('readonly', 'true');
        emailInput.classList.add('bg-gray-50', 'cursor-not-allowed');
      }

      // Populate name fields if available
      if (userData) {
        const firstNameInput = document.getElementById('checkout-first-name');
        const lastNameInput = document.getElementById('checkout-last-name');
        
        if (firstNameInput && userData.first_name) {
          firstNameInput.value = userData.first_name;
        }
        
        if (lastNameInput && userData.last_name) {
          lastNameInput.value = userData.last_name;
        }

        // TODO: Populate address fields from user's previous orders or saved addresses
        this.loadUserAddresses(userData);
      }
      
    } catch (error) {
      console.error('🛒 Error populating user data:', error);
    }
  }

  async loadUserAddresses(userData) {
    // Try to load user's previous shipping addresses from Swell
    try {
      const swell = window.swell;
      if (swell && swell.account) {
        const account = await swell.account.get();
        if (account && account.shipping) {
          this.populateAddressFields(account.shipping);
        }
      }
    } catch (error) {
      console.log('🛒 Could not load saved addresses:', error);
    }
  }

  populateAddressFields(address) {
    if (!address) return;
    
    const fieldMappings = {
      'checkout-address1': address.address1,
      'checkout-address2': address.address2,
      'checkout-city': address.city,
      'checkout-zip': address.zip,
      'checkout-state': address.state,
      'checkout-country': address.country
    };

    Object.entries(fieldMappings).forEach(([fieldId, value]) => {
      const field = document.getElementById(fieldId);
      if (field && value && !field.value) {
        field.value = value;
      }
    });
  }

  clearUserData() {
    // Make email field editable again
    const emailInput = document.getElementById('checkout-email');
    if (emailInput) {
      emailInput.removeAttribute('readonly');
      emailInput.classList.remove('bg-gray-50', 'cursor-not-allowed');
      emailInput.value = '';
    }

    // Clear name fields
    const nameFields = ['checkout-first-name', 'checkout-last-name'];
    nameFields.forEach(fieldId => {
      const field = document.getElementById(fieldId);
      if (field) {
        field.value = '';
      }
    });
  }

  updateAuthenticatedUI() {
    const userInfo = document.getElementById('checkout-user-info');
    const guestInfo = document.getElementById('checkout-guest-info');
    
    if (userInfo && this.currentUser) {
      userInfo.innerHTML = `
        <div class="flex items-center space-x-2 text-sm text-green-600">
          <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"></path>
          </svg>
          <span>Signed in as ${this.currentUser.email}</span>
          <button onclick="window.checkoutHandler.signOut()" class="text-red-600 hover:text-red-800 underline">
            Sign out
          </button>
        </div>
      `;
      userInfo.classList.remove('hidden');
    }
    
    if (guestInfo) {
      guestInfo.classList.add('hidden');
    }
  }

  updateGuestUI() {
    const userInfo = document.getElementById('checkout-user-info');
    const guestInfo = document.getElementById('checkout-guest-info');
    
    if (userInfo) {
      userInfo.classList.add('hidden');
    }
    
    if (guestInfo) {
      guestInfo.classList.remove('hidden');
    }
  }

  continueAsGuest() {
    console.log('🛒 Continuing as guest');
    this.currentStep = 'form';
    
    this.hideGuestSelection();
    this.showCheckoutForm();
    
    // Focus on first form field
    const firstInput = document.querySelector('#checkout-form input:not([readonly])');
    if (firstInput) {
      firstInput.focus();
    }
  }

  async checkReturningCustomer(email) {
    if (!email || !this.isValidEmail(email)) {
      this.hideReturningCustomerPrompt();
      return;
    }

    console.log('🛒 Checking for returning customer:', email);
    
    // Show returning customer prompt
    this.showReturningCustomerPrompt(email);
  }

  showReturningCustomerPrompt(email) {
    const promptContainer = document.getElementById('returning-customer-prompt');
    if (!promptContainer) return;
    
    promptContainer.innerHTML = `
      <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 dark:bg-blue-900/20 dark:border-blue-800">
        <div class="flex items-center">
          <svg class="w-5 h-5 text-blue-600 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
          </svg>
          <div class="flex-1">
            <p class="text-sm text-blue-800 dark:text-blue-200">
              Have an account with <strong>${email}</strong>?
              <button 
                onclick="window.checkoutHandler.openAuthModal('signin')"
                class="font-medium underline hover:no-underline ml-1"
              >
                Sign in for faster checkout
              </button>
            </p>
          </div>
          <button 
            onclick="window.checkoutHandler.hideReturningCustomerPrompt()"
            class="text-blue-600 hover:text-blue-800 ml-2"
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
            </svg>
          </button>
        </div>
      </div>
    `;
    
    promptContainer.classList.remove('hidden');
  }

  hideReturningCustomerPrompt() {
    const promptContainer = document.getElementById('returning-customer-prompt');
    if (promptContainer) {
      promptContainer.classList.add('hidden');
    }
  }

  // UI State Management
  showGuestSelection() {
    const section = document.getElementById('guest-checkout-section');
    if (section) {
      section.classList.remove('hidden');
    }
  }

  hideGuestSelection() {
    const section = document.getElementById('guest-checkout-section');
    if (section) {
      section.classList.add('hidden');
    }
  }

  showCheckoutForm() {
    const container = document.getElementById('checkout-form-container');
    if (container) {
      container.classList.remove('hidden');
    }
  }

  hideCheckoutForm() {
    const container = document.getElementById('checkout-form-container');
    if (container) {
      container.classList.add('hidden');
    }
  }

  // Field Validation
  validateField(field) {
    if (!field) return true;
    
    const value = field.value.trim();
    const isRequired = field.hasAttribute('required');
    
    if (isRequired && !value) {
      this.showFieldError(field, 'This field is required');
      return false;
    }
    
    // Email validation
    if (field.type === 'email' && value && !this.isValidEmail(value)) {
      this.showFieldError(field, 'Please enter a valid email address');
      return false;
    }
    
    // Postal code validation by country
    if (field.id === 'checkout-zip' && value) {
      const country = document.getElementById('checkout-country')?.value;
      if (!this.isValidPostalCode(value, country)) {
        this.showFieldError(field, 'Please enter a valid postal code');
        return false;
      }
    }
    
    this.clearFieldError(field);
    return true;
  }

  showFieldError(field, message) {
    this.clearFieldError(field);
    
    field.classList.add('border-red-500', 'focus:border-red-500', 'focus:ring-red-500');
    
    const errorEl = document.createElement('div');
    errorEl.className = 'mt-1 text-sm text-red-600';
    errorEl.textContent = message;
    errorEl.setAttribute('data-field-error', field.id);
    
    field.parentNode.appendChild(errorEl);
  }

  clearFieldError(field) {
    field.classList.remove('border-red-500', 'focus:border-red-500', 'focus:ring-red-500');
    
    const existingError = field.parentNode.querySelector(`[data-field-error="${field.id}"]`);
    if (existingError) {
      existingError.remove();
    }
  }

  // Field Formatting
  formatPhoneNumber(input) {
    let value = input.value.replace(/\D/g, ''); // Remove non-digits
    
    // Format based on length (US format as default)
    if (value.length >= 6) {
      value = value.replace(/(\d{3})(\d{3})(\d{4})/, '($1) $2-$3');
    } else if (value.length >= 3) {
      value = value.replace(/(\d{3})(\d{0,3})/, '($1) $2');
    }
    
    input.value = value;
  }

  formatPostalCode(input) {
    const country = document.getElementById('checkout-country')?.value;
    let value = input.value.toUpperCase();
    
    // Format based on country
    switch (country) {
      case 'CA': // Canada: A1A 1A1
        value = value.replace(/[^A-Z0-9]/g, '');
        if (value.length > 3) {
          value = value.replace(/^([A-Z0-9]{3})([A-Z0-9]{3})$/, '$1 $2');
        }
        break;
      case 'GB': // UK: Similar to Canada
        value = value.replace(/[^A-Z0-9]/g, '');
        if (value.length > 4) {
          value = value.replace(/^([A-Z0-9]{3,4})([A-Z0-9]{3})$/, '$1 $2');
        }
        break;
      default: // Most countries: just remove special chars except spaces and dashes
        value = value.replace(/[^A-Z0-9\s-]/g, '');
    }
    
    input.value = value;
  }

  // Validation Helpers
  isValidEmail(email) {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
  }

  isValidPostalCode(code, country) {
    const patterns = {
      'US': /^\d{5}(-\d{4})?$/,
      'CA': /^[A-Z]\d[A-Z]\s?\d[A-Z]\d$/,
      'GB': /^[A-Z]{1,2}\d[A-Z\d]?\s?\d[A-Z]{2}$/,
      'DE': /^\d{5}$/,
      'FR': /^\d{5}$/,
      'IT': /^\d{5}$/,
      'ES': /^\d{5}$/,
      'NL': /^\d{4}\s?[A-Z]{2}$/,
      'BE': /^\d{4}$/,
      'AT': /^\d{4}$/,
      'CH': /^\d{4}$/
    };
    
    const pattern = patterns[country];
    return pattern ? pattern.test(code.toUpperCase()) : true; // Default to valid for unknown countries
  }

  // Auth Integration
  openAuthModal(mode = 'signin') {
    if (window.authHandler) {
      window.authHandler.openModal(mode);
    } else {
      // Fallback: dispatch custom event
      window.dispatchEvent(new CustomEvent('openAuthModal', { 
        detail: { mode } 
      }));
    }
  }

  signOut() {
    if (window.authStateManager) {
      window.authStateManager.signOut();
    }
  }

  // Messages
  showError(message) {
    const errorContainer = document.getElementById('checkout-error');
    if (errorContainer) {
      errorContainer.innerHTML = `
        <div class="bg-red-50 border border-red-200 rounded-lg p-4 text-sm text-red-800 dark:bg-red-900/20 dark:border-red-800 dark:text-red-200">
          <div class="flex items-center">
            <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
            </svg>
            ${message}
          </div>
        </div>
      `;
      errorContainer.classList.remove('hidden');
      
      // Scroll to error
      errorContainer.scrollIntoView({ behavior: 'smooth', block: 'center' });
    } else {
      console.error('🛒 Checkout error:', message);
    }
  }

  showMessage(text, type = 'info') {
    const messageContainer = document.getElementById('message-container');
    if (!messageContainer) return;
    
    const messageEl = document.createElement('div');
    messageEl.className = `p-4 rounded-md mb-4 ${
      type === 'error' ? 'bg-red-100 text-red-800' : 
      type === 'success' ? 'bg-green-100 text-green-800' : 
      'bg-blue-100 text-blue-800'
    }`;
    messageEl.textContent = text;
    
    messageContainer.appendChild(messageEl);
    
    // Auto-remove after 5 seconds
    setTimeout(() => {
      messageEl.remove();
    }, 5000);
  }

  // Public API
  getCurrentUser() {
    return this.currentUser;
  }

  isAuthenticated() {
    return !!this.currentUser;
  }

  getCurrentStep() {
    return this.currentStep;
  }

  getCheckoutData() {
    return this.checkoutData;
  }

  // Cleanup
  destroy() {
    if (this.authUnsubscribe) {
      this.authUnsubscribe();
    }
  }
}

// Initialize checkout handler
const checkoutHandler = new CheckoutHandler();

// Make available globally for debugging and integration
if (typeof window !== 'undefined') {
  window.checkoutHandler = checkoutHandler;
}

export default checkoutHandler;