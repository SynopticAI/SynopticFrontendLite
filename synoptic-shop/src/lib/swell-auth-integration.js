// src/lib/swell-auth-integration.js - Fixed Firebase to Swell Authentication Bridge
import { swell } from './swell.js';
import authStateManager from './auth-state-manager.js';

class SwellAuthIntegration {
  constructor() {
    this.isAuthenticating = false;
    this.authPromise = null;
    this.init();
  }

  init() {
    console.log('🔗 Initializing Swell authentication integration...');
    
    // Subscribe to centralized auth state changes
    authStateManager.subscribe((user) => {
      this.handleFirebaseAuthChange(user);
    });
  }

  async handleFirebaseAuthChange(firebaseUser) {
    if (firebaseUser && !this.isAuthenticating) {
      // User signed in with Firebase - authenticate with Swell
      console.log('🔗 Firebase user signed in, authenticating with Swell...');
      await this.authenticateWithSwell(firebaseUser);
    } else if (!firebaseUser) {
      // User signed out - sign out from Swell
      console.log('🔗 Firebase user signed out, signing out from Swell...');
      await this.signOutFromSwell();
    }
  }

  async authenticateWithSwell(firebaseUser) {
    if (this.isAuthenticating) {
      return this.authPromise;
    }

    this.isAuthenticating = true;
    
    this.authPromise = this._performSwellAuth(firebaseUser);
    
    try {
      const result = await this.authPromise;
      return result;
    } finally {
      this.isAuthenticating = false;
      this.authPromise = null;
    }
  }

  async _performSwellAuth(firebaseUser) {
    try {
      console.log('🔗 Authenticating with Swell for:', firebaseUser.email);
      
      // Create a consistent password using Firebase UID
      const password = `firebase_${firebaseUser.uid}`;
      
      // Step 1: Try to login with existing account
      try {
        const loginResult = await swell.account.login({
          email: firebaseUser.email,
          password: password
        });

        if (loginResult) {
          console.log('✅ Successfully logged into existing Swell account');
          return { success: true, account: loginResult, error: null };
        }
      } catch (loginError) {
        console.log('🔗 No existing account found, creating new one...');
      }

      // Step 2: Create new account if login failed
      try {
        const createResult = await swell.account.create({
          email: firebaseUser.email,
          password: password,
          first_name: firebaseUser.displayName?.split(' ')[0] || '',
          last_name: firebaseUser.displayName?.split(' ').slice(1).join(' ') || '',
          email_verified: firebaseUser.emailVerified
        });

        if (createResult) {
          console.log('✅ Successfully created and logged into new Swell account');
          return { success: true, account: createResult, error: null };
        }
      } catch (createError) {
        console.log('🔗 Account creation failed, trying alternative login...');
        
        // Step 3: Try alternative authentication methods
        try {
          // Try login with just email (in case account exists with different password)
          const account = await swell.account.login({
            email: firebaseUser.email,
            password: firebaseUser.email // Fallback password
          });

          if (account) {
            console.log('✅ Successfully logged in with alternative method');
            return { success: true, account, error: null };
          }
        } catch (altError) {
          console.log('🔗 All authentication methods failed');
        }
      }

      throw new Error('Failed to authenticate with Swell using any method');
      
    } catch (error) {
      console.error('❌ Swell authentication failed:', error);
      return { success: false, account: null, error: error.message };
    }
  }

  async signOutFromSwell() {
    try {
      console.log('🔗 Signing out from Swell...');
      
      await swell.account.logout();
      console.log('✅ Signed out from Swell');
      
    } catch (error) {
      console.error('🔗 Error signing out from Swell:', error);
    }
  }

  // Public method to manually trigger Swell auth
  async forceSwellAuthentication() {
    const firebaseUser = authStateManager.getCurrentUser();
    if (firebaseUser) {
      return await this.authenticateWithSwell(firebaseUser);
    } else {
      throw new Error('No Firebase user found');
    }
  }

  // Public method to check if Swell is authenticated
  async isSwellAuthenticated() {
    try {
      const account = await swell.account.get();
      return !!account && !!account.id;
    } catch (error) {
      return false;
    }
  }

  // Get current Swell account
  async getCurrentSwellAccount() {
    try {
      return await swell.account.get();
    } catch (error) {
      return null;
    }
  }

  // Debug method
  async debug() {
    const firebaseUser = authStateManager.getCurrentUser();
    const isSwellAuth = await this.isSwellAuthenticated();
    const swellAccount = await this.getCurrentSwellAccount();
    
    console.log('🔗 Swell Auth Integration Debug:', {
      firebaseUser: firebaseUser?.email || 'None',
      isSwellAuthenticated: isSwellAuth,
      isAuthenticating: this.isAuthenticating,
      swellAccount: swellAccount ? {
        id: swellAccount.id,
        email: swellAccount.email,
        name: swellAccount.name
      } : 'None'
    });
  }
}

// Create singleton instance
const swellAuthIntegration = new SwellAuthIntegration();

// Make globally available for debugging
if (typeof window !== 'undefined') {
  window.swellAuthIntegration = swellAuthIntegration;
}

export default swellAuthIntegration;