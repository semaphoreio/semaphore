// Enhanced form validation for email changes
document.addEventListener('DOMContentLoaded', function() {
  const emailForm = document.getElementById('email-form');
  
  if (emailForm) {
    emailForm.addEventListener('submit', function(e) {
      const emailInput = emailForm.querySelector('input[type="email"]');
      const currentEmail = emailInput.placeholder;
      const newEmail = emailInput.value.trim();
      
      // Check if email is different from current
      if (newEmail === currentEmail) {
        e.preventDefault();
        alert('Please enter a different email address.');
        return false;
      }
      
      // Basic email format validation (HTML5 handles most of this)
      const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
      if (!emailRegex.test(newEmail)) {
        e.preventDefault();
        alert('Please enter a valid email address.');
        return false;
      }
      
      // Check for empty email
      if (newEmail.length === 0) {
        e.preventDefault();
        alert('Email address cannot be empty.');
        return false;
      }
    });
    
    // Real-time validation feedback
    const emailInput = emailForm.querySelector('input[type="email"]');
    if (emailInput) {
      emailInput.addEventListener('blur', function() {
        const currentEmail = emailInput.placeholder;
        const newEmail = emailInput.value.trim();
        
        if (newEmail === currentEmail && newEmail.length > 0) {
          emailInput.style.borderColor = '#ff6b6b';
          emailInput.title = 'This is your current email address';
        } else {
          emailInput.style.borderColor = '';
          emailInput.title = '';
        }
      });
    }
  }
});