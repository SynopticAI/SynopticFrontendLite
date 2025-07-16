// src/lib/swell-auth-integration.js - FIXED: Remove cart.create() which doesn't exist
import swell from 'swell-js';
import authStateManager from './auth-state-manager.js';

class SwellAuthIntegration {
  constructor() {
    this.isAuthenticating = false;
    this.currentSwellAccount = null;
    this.authRetryCount = 0;
    this.maxRetries = 3;
    this.init();
  }

  init() {
    console.log('🔗 Initializing Swell auth integration...');
    
    // Subscribe to Firebase auth state changes
    authStateManager.subscribe((firebaseUser) => {
      if (firebaseUser && !this.isAuthenticating) {
        console.log('🔗 Firebase user authenticated, starting Swell integration...');
        this.authenticateWithSwell(firebaseUser);
      } else if (!firebaseUser) {
        console.log('🔗 Firebase user signed out, clearing Swell auth...');
        this.signOutFromSwell();
      }
    });
  }

  async authenticateWithSwell(firebaseUser) {
    if (this.isAuthenticating) {
      console.log('🔗 Already authenticating, skipping...');
      return;
    }

    this.isAuthenticating = true;
    console.log('🔗 Starting Swell authentication for:', firebaseUser.email);
    
    try {
      // Step 1: Verify Swell is properly initialized
      await this.ensureSwellInitialized();
      
      // Step 2: Check current Swell auth state
      const currentAccount = await this.getCurrentSwellAccount();
      if (currentAccount && currentAccount.email === firebaseUser.email) {
        console.log('✅ Already authenticated with matching Swell account');
        this.currentSwellAccount = currentAccount;
        
        // Still ensure cart is associated
        await this.ensureCartAssociation();
        return { success: true, account: currentAccount, error: null };
      }

      // Step 3: Try to authenticate or create account
      const result = await this.performSwellAuthentication(firebaseUser);
      
      if (result.success) {
        this.currentSwellAccount = result.account;
        this.authRetryCount = 0;
        console.log('✅ Swell authentication successful');
        
        // Step 4: CRITICAL - Associate cart with the authenticated account
        await this.ensureCartAssociation();
        
        // Step 5: Notify cart manager that auth is complete
        window.dispatchEvent(new CustomEvent('swellAuthComplete', { 
          detail: { account: result.account } 
        }));
        
      } else {
        console.error('❌ Swell authentication failed:', result.error);
        
        // Retry logic
        if (this.authRetryCount < this.maxRetries) {
          this.authRetryCount++;
          console.log(`🔄 Retrying Swell auth (${this.authRetryCount}/${this.maxRetries})...`);
          setTimeout(() => {
            this.isAuthenticating = false;
            this.authenticateWithSwell(firebaseUser);
          }, 2000 * this.authRetryCount);
          return;
        }
      }
      
      return result;
      
    } catch (error) {
      console.error('❌ Swell authentication error:', error);
      return { success: false, account: null, error: error.message };
    } finally {
      this.isAuthenticating = false;
    }
  }

  // 🔧 FIXED: Remove cart.create() call and handle cart association properly
  async ensureCartAssociation() {
    try {
      console.log('🛒 Ensuring cart is associated with authenticated account...');
      
      // Get current cart (may be null if no cart exists yet)
      let cart = await swell.cart.get();
      
      // 🔧 FIXED: Don't try to create cart manually - Swell creates carts automatically
      if (!cart) {
        console.log('🛒 No cart found - cart will be created automatically when first item is added');
        return { success: true, cart: null, message: 'No cart exists yet, will be created on first add' };
      }
      
      // Check if cart is already associated with account
      const currentAccount = await this.getCurrentSwellAccount();
      if (!currentAccount) {
        console.log('🛒 No authenticated account found, skipping cart association');
        return { success: false, error: 'No authenticated account' };
      }
      
      if (cart.account_id === currentAccount.id) {
        console.log('✅ Cart already associated with account');
        return { success: true, cart };
      }
      
      console.log('🛒 Associating existing cart with authenticated account...');
      
      // Force cart to be associated with the authenticated account
      const updatedCart = await swell.cart.update({
        account_id: currentAccount.id
      });
      
      if (updatedCart && updatedCart.account_id) {
        console.log('✅ Cart successfully associated with account:', updatedCart.account_id);
        return { success: true, cart: updatedCart };
      } else {
        console.warn('⚠️ Cart association may not have worked as expected');
        return { success: false, cart: updatedCart };
      }
      
    } catch (error) {
      console.error('❌ Error associating cart with account:', error);
      
      // If the error is about cart not existing, that's actually fine
      if (error.message?.includes('cart') && error.message?.includes('not found')) {
        console.log('🛒 No cart exists yet - this is normal, cart will be created when items are added');
        return { success: true, cart: null, message: 'No cart exists yet' };
      }
      
      return { success: false, error: error.message };
    }
  }

