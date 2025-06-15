// src/scripts/auth-handler.js - Main authentication handler with centralized state
import { 
  signIn, 
  signUp, 
  signOutUser, 
  resetPassword, 
  getUserDataForSwell
} from '../lib/firebase.js';
import authStateManager from '../lib/auth-state-manager.js';

class AuthHandler {
  constructor() {
    this.currentUser = null;
    this.authModal = null;
    this.currentForm = 'signin';
    this.authUnsubscribe = null;
    this.init();
  }

  init() {
    console.log('🔐 Initializing auth handler...');
    
    // Wait for DOM to be ready
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', () => this.setupDOM());
    } else {
      this.setupDOM();
    }

    // Subscribe to centralized auth state changes
    this.authUnsubscribe = authStateManager.subscribe((user) => {
      this.currentUser = user;
      this.updateAuthUI(user);
    });

    // Listen for custom events to open auth modal
    window.addEventListener('openAuthModal', (e) => {
      this.openModal(e.detail?.mode || 'signin');
    });
  }

  setupDOM() {
    // Get DOM elements
    this.authModal = document.getElementById('auth-modal');
    this.setupModalEventListeners();
    this.setupFormEventListeners();
    this.setupHeaderEventListeners();
  }

  setupModalEventListeners() {
    if (!this.authModal) return;

    // Open modal button
    const openModalBtn = document.getElementById('open-auth-modal');
    if (openModalBtn) {
      openModalBtn.addEventListener('click', () => this.openModal('signin'));
    }

    // Close modal buttons
    const closeModalBtn = document.getElementById('close-auth-modal');
    const backdrop = document.getElementById('auth-backdrop');
    
    if (closeModalBtn) {
      closeModalBtn.addEventListener('click', () => this.closeModal());
    }
    
    if (backdrop) {
      backdrop.addEventListener('click', () => this.closeModal());
    }

    // Form switching buttons
    const showSignupBtn = document.getElementById('show-signup');
    const showSigninBtn = document.getElementById('show-signin');
    const showResetBtn = document.getElementById('show-reset');
    const backToSigninBtn = document.getElementById('back-to-signin');

    if (showSignupBtn) {
      showSignupBtn.addEventListener('click', () => this.switchForm('signup'));
    }
    
    if (showSigninBtn) {
      showSigninBtn.addEventListener('click', () => this.switchForm('signin'));
    }
    
    if (showResetBtn) {
      showResetBtn.addEventListener('click', () => this.switchForm('reset'));
    }
    
    if (backToSigninBtn) {
      backToSigninBtn.addEventListener('click', () => this.switchForm('signin'));
    }

    // Escape key to close modal
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' && this.isModalOpen()) {
        this.closeModal();
      }
    });
  }

  setupFormEventListeners() {
    // Sign in form
    const signinForm = document.getElementById('signin-form');
    if (signinForm) {
      signinForm.addEventListener('submit', (e) => this.handleSignIn(e));
    }

    // Sign up form
    const signupForm = document.getElementById('signup-form');
    if (signupForm) {
      signupForm.addEventListener('submit', (e) => this.handleSignUp(e));
    }

    // Password reset form
    const resetForm = document.getElementById('reset-form');
    if (resetForm) {
      resetForm.addEventListener('submit', (e) => this.handlePasswordReset(e));
    }
  }

  setupHeaderEventListeners() {
    // Sign out button
    const signOutBtn = document.getElementById('sign-out-btn');
    if (signOutBtn) {
      signOutBtn.addEventListener('click', () => this.handleSignOut());
    }

    // User menu toggle
    const userMenuBtn = document.getElementById('user-menu-btn');
    const userMenu = document.getElementById('user-menu');
    
    if (userMenuBtn && userMenu) {
      userMenuBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        userMenu.classList.toggle('hidden');
      });

      // Close menu when clicking outside
      document.addEventListener('click', () => {
        userMenu.classList.add('hidden');
      });
    }
  }

  async handleSignIn(e) {
    e.preventDefault();
    
    const form = e.target;
    const email = form.email.value.trim();
    const password = form.password.value;
    const submitBtn = form.querySelector('button[type="submit"]');
    const errorDiv = document.getElementById('signin-error');

    if (!email || !password) {
      this.showError(errorDiv, 'Please fill in all fields');
      return;
    }

    this.setLoading(submitBtn, true);
    this.showError(errorDiv, '');

    try {
      const result = await signIn(email, password);
      
      if (result.success) {
        console.log('✅ Sign in successful');
        this.closeModal();
        form.reset();
        
        // Emit custom event for successful sign in
        window.dispatchEvent(new CustomEvent('userSignedIn', { 
          detail: { user: result.user } 
        }));
      } else {
        this.showError(errorDiv, result.error);
      }
    } catch (error) {
      console.error('Sign in error:', error);
      this.showError(errorDiv, 'An unexpected error occurred');
    } finally {
      this.setLoading(submitBtn, false);
    }
  }

  async handleSignUp(e) {
    e.preventDefault();
    
    const form = e.target;
    const email = form.email.value.trim();
    const password = form.password.value;
    const confirmPassword = form.confirmPassword.value;
    const displayName = form.displayName?.value.trim() || '';
    const submitBtn = form.querySelector('button[type="submit"]');
    const errorDiv = document.getElementById('signup-error');

    if (!email || !password || !confirmPassword) {
      this.showError(errorDiv, 'Please fill in all fields');
      return;
    }

    if (password !== confirmPassword) {
      this.showError(errorDiv, 'Passwords do not match');
      return;
    }

    if (password.length < 6) {
      this.showError(errorDiv, 'Password must be at least 6 characters long');
      return;
    }

    this.setLoading(submitBtn, true);
    this.showError(errorDiv, '');

    try {
      const result = await signUp(email, password, displayName);
      
      if (result.success) {
        console.log('✅ Sign up successful');
        this.closeModal();
        form.reset();
        
        // Emit custom event for successful sign up
        window.dispatchEvent(new CustomEvent('userSignedUp', { 
          detail: { user: result.user } 
        }));
      } else {
        this.showError(errorDiv, result.error);
      }
    } catch (error) {
      console.error('Sign up error:', error);
      this.showError(errorDiv, 'An unexpected error occurred');
    } finally {
      this.setLoading(submitBtn, false);
    }
  }

  async handlePasswordReset(e) {
    e.preventDefault();
    
    const form = e.target;
    const email = form.email.value.trim();
    const submitBtn = form.querySelector('button[type="submit"]');
    const errorDiv = document.getElementById('reset-error');
    const successDiv = document.getElementById('reset-success');

    if (!email) {
      this.showError(errorDiv, 'Please enter your email address');
      return;
    }

    this.setLoading(submitBtn, true);
    this.showError(errorDiv, '');
    this.showError(successDiv, '');

    try {
      const result = await resetPassword(email);
      
      if (result.success) {
        this.showError(successDiv, 'Password reset email sent! Check your inbox.');
        form.reset();
      } else {
        this.showError(errorDiv, result.error);
      }
    } catch (error) {
      console.error('Password reset error:', error);
      this.showError(errorDiv, 'An unexpected error occurred');
    } finally {
      this.setLoading(submitBtn, false);
    }
  }

  async handleSignOut() {
    try {
      console.log('🔐 Signing out...');
      const result = await signOutUser();
      
      if (result.success) {
        console.log('✅ Sign out successful');
        
        // Emit custom event for successful sign out
        window.dispatchEvent(new CustomEvent('userSignedOut'));
        
        // Redirect to home page if on protected page
        const protectedPaths = ['/orders', '/account'];
        if (protectedPaths.some(path => window.location.pathname.includes(path))) {
          window.location.href = '/';
        }
      } else {
        console.error('Sign out error:', result.error);
      }
    } catch (error) {
      console.error('Sign out error:', error);
    }
  }

  updateAuthUI(user) {
    // Update user menu
    const authButtons = document.getElementById('auth-buttons');
    const userMenu = document.getElementById('user-menu-container');
    const userNameDisplay = document.getElementById('user-name-display');

    if (user) {
      // User is signed in
      if (authButtons) authButtons.classList.add('hidden');
      if (userMenu) userMenu.classList.remove('hidden');
      
      if (userNameDisplay) {
        userNameDisplay.textContent = user.displayName || user.email.split('@')[0];
      }
      
      console.log('🔐 UI updated for authenticated user:', user.email);
    } else {
      // User is signed out
      if (authButtons) authButtons.classList.remove('hidden');
      if (userMenu) userMenu.classList.add('hidden');
      
      console.log('🔐 UI updated for non-authenticated state');
    }
  }

  openModal(formType = 'signin') {
    if (!this.authModal) return;
    
    this.currentForm = formType;
    this.switchForm(formType);
    
    this.authModal.classList.remove('hidden');
    this.authModal.classList.add('show');
    document.body.style.overflow = 'hidden';
    
    // Focus on first input
    setTimeout(() => {
      const firstInput = this.authModal.querySelector(`#${formType}-form input[type="email"]`);
      if (firstInput) firstInput.focus();
    }, 100);
  }

  closeModal() {
    if (!this.authModal) return;
    
    this.authModal.classList.remove('show');
    this.authModal.classList.add('hidden');
    document.body.style.overflow = '';
    
    // Clear all error messages
    const errorDivs = this.authModal.querySelectorAll('.error-message');
    errorDivs.forEach(div => div.textContent = '');
    
    // Reset all forms
    const forms = this.authModal.querySelectorAll('form');
    forms.forEach(form => form.reset());
  }

  switchForm(formType) {
    const forms = ['signin', 'signup', 'reset'];
    
    forms.forEach(type => {
      const form = document.getElementById(`${type}-form`);
      if (form) {
        if (type === formType) {
          form.classList.remove('hidden');
        } else {
          form.classList.add('hidden');
        }
      }
    });
    
    this.currentForm = formType;
  }

  isModalOpen() {
    return this.authModal && !this.authModal.classList.contains('hidden');
  }

  showError(errorDiv, message) {
    if (errorDiv) {
      errorDiv.textContent = message;
      errorDiv.style.display = message ? 'block' : 'none';
    }
  }

  setLoading(button, isLoading) {
    if (!button) return;
    
    if (isLoading) {
      button.disabled = true;
      button.dataset.originalText = button.textContent;
      button.textContent = 'Loading...';
    } else {
      button.disabled = false;
      if (button.dataset.originalText) {
        button.textContent = button.dataset.originalText;
      }
    }
  }

  // Public methods for external access
  getCurrentUser() {
    return this.currentUser;
  }

  isAuthenticated() {
    return !!this.currentUser;
  }

  async getAuthState() {
    return authStateManager.getAuthState();
  }

  // Cleanup method
  destroy() {
    if (this.authUnsubscribe) {
      this.authUnsubscribe();
    }
  }
}

// Initialize auth handler
const authHandler = new AuthHandler();

// Make available globally for backward compatibility
if (typeof window !== 'undefined') {
  window.authHandler = authHandler;
}

export default authHandler;