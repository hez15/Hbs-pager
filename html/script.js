'use strict';

let hideTimer = null;

window.addEventListener('message', function (event) {
  const data = event.data;
  if (!data || data.action !== 'showPage') return;

  const popup   = document.getElementById('pager-popup');
  const fromEl  = document.getElementById('pager-from');
  const msgEl   = document.getElementById('pager-message');
  const timeEl  = document.getElementById('pager-time');

  // Clear any pending hide
  clearTimeout(hideTimer);
  popup.classList.remove('slide-out', 'hidden');

  // Populate fields
  fromEl.textContent = 'PAGE FROM #' + data.sender;
  msgEl.textContent  = data.message;
  timeEl.textContent = data.time || '';

  // Auto-dismiss
  const duration = typeof data.duration === 'number' ? data.duration : 8000;
  hideTimer = setTimeout(function () {
    popup.classList.add('slide-out');
    setTimeout(function () {
      popup.classList.add('hidden');
      popup.classList.remove('slide-out');
    }, 320);
  }, duration);
});