  async ensureSwellInitialized() {
    console.log('🔗 Checking Swell initialization...');
    
    // Wait for Swell to be available
    let attempts = 0;
    while (attempts < 50) { // 5 seconds max
      if (typeof swell !== 'undefined' && swell.init) {
        break;
      }
      await new Promise(resolve => setTimeout(resolve, 100));
      attempts++;
    }
    
    if (typeof swell === 'undefined' || !swell.init) {
      throw new Error('Swell SDK not loaded');
    }
    
    if (!swell.account) {
      throw new Error('Swell account API not available');
    }
  }

  async performSwellAuthentication(firebaseUser) {
    const password = `firebase_${firebaseUser.uid}`;
    const email = firebaseUser.email;
    
    console.log('🔗 Performing Swell authentication for:', email);
    
    // Method 1: Try existing account login
    console.log('🔗 Method 1: Attempting login with Firebase UID password...');
    try {
      const loginResult = await swell.account.login({
        email: email,
        password: password
      });

      if (loginResult && loginResult.id) {
        console.log('✅ Successfully logged into existing Swell account');
        return { success: true, account: loginResult, error: null };
      }
    } catch (loginError) {
      console.log('🔗 Login failed:', loginError.message);
    }

    // Method 2: Try to create new account (FIXED - removed email_verified)
    console.log('🔗 Method 2: Attempting account creation...');
    try {
      const createData = {
        email: email,
        password: password,
        first_name: firebaseUser.displayName?.split(' ')[0] || '',
        last_name: firebaseUser.displayName?.split(' ').slice(1).join(' ') || ''
        // ✅ Removed email_verified field - not allowed from frontend
      };
      
      console.log('🔗 Creating account with data:', {
        ...createData,
        password: '[REDACTED]'
      });
      
      const createResult = await swell.account.create(createData);

      if (createResult && createResult.id) {
        console.log('✅ Successfully created and logged into new Swell account');
        return { success: true, account: createResult, error: null };
      }
    } catch (createError) {
      console.log('🔗 Account creation failed:', createError.message);
      this.logSwellError('account.create', createError);
      
      // If creation failed, account might exist with different password
      // Try login with email as password (common fallback)
      console.log('🔗 Method 3: Attempting fallback login with email as password...');
      try {
        const fallbackResult = await swell.account.login({
          email: email,
          password: email
        });

        if (fallbackResult && fallbackResult.id) {
          console.log('✅ Successfully logged in with fallback method');
          return { success: true, account: fallbackResult, error: null };
        }
      } catch (fallbackError) {
        console.log('🔗 Fallback login failed:', fallbackError.message);
      }
    }

    // Method 3: Try guest checkout association (cart-only approach)
    console.log('🔗 Method 3: Attempting guest checkout association...');
    try {
      // Set cart customer info without creating account
      const cart = await swell.cart.update({
        account: {
          email: email
          // Remove first_name and last_name - they're restricted from frontend updates
        }
      });

      if (cart && cart.account?.email === email) {
        console.log('✅ Successfully associated cart with user info (guest mode)');
        return { 
          success: true, 
          account: { 
            id: 'guest_' + firebaseUser.uid,
            email: email,
            guest: true 
          }, 
          error: null 
        };
      }
    } catch (cartError) {
      console.log('🔗 Cart association failed:', cartError.message);
    }

    // All methods failed
    const errorMessage = 'All Swell authentication methods failed';
    console.error('❌', errorMessage);
    return { success: false, account: null, error: errorMessage };
  }

