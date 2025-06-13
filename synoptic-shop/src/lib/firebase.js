// src/lib/firebase.js - Firebase configuration for web shop
import { initializeApp } from 'firebase/app';
import { 
  getAuth, 
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
  signOut,
  onAuthStateChanged,
  sendPasswordResetEmail,
  updateProfile
} from 'firebase/auth';

// Firebase configuration from your existing project
const firebaseConfig = {
  apiKey: 'AIzaSyBSUx6kTj34uo7vqcVml0NA4s4_miTTcR0',
  authDomain: 'aimanagerfirebasebackend.firebaseapp.com',
  projectId: 'aimanagerfirebasebackend',
  storageBucket: 'aimanagerfirebasebackend.firebasestorage.app',
  messagingSenderId: '723311357828',
  appId: '1:723311357828:web:d55617cf5b0a5282ab37d1',
  measurementId: 'G-GF71C63N9P'
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);

// Initialize Auth
const auth = getAuth(app);

// Auth state management
let currentUser = null;
let authStateInitialized = false;
const authCallbacks = new Set();

// Listen to auth state changes
onAuthStateChanged(auth, (user) => {
  currentUser = user;
  authStateInitialized = true;
  
  // Notify all subscribers
  authCallbacks.forEach(callback => {
    try {
      callback(user);
    } catch (error) {
      console.error('Error in auth state callback:', error);
    }
  });
});

/**
 * Subscribe to auth state changes
 * @param {Function} callback - Callback function to call when auth state changes
 * @returns {Function} Unsubscribe function
 */
export function onAuthStateChange(callback) {
  authCallbacks.add(callback);
  
  // If auth is already initialized, call immediately
  if (authStateInitialized) {
    callback(currentUser);
  }
  
  // Return unsubscribe function
  return () => {
    authCallbacks.delete(callback);
  };
}

/**
 * Get current user
 * @returns {Object|null} Current user or null
 */
export function getCurrentUser() {
  return currentUser;
}

/**
 * Check if user is authenticated
 * @returns {boolean} True if user is authenticated
 */
export function isAuthenticated() {
  return currentUser !== null;
}

/**
 * Sign in with email and password
 * @param {string} email - User email
 * @param {string} password - User password
 * @returns {Promise<Object>} User credential
 */
export async function signIn(email, password) {
  try {
    const userCredential = await signInWithEmailAndPassword(auth, email, password);
    return {
      success: true,
      user: userCredential.user,
      error: null
    };
  } catch (error) {
    console.error('Sign in error:', error);
    return {
      success: false,
      user: null,
      error: getAuthErrorMessage(error)
    };
  }
}

/**
 * Sign up with email and password
 * @param {string} email - User email
 * @param {string} password - User password
 * @param {string} displayName - User display name (optional)
 * @returns {Promise<Object>} User credential
 */
export async function signUp(email, password, displayName = '') {
  try {
    const userCredential = await createUserWithEmailAndPassword(auth, email, password);
    
    // Update profile with display name if provided
    if (displayName && userCredential.user) {
      await updateProfile(userCredential.user, {
        displayName: displayName
      });
    }
    
    return {
      success: true,
      user: userCredential.user,
      error: null
    };
  } catch (error) {
    console.error('Sign up error:', error);
    return {
      success: false,
      user: null,
      error: getAuthErrorMessage(error)
    };
  }
}

/**
 * Sign out current user
 * @returns {Promise<Object>} Success status
 */
export async function signOutUser() {
  try {
    await signOut(auth);
    return {
      success: true,
      error: null
    };
  } catch (error) {
    console.error('Sign out error:', error);
    return {
      success: false,
      error: getAuthErrorMessage(error)
    };
  }
}

/**
 * Send password reset email
 * @param {string} email - User email
 * @returns {Promise<Object>} Success status
 */
export async function resetPassword(email) {
  try {
    await sendPasswordResetEmail(auth, email);
    return {
      success: true,
      error: null
    };
  } catch (error) {
    console.error('Password reset error:', error);
    return {
      success: false,
      error: getAuthErrorMessage(error)
    };
  }
}

/**
 * Get user-friendly error message
 * @param {Object} error - Firebase auth error
 * @returns {string} User-friendly error message
 */
function getAuthErrorMessage(error) {
  switch (error.code) {
    case 'auth/user-not-found':
      return 'No account found with this email address.';
    case 'auth/wrong-password':
      return 'Incorrect password.';
    case 'auth/email-already-in-use':
      return 'An account with this email already exists.';
    case 'auth/weak-password':
      return 'Password should be at least 6 characters long.';
    case 'auth/invalid-email':
      return 'Please enter a valid email address.';
    case 'auth/user-disabled':
      return 'This account has been disabled.';
    case 'auth/too-many-requests':
      return 'Too many failed attempts. Please try again later.';
    case 'auth/network-request-failed':
      return 'Network error. Please check your connection.';
    case 'auth/invalid-credential':
      return 'Invalid email or password.';
    default:
      return error.message || 'An unexpected error occurred.';
  }
}

/**
 * Get user data for Swell cart integration
 * @returns {Object|null} User data formatted for Swell
 */
export function getUserDataForSwell() {
  if (!currentUser) return null;
  
  return {
    email: currentUser.email,
    first_name: currentUser.displayName?.split(' ')[0] || '',
    last_name: currentUser.displayName?.split(' ').slice(1).join(' ') || '',
    email_verified: currentUser.emailVerified,
    firebase_uid: currentUser.uid
  };
}

// Export auth instance for advanced usage
export { auth };