// src/scripts/checkout-handler.js - Checkout authentication and cart integration
import authStateManager from '../lib/auth-state-manager.js';
import { getUserDataForSwell } from '../lib/firebase.js';

class CheckoutHandler {
  constructor() {
    this.currentUser = null;
    this.checkoutData = {};
    this.authUnsubscribe = null;
    this.isInitialized = false;
    this.init();
  }

  init() {
    console.log('🛒 Initializing checkout handler...');
    
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
           path.includes('/cart') || 
           path.includes('/order-summary') ||
           path.includes('/payment');
  }

  async setupCheckout() {
    console.log('🛒 Setting up checkout page...');
    
    this.setupAuthIntegration();
    this.setupEventListeners();
    
    // Wait for auth to be ready and initialize checkout
    try {
      const authState = await authStateManager.getAuthState();
      console.log('🛒 Checkout auth state ready:', authState.isAuthenticated ? 'Authenticated' : 'Guest');
      
      if (authState.isAuthenticated) {
        this.populateUserData(authState.user);
        this.hideGuestCheckoutPrompt();
      } else {
        this.showGuestCheckoutOptions();
      }
      
      this.isInitialized = true;
    } catch (error) {
      console.error('🛒 Error initializing checkout:', error);
      this.showError('Failed to initialize checkout. Please refresh the page.');
    }
  }

  setupAuthIntegration() {
    // Subscribe to auth state changes
    this.authUnsubscribe = authStateManager.subscribe((user) => {
      console.log('🛒 Checkout: Auth state changed:', user ? '✅ Authenticated' : '❌ Guest');
      this.currentUser = user;
      this.handleAuthStateChange(user);
    });
  }

  setupEventListeners() {
    // Sign in button in checkout
    const checkoutSignInBtn = document.getElementById('checkout-sign-in-btn');
    if (checkoutSignInBtn) {
      checkoutSignInBtn.addEventListener('click', () => {
        if (window.authHandler) {
          window.authHandler.openModal('signin');
        } else {
          // Fallback - dispatch custom event
          window.dispatchEvent(new CustomEvent('openAuthModal', { 
            detail: { mode: 'signin' } 
          }));
        }
      });
    }

    // Create account button
    const createAccountBtn = document.getElementById('checkout-create-account-btn');
    if (createAccountBtn) {
      createAccountBtn.addEventListener('click', () => {
        if (window.authHandler) {
          window.authHandler.openModal('signup');
        } else {
          window.dispatchEvent(new CustomEvent('openAuthModal', { 
            detail: { mode: 'signup' } 
          }));
        }
      });
    }

    // Continue as guest button
    const guestCheckoutBtn = document.getElementById('continue-as-guest-btn');
    if (guestCheckoutBtn) {
      guestCheckoutBtn.addEventListener('click', () => {
        this.continueAsGuest();
      });
    }

    // Email field change detection for returning customers
    const emailInput = document.getElementById('checkout-email');
    if (emailInput) {
      emailInput.addEventListener('blur', () => {
        this.checkReturningCustomer(emailInput.value);
      });
    }

    // Form submission handling
    const checkoutForm = document.getElementById('checkout-form');
    if (checkoutForm) {
      checkoutForm.addEventListener('submit', (e) => {
        this.handleCheckoutSubmission(e);
      });
    }

    // Address form auto-fill
    this.setupAddressAutofill();
  }

  handleAuthStateChange(user) {
    if (!this.isInitialized) {
      return; // Wait for initial setup
    }

    if (user) {
      // User signed in during checkout
      console.log('🛒 User signed in during checkout, updating form...');
      this.populateUserData(user);
      this.hideGuestCheckoutPrompt();
      this.showAuthenticatedCheckout();
    } else {
      // User signed out during checkout
      console.log('🛒 User signed out during checkout, switching to guest...');
      this.clearUserData();
      this.showGuestCheckoutOptions();
    }
  }

  populateUserData(user) {
    console.log('🛒 Populating checkout form with user data...');
    
    const userData = getUserDataForSwell();
    if (!userData) {
      console.warn('🛒 No user data available for Swell integration');
      return;
    }

    // Populate email field
    const emailInput = document.getElementById('checkout-email');
    if (emailInput && !emailInput.value) {
      emailInput.value = userData.email;
      emailInput.setAttribute('readonly', 'true');
      emailInput.classList.add('bg-gray-50', 'cursor-not-allowed');
    }

    // Populate name fields
    const firstNameInput = document.getElementById('checkout-first-name');
    const lastNameInput = document.getElementById('checkout-last-name');
    
    if (firstNameInput && !firstNameInput.value && userData.first_name) {
      firstNameInput.value = userData.first_name;
    }
    
    if (lastNameInput && !lastNameInput.value && userData.last_name) {
      lastNameInput.value = userData.last_name;
    }

    // Show authenticated user info
    this.updateCheckoutHeader(user);
  }

  clearUserData() {
    // Remove readonly attribute from email
    const emailInput = document.getElementById('checkout-email');
    if (emailInput) {
      emailInput.removeAttribute('readonly');
      emailInput.classList.remove('bg-gray-50', 'cursor-not-allowed');
    }

    // Clear user-specific UI
    this.updateCheckoutHeader(null);
  }

  updateCheckoutHeader(user) {
    const userInfo = document.getElementById('checkout-user-info');
    const guestInfo = document.getElementById('checkout-guest-info');
    
    if (user) {
      // Show authenticated user info
      if (userInfo) {
        userInfo.innerHTML = `
          <div class="flex items-center space-x-2 text-sm text-green-600">
            <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"></path>
            </svg>
            <span>Signed in as ${user.email}</span>
          </div>
        `;
        userInfo.classList.remove('hidden');
      }
      
      if (guestInfo) {
        guestInfo.classList.add('hidden');
      }
    } else {
      // Show guest checkout info
      if (userInfo) {
        userInfo.classList.add('hidden');
      }
      
      if (guestInfo) {
        guestInfo.classList.remove('hidden');
      }
    }
  }

  showGuestCheckoutOptions() {
    const guestSection = document.getElementById('guest-checkout-section');
    const authPrompt = document.getElementById('checkout-auth-prompt');
    
    if (guestSection) {
      guestSection.classList.remove('hidden');
    }
    
    if (authPrompt) {
      authPrompt.classList.remove('hidden');
    }
  }

  hideGuestCheckoutPrompt() {
    const authPrompt = document.getElementById('checkout-auth-prompt');
    if (authPrompt) {
      authPrompt.classList.add('hidden');
    }
  }

  showAuthenticatedCheckout() {
    const authenticatedSection = document.getElementById('authenticated-checkout-section');
    if (authenticatedSection) {
      authenticatedSection.classList.remove('hidden');
    }
  }

  continueAsGuest() {
    console.log('🛒 Continuing as guest checkout...');
    
    const guestSection = document.getElementById('guest-checkout-section');
    const checkoutForm = document.getElementById('checkout-form-container');
    
    if (guestSection) {
      guestSection.classList.add('hidden');
    }
    
    if (checkoutForm) {
      checkoutForm.classList.remove('hidden');
    }

    // Focus on first form field
    const firstInput = document.querySelector('#checkout-form input:not([readonly])');
    if (firstInput) {
      firstInput.focus();
    }
  }

  async checkReturningCustomer(email) {
    if (!email || !this.isValidEmail(email)) {
      return;
    }

    // Check if this email belongs to an existing user
    // This is a placeholder - you might want to implement this with your backend
    console.log('🛒 Checking if email belongs to returning customer:', email);
    
    const returningCustomerPrompt = document.getElementById('returning-customer-prompt');
    if (returningCustomerPrompt) {
      returningCustomerPrompt.innerHTML = `
        <div class="bg-blue-50 border border-blue-200 rounded-lg p-3 text-sm">
          <p class="text-blue-800">
            Have an account with this email? 
            <button id="sign-in-returning" class="font-medium text-blue-600 hover:text-blue-500 underline">
              Sign in for faster checkout
            </button>
          </p>
        </div>
      `;
      
      const signInBtn = returningCustomerPrompt.querySelector('#sign-in-returning');
      if (signInBtn) {
        signInBtn.addEventListener('click', () => {
          if (window.authHandler) {
            window.authHandler.openModal('signin');
          }
        });
      }
      
      returningCustomerPrompt.classList.remove('hidden');
    }
  }

  setupAddressAutofill() {
    // Setup address autofill from user's previous orders if authenticated
    if (this.currentUser) {
      // This could integrate with Swell to fetch user's address history
      console.log('🛒 Setting up address autofill for authenticated user');
    }
  }

  handleCheckoutSubmission(e) {
    console.log('🛒 Processing checkout submission...');
    
    // Add user authentication context to checkout data
    if (this.currentUser) {
      const userData = getUserDataForSwell();
      if (userData) {
        // Add Firebase UID and email verification status
        this.checkoutData.firebaseUid = userData.firebase_uid;
        this.checkoutData.emailVerified = userData.email_verified;
        this.checkoutData.isAuthenticated = true;
      }
    } else {
      this.checkoutData.isAuthenticated = false;
    }

    // Continue with normal checkout process
    console.log('🛒 Checkout data prepared:', this.checkoutData);
  }

  isValidEmail(email) {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
  }

  showError(message) {
    const errorContainer = document.getElementById('checkout-error');
    if (errorContainer) {
      errorContainer.innerHTML = `
        <div class="bg-red-50 border border-red-200 rounded-lg p-3 text-sm text-red-800">
          ${message}
        </div>
      `;
      errorContainer.classList.remove('hidden');
    } else {
      console.error('🛒 Checkout error:', message);
      alert(message); // Fallback
    }
  }

  // Public methods for external integration
  getCurrentUser() {
    return this.currentUser;
  }

  isAuthenticated() {
    return !!this.currentUser;
  }

  getCheckoutData() {
    return this.checkoutData;
  }

  // Cleanup method
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