// src/lib/auth-manager.js - Centralized authentication state management
import { 
  onAuthStateChanged,
  getCurrentUser,
  isAuthenticated,
  signIn,
  signUp,
  signOutUser,
  resetPassword,
  getUserDataForSwell,
  auth
} from './firebase.js';

class AuthManager {
  constructor() {
    this.currentUser = null;
    this.authInitialized = false;
    this.subscribers = new Set();
    this.initPromise = null;
    
    // Start initialization immediately
    this.init();
  }

  async init() {
    if (this.initPromise) {
      return this.initPromise;
    }

    this.initPromise = new Promise((resolve) => {
      console.log('🔐 Initializing AuthManager...');
      
      // Wait for Firebase Auth to be ready
      const checkAuth = () => {
        if (auth) {
          console.log('🔥 Firebase Auth available, setting up state listener');
          
          // Set up auth state listener
          onAuthStateChanged(auth, (user) => {
            console.log('🔄 Auth state changed:', user ? user.email : 'signed out');
            this.currentUser = user;
            
            if (!this.authInitialized) {
              this.authInitialized = true;
              console.log('✅ AuthManager initialized with user:', user ? user.email : 'none');
              resolve();
            }
            
            // Notify all subscribers
            this.notifySubscribers(user);
          });
          
          // Also check current user immediately
          const currentUser = getCurrentUser();
          if (currentUser && !this.currentUser) {
            console.log('📱 Found existing user:', currentUser.email);
            this.currentUser = currentUser;
            this.notifySubscribers(currentUser);
          }
          
        } else {
          console.log('⏳ Waiting for Firebase Auth...');
          setTimeout(checkAuth, 100);
        }
      };
      
      checkAuth();
      
      // Fallback timeout
      setTimeout(() => {
        if (!this.authInitialized) {
          console.log('⚠️ AuthManager timeout, resolving anyway');
          this.authInitialized = true;
          resolve();
        }
      }, 5000);
    });

    return this.initPromise;
  }

  /**
   * Subscribe to auth state changes
   * @param {Function} callback - Callback function
   * @returns {Function} Unsubscribe function
   */
  subscribe(callback) {
    this.subscribers.add(callback);
    
    // If already initialized, call immediately
    if (this.authInitialized) {
      try {
        callback(this.currentUser);
      } catch (error) {
        console.error('Error in auth subscriber callback:', error);
      }
    }
    
    // Return unsubscribe function
    return () => {
      this.subscribers.delete(callback);
    };
  }

  /**
   * Notify all subscribers of auth state changes
   */
  notifySubscribers(user) {
    this.subscribers.forEach(callback => {
      try {
        callback(user);
      } catch (error) {
        console.error('Error in auth state callback:', error);
      }
    });
  }

  /**
   * Get current user
   * @returns {Object|null} Current user or null
   */
  getCurrentUser() {
    return this.currentUser;
  }

  /**
   * Check if user is authenticated
   * @returns {boolean} True if user is authenticated
   */
  isAuthenticated() {
    return this.currentUser !== null;
  }

  /**
   * Wait for auth to be initialized
   * @returns {Promise} Promise that resolves when auth is ready
   */
  async waitForAuth() {
    await this.init();
    return this.currentUser;
  }

  /**
   * Get user data formatted for Swell
   * @returns {Object|null} User data for Swell
   */
  getUserDataForSwell() {
    return getUserDataForSwell();
  }

  /**
   * Sign in with email and password
   * @param {string} email - User email
   * @param {string} password - User password
   * @returns {Promise<Object>} Sign in result
   */
  async signIn(email, password) {
    return await signIn(email, password);
  }

  /**
   * Sign up with email and password
   * @param {string} email - User email
   * @param {string} password - User password
   * @param {string} displayName - User display name
   * @returns {Promise<Object>} Sign up result
   */
  async signUp(email, password, displayName) {
    return await signUp(email, password, displayName);
  }

  /**
   * Sign out current user
   * @returns {Promise<Object>} Sign out result
   */
  async signOut() {
    return await signOutUser();
  }

  /**
   * Reset password
   * @param {string} email - User email
   * @returns {Promise<Object>} Reset result
   */
  async resetPassword(email) {
    return await resetPassword(email);
  }

  /**
   * Require authentication for a function
   * @param {Function} callback - Function to execute after auth
   * @param {Function} onSignIn - Optional callback for sign in prompt
   */
  requireAuth(callback, onSignIn = null) {
    if (this.isAuthenticated()) {
      callback(this.currentUser);
    } else {
      console.log('🔐 Authentication required');
      
      if (onSignIn) {
        onSignIn();
      } else {
        // Try to open auth modal if available
        this.openAuthModal();
      }
      
      // Listen for successful auth
      const unsubscribe = this.subscribe((user) => {
        if (user) {
          callback(user);
          unsubscribe();
        }
      });
    }
  }

  /**
   * Open authentication modal
   */
  openAuthModal(mode = 'signin') {
    // Try multiple methods to open auth modal
    if (window.authHandler && window.authHandler.openModal) {
      window.authHandler.openModal(mode);
    } else if (document.getElementById('open-auth-modal')) {
      document.getElementById('open-auth-modal').click();
    } else {
      console.error('No auth modal available');
      alert('Please sign in to continue. Refresh the page if you encounter issues.');
    }
  }

  /**
   * Get debug info
   * @returns {Object} Debug information
   */
  getDebugInfo() {
    return {
      currentUser: this.currentUser ? {
        email: this.currentUser.email,
        uid: this.currentUser.uid,
        displayName: this.currentUser.displayName
      } : null,
      authInitialized: this.authInitialized,
      subscriberCount: this.subscribers.size,
      firebaseAuth: !!auth,
      firebaseCurrentUser: auth ? !!auth.currentUser : false
    };
  }
}

// Create singleton instance
const authManager = new AuthManager();

// Make available globally for debugging and compatibility
if (typeof window !== 'undefined') {
  window.authManager = authManager;
  
  // Also maintain compatibility with existing authHandler access
  window.getAuthManager = () => authManager;
}

export default authManager;