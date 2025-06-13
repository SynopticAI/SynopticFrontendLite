// src/scripts/auth-handler.js - Main authentication handler
import { 
  signIn, 
  signUp, 
  signOutUser, 
  resetPassword, 
  onAuthStateChange, 
  getUserDataForSwell
} from '../lib/firebase.js';

class AuthHandler {
  constructor() {
    this.currentUser = null;
    this.authModal = null;
    this.currentForm = 'signin';
    this.init();
  }

  init() {
    // Wait for DOM to be ready
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', () => this.setupDOM());
    } else {
      this.setupDOM();
    }

    // Listen to auth state changes
    onAuthStateChange((user) => {
      this.currentUser = user;
      this.updateAuthUI(user);
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

    // ESC key to close modal
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' && !this.authModal.classList.contains('hidden')) {
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

    // Reset form
    const resetForm = document.getElementById('reset-form');
    if (resetForm) {
      resetForm.addEventListener('submit', (e) => this.handleResetPassword(e));
    }
  }

  setupHeaderEventListeners() {
    // Sign out button
    const signoutBtn = document.getElementById('signout-button');
    if (signoutBtn) {
      signoutBtn.addEventListener('click', () => this.handleSignOut());
    }

    // Cart button (placeholder for future cart integration)
    const cartBtn = document.getElementById('cart-button');
    if (cartBtn) {
      cartBtn.addEventListener('click', () => {
        console.log('Cart clicked - integration coming soon');
        // Future cart functionality
      });
    }
  }

  openModal(formType = 'signin') {
    if (!this.authModal) return;
    
    this.currentForm = formType;
    this.switchForm(formType);
    this.clearMessages();
    this.authModal.classList.remove('hidden');
    document.body.style.overflow = 'hidden';
    
    // Focus first input
    setTimeout(() => {
      const firstInput = this.authModal.querySelector(`#${formType}-form input`);
      if (firstInput) firstInput.focus();
    }, 100);
  }

  closeModal() {
    if (!this.authModal) return;
    
    this.authModal.classList.add('hidden');
    document.body.style.overflow = '';
    this.clearForms();
    this.clearMessages();
  }

  switchForm(formType) {
    this.currentForm = formType;
    
    // Hide all forms
    const forms = ['signin', 'signup', 'reset'];
    forms.forEach(form => {
      const formEl = document.getElementById(`${form}-form`);
      const footerEl = document.getElementById(`${form}-footer`);
      
      if (formEl) formEl.classList.add('hidden');
      if (footerEl) footerEl.classList.add('hidden');
    });

    // Show current form
    const currentFormEl = document.getElementById(`${formType}-form`);
    const currentFooterEl = document.getElementById(`${formType}-footer`);
    
    if (currentFormEl) currentFormEl.classList.remove('hidden');
    if (currentFooterEl) currentFooterEl.classList.remove('hidden');

    // Update modal title
    const modalTitle = document.getElementById('auth-modal-title');
    if (modalTitle) {
      const titles = {
        signin: 'Sign In',
        signup: 'Create Account',
        reset: 'Reset Password'
      };
      modalTitle.textContent = titles[formType] || 'Authentication';
    }

    this.clearMessages();
  }

  async handleSignIn(event) {
    event.preventDefault();
    
    const form = event.target;
    const formData = new FormData(form);
    const email = formData.get('email');
    const password = formData.get('password');

    this.setFormLoading('signin', true);
    this.clearMessages();

    try {
      const result = await signIn(email, password);
      
      if (result.success) {
        this.showSuccess('Successfully signed in!');
        setTimeout(() => this.closeModal(), 1500);
      } else {
        this.showError(result.error);
      }
    } catch (error) {
      this.showError(error);
    } finally {
      this.setFormLoading('signin', false);
    }
  }

  async handleSignUp(event) {
    event.preventDefault();
    
    const form = event.target;
    const formData = new FormData(form);
    const name = formData.get('name');
    const email = formData.get('email');
    const password = formData.get('password');
    const confirmPassword = formData.get('confirmPassword');

    // Validate passwords match
    if (password !== confirmPassword) {
      this.showError('Passwords do not match.');
      return;
    }

    this.setFormLoading('signup', true);
    this.clearMessages();

    try {
      const result = await signUp(email, password, name);
      
      if (result.success) {
        this.showSuccess('Account created successfully!');
        setTimeout(() => this.closeModal(), 1500);
      } else {
        this.showError(result.error);
      }
    } catch (error) {
      this.showError(error);
    } finally {
      this.setFormLoading('signup', false);
    }
  }

  async handleResetPassword(event) {
    event.preventDefault();
    
    const form = event.target;
    const formData = new FormData(form);
    const email = formData.get('email');

    this.setFormLoading('reset', true);
    this.clearMessages();

    try {
      const result = await resetPassword(email);
      
      if (result.success) {
        this.showSuccess('Password reset email sent! Check your inbox.');
        setTimeout(() => this.switchForm('signin'), 2000);
      } else {
        this.showError(result.error);
      }
    } catch (error) {
      this.showError(error);
    } finally {
      this.setFormLoading('reset', false);
    }
  }

  async handleSignOut() {
    try {
      const result = await signOutUser();
      
      if (result.success) {
        // Redirect to home page after sign out
        window.location.href = '/';
      } else {
        console.error('Sign out error:', result.error);
      }
    } catch (error) {
      console.error('Sign out error:', error);
    }
  }

  updateAuthUI(user) {
    // Update loading state
    this.hideElement('auth-loading');
    
    if (user) {
      // User is authenticated
      this.showElement('auth-authenticated');
      this.hideElement('auth-not-authenticated');
      
      // Update user info
      this.updateUserInfo(user);
    } else {
      // User is not authenticated
      this.showElement('auth-not-authenticated');
      this.hideElement('auth-authenticated');
    }
  }

  updateUserInfo(user) {
    // User avatar and name
    const avatarText = document.getElementById('user-avatar-text');
    const displayName = document.getElementById('user-display-name');
    const dropdownName = document.getElementById('dropdown-user-name');
    const dropdownEmail = document.getElementById('dropdown-user-email');

    const name = user.displayName || user.email.split('@')[0];
    const initials = this.getInitials(name);

    if (avatarText) avatarText.textContent = initials;
    if (displayName) displayName.textContent = name;
    if (dropdownName) dropdownName.textContent = name;
    if (dropdownEmail) dropdownEmail.textContent = user.email;
  }

  getInitials(name) {
    return name
      .split(' ')
      .map(part => part.charAt(0).toUpperCase())
      .slice(0, 2)
      .join('');
  }

  setFormLoading(formType, loading) {
    const submitBtn = document.getElementById(`${formType}-submit`);
    const textSpan = submitBtn?.querySelector(`.${formType}-text`);
    const loadingSpan = submitBtn?.querySelector(`.${formType}-loading`);

    if (submitBtn) {
      submitBtn.disabled = loading;
      
      if (loading) {
        textSpan?.classList.add('hidden');
        loadingSpan?.classList.remove('hidden');
      } else {
        textSpan?.classList.remove('hidden');
        loadingSpan?.classList.add('hidden');
      }
    }
  }

  showError(message) {
    const errorEl = document.getElementById('auth-error');
    const errorMessageEl = document.getElementById('auth-error-message');
    
    if (errorEl && errorMessageEl) {
      errorMessageEl.textContent = message;
      errorEl.classList.remove('hidden');
    }
    
    this.hideElement('auth-success');
  }

  showSuccess(message) {
    const successEl = document.getElementById('auth-success');
    const successMessageEl = document.getElementById('auth-success-message');
    
    if (successEl && successMessageEl) {
      successMessageEl.textContent = message;
      successEl.classList.remove('hidden');
    }
    
    this.hideElement('auth-error');
  }

  clearMessages() {
    this.hideElement('auth-error');
    this.hideElement('auth-success');
  }

  clearForms() {
    const forms = document.querySelectorAll('#auth-modal form');
    forms.forEach(form => form.reset());
  }

  showElement(id) {
    const el = document.getElementById(id);
    if (el) el.classList.remove('hidden');
  }

  hideElement(id) {
    const el = document.getElementById(id);
    if (el) el.classList.add('hidden');
  }

  // Public methods for cart integration
  getCurrentUser() {
    return this.currentUser;
  }

  getUserDataForSwell() {
    return getUserDataForSwell();
  }

  requireAuth(callback) {
    if (this.currentUser) {
      callback(this.currentUser);
    } else {
      this.openModal('signin');
      
      // Listen for successful auth
      const unsubscribe = onAuthStateChange((user) => {
        if (user) {
          callback(user);
          unsubscribe();
        }
      });
    }
  }
}

// Initialize auth handler
const authHandler = new AuthHandler();

// Export for use by other scripts
window.authHandler = authHandler;

export default authHandler;