// src/lib/auth-state-manager.js - Centralized Authentication State Manager
import { onAuthStateChange, getCurrentUser, isAuthenticated } from './firebase.js';

class AuthStateManager {
  constructor() {
    this.currentUser = null;
    this.isReady = false;
    this.isInitialized = false;
    this.subscribers = new Set();
    
    // Promise that resolves when auth is ready
    this.readyPromise = new Promise((resolve) => {
      this.resolveReady = resolve;
    });
    
    this.init();
  }

  init() {
    console.log('🔐 Initializing centralized auth state manager...');
    
    // Listen to Firebase auth state changes
    onAuthStateChange((user) => {
      const wasReady = this.isReady;
      this.currentUser = user;
      this.isReady = true;
      
      // Mark as initialized and resolve ready promise on first auth check
      if (!this.isInitialized) {
        this.isInitialized = true;
        this.resolveReady();
        console.log('🔐 Auth state manager ready:', user ? '✅ Authenticated' : '❌ Not authenticated');
      }
      
      // Notify all subscribers
      this.notifySubscribers(user);
      
      // Emit custom event for backward compatibility
      window.dispatchEvent(new CustomEvent('authStateChanged', { 
        detail: { user, isAuthenticated: !!user } 
      }));
    });
  }

  /**
   * Subscribe to auth state changes
   * @param {Function} callback - Called when auth state changes
   * @returns {Function} Unsubscribe function
   */
  subscribe(callback) {
    this.subscribers.add(callback);
    
    // If auth is already ready, call immediately
    if (this.isReady) {
      try {
        callback(this.currentUser);
      } catch (error) {
        console.error('Error in auth state subscriber:', error);
      }
    }
    
    // Return unsubscribe function
    return () => {
      this.subscribers.delete(callback);
    };
  }

  /**
   * Wait for auth to be ready
   * @returns {Promise} Resolves when auth state is determined
   */
  async waitForReady() {
    return this.readyPromise;
  }

  /**
   * Get current user (synchronous)
   * @returns {Object|null} Current user or null
   */
  getCurrentUser() {
    return this.currentUser;
  }

  /**
   * Check if user is authenticated (synchronous)
   * @returns {boolean} True if authenticated
   */
  isAuthenticated() {
    return !!this.currentUser;
  }

  /**
   * Get auth state safely (async - waits for ready)
   * @returns {Promise<Object>} Auth state with user and isAuthenticated
   */
  async getAuthState() {
    await this.waitForReady();
    return {
      user: this.currentUser,
      isAuthenticated: this.isAuthenticated(),
      isReady: this.isReady
    };
  }

  /**
   * Notify all subscribers of auth state change
   * @param {Object|null} user - Current user
   */
  notifySubscribers(user) {
    this.subscribers.forEach(callback => {
      try {
        callback(user);
      } catch (error) {
        console.error('Error in auth state subscriber:', error);
      }
    });
  }

  /**
   * Debug method to check current state
   */
  debug() {
    console.log('🔐 Auth State Debug:', {
      isReady: this.isReady,
      isInitialized: this.isInitialized,
      currentUser: this.currentUser,
      subscriberCount: this.subscribers.size,
      isAuthenticated: this.isAuthenticated()
    });
  }
}

// Create singleton instance
const authStateManager = new AuthStateManager();

// Make globally available
if (typeof window !== 'undefined') {
  window.authState = authStateManager;
}

export default authStateManager;