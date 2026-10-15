/**
 * Fábrica de Serviços Cross-Platform - Documentation Application Logic
 */

document.addEventListener('DOMContentLoaded', () => {
  // 1. Theme Toggle
  const themeToggleBtn = document.getElementById('themeToggleBtn');
  const savedTheme = localStorage.getItem('svc_doc_theme') || 'dark';
  document.documentElement.setAttribute('data-theme', savedTheme);

  if (themeToggleBtn) {
    themeToggleBtn.addEventListener('click', () => {
      const current = document.documentElement.getAttribute('data-theme');
      const nextTheme = current === 'dark' ? 'light' : 'dark';
      document.documentElement.setAttribute('data-theme', nextTheme);
      localStorage.setItem('svc_doc_theme', nextTheme);
    });
  }

  // 2. Mobile Menu Toggle
  const mobileMenuBtn = document.getElementById('mobileMenuBtn');
  const sidebar = document.getElementById('sidebar');

  if (mobileMenuBtn && sidebar) {
    mobileMenuBtn.addEventListener('click', () => {
      sidebar.classList.toggle('open');
    });

    // Close when clicking outside on mobile
    document.addEventListener('click', (e) => {
      if (!sidebar.contains(e.target) && !mobileMenuBtn.contains(e.target) && sidebar.classList.contains('open')) {
        sidebar.classList.remove('open');
      }
    });
  }

  // 3. Search Filter in Sidebar
  const searchInput = document.getElementById('sidebarSearch');
  const navLinks = document.querySelectorAll('.sidebar .nav-link');

  if (searchInput) {
    searchInput.addEventListener('input', (e) => {
      const term = e.target.value.toLowerCase().trim();
      navLinks.forEach((link) => {
        const text = link.textContent.toLowerCase();
        if (text.includes(term) || term === '') {
          link.style.display = 'flex';
        } else {
          link.style.display = 'none';
        }
      });
    });
  }

  // 4. Tab Switching
  const tabContainers = document.querySelectorAll('.tab-container');
  tabContainers.forEach((container) => {
    const buttons = container.querySelectorAll('.tab-btn');
    const panes = container.querySelectorAll('.tab-pane');

    buttons.forEach((btn, idx) => {
      btn.addEventListener('click', () => {
        buttons.forEach((b) => b.classList.remove('active'));
        panes.forEach((p) => p.classList.remove('active'));

        btn.classList.add('active');
        if (panes[idx]) {
          panes[idx].classList.add('active');
        }
      });
    });
  });

  // 5. Copy Code to Clipboard
  const copyButtons = document.querySelectorAll('.btn-copy');
  copyButtons.forEach((btn) => {
    btn.addEventListener('click', () => {
      const codeBlock = btn.closest('.code-window').querySelector('pre code');
      if (codeBlock) {
        const textToCopy = codeBlock.innerText;
        navigator.clipboard.writeText(textToCopy).then(() => {
          const originalText = btn.innerHTML;
          btn.innerHTML = `
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <polyline points="20 6 9 17 4 12"></polyline>
            </svg> Copiado!
          `;
          btn.style.borderColor = 'var(--accent-emerald)';
          btn.style.color = 'var(--accent-emerald)';

          setTimeout(() => {
            btn.innerHTML = originalText;
            btn.style.borderColor = '';
            btn.style.color = '';
          }, 2000);
        });
      }
    });
  });

  // 6. Active Sidebar Link Spy
  const sections = document.querySelectorAll('.doc-section');
  const observerOptions = {
    root: null,
    rootMargin: '-20% 0px -70% 0px',
    threshold: 0
  };

  const observer = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        const id = entry.target.getAttribute('id');
        navLinks.forEach((link) => {
          if (link.getAttribute('href') === `#${id}`) {
            link.classList.add('active');
          } else {
            link.classList.remove('active');
          }
        });
      }
    });
  }, observerOptions);

  sections.forEach((sec) => observer.observe(sec));
});