  logSwellError(method, error) {
    console.error(`🔗 Swell ${method} error details:`, {
      message: error.message,
      status: error.status,
      statusText: error.statusText,
      response: error.response
    });
    
    // Check for specific error patterns
    if (error.message?.includes('forbidden') || error.status === 403) {
      console.error('🚨 PERMISSION ERROR: This operation might be restricted');
    }
    
    if (error.message?.includes('not found') || error.status === 404) {
      console.error('🚨 API ERROR: This endpoint might not exist');
    }
    
    if (error.message?.includes('validation') || error.status === 400) {
      console.error('🚨 VALIDATION ERROR: Check required fields and data format');
    }

    if (error.message?.includes('email_verified')) {
      console.error('🚨 FIELD RESTRICTION: email_verified cannot be set from frontend');
    }
  }

  async signOutFromSwell() {
    try {
      console.log('🔗 Signing out from Swell...');
      
      if (swell.account?.logout) {
        await swell.account.logout();
      }
      
      this.currentSwellAccount = null;
      console.log('✅ Signed out from Swell');
      
    } catch (error) {
      console.error('🔗 Error signing out from Swell:', error);
    }
  }

  // Public methods for external access
  async forceSwellAuthentication() {
    const firebaseUser = authStateManager.getCurrentUser();
    if (firebaseUser) {
      this.authRetryCount = 0; // Reset retry count
      return await this.authenticateWithSwell(firebaseUser);
    } else {
      throw new Error('No Firebase user found');
    }
  }

  async forceCartAssociation() {
    return await this.ensureCartAssociation();
  }

  async isSwellAuthenticated() {
    try {
      const account = await swell.account.get();
      return !!account && !!account.id && !account.guest;
    } catch (error) {
      return false;
    }
  }

  async getCurrentSwellAccount() {
    try {
      return await swell.account.get();
    } catch (error) {
      console.log('🔗 Unable to get current Swell account:', error.message);
      return null;
    }
  }

  // Comprehensive debug method
  async debug() {
    const firebaseUser = authStateManager.getCurrentUser();
    const isSwellAuth = await this.isSwellAuthenticated();
    const swellAccount = await this.getCurrentSwellAccount();
    const cart = await swell.cart.get();
    
    console.group('🔗 Swell Auth Integration Debug');
    console.log('Firebase User:', firebaseUser?.email || 'None');
    console.log('Is Authenticating:', this.isAuthenticating);
    console.log('Retry Count:', this.authRetryCount);
    console.log('Is Swell Authenticated:', isSwellAuth);
    console.log('Current Swell Account:', swellAccount ? {
      id: swellAccount.id,
      email: swellAccount.email,
      name: swellAccount.name || `${swellAccount.first_name} ${swellAccount.last_name}`,
      guest: swellAccount.guest || false
    } : 'None');
    
    console.log('Cart Status:', cart ? {
      id: cart.id,
      account_id: cart.account_id,
      account_email: cart.account?.email,
      item_count: cart.items?.length || 0,
      is_associated: !!cart.account_id
    } : 'No cart');
    
    // Test Swell API availability
    console.log('Swell API Status:', {
      swellLoaded: typeof swell !== 'undefined',
      hasAccount: !!swell?.account,
      hasAccountMethods: {
        get: !!(swell?.account?.get),
        login: !!(swell?.account?.login),
        create: !!(swell?.account?.create),
        logout: !!(swell?.account?.logout)
      },
      hasCart: !!swell?.cart,
      hasCartMethods: {
        get: !!(swell?.cart?.get),
        update: !!(swell?.cart?.update),
        addItem: !!(swell?.cart?.addItem),
        // Note: cart.create does NOT exist in Swell API
        create: !!(swell?.cart?.create)  // This should be false
      }
    });
    console.groupEnd();
  }

  // Force reset auth state
  reset() {
    this.isAuthenticating = false;
    this.currentSwellAccount = null;
    this.authRetryCount = 0;
    console.log('🔗 Swell auth integration reset');
  }
}

// Create singleton instance
const swellAuthIntegration = new SwellAuthIntegration();

// Make globally available for debugging
if (typeof window !== 'undefined') {
  window.swellAuthIntegration = swellAuthIntegration;
}

export default swellAuthIntegration;