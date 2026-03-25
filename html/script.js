'use strict';

// ── State ──────────────────────────────────────
let myPagerNumber   = null;
let contacts        = [];
let inbox           = [];
let pendingSendTo   = null; // { number, name } for the send overlay
let pendingInboxMsg = null; // inbox entry for action overlay

// ── NUI callback helper ────────────────────────
function nuiCallback(name, data) {
  fetch(`https://hbs-pager/${name}`, {
    method:  'POST',
    headers: { 'Content-Type': 'application/json' },
    body:    JSON.stringify(data || {}),
  });
}

// ── Audio ──────────────────────────────────────
let audioContext = null;

function getAudioContext() {
  if (!audioContext) {
    audioContext = new (window.AudioContext || window.webkitAudioContext)();
  }
  return audioContext;
}

function playPagerBeep() {
  try {
    const ctx = getAudioContext();
    function beep(t) {
      const osc  = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.type            = 'square';
      osc.frequency.value = 1050;
      gain.gain.setValueAtTime(0.25, t);
      gain.gain.exponentialRampToValueAtTime(0.001, t + 0.12);
      osc.start(t);
      osc.stop(t + 0.12);
    }
    const t = ctx.currentTime;
    beep(t); beep(t + 0.22); beep(t + 0.44);
  } catch (e) {}
}

// ── Tab switching (hardware buttons) ───────────
document.querySelectorAll('.hw-btn[data-tab]').forEach(btn => {
  btn.addEventListener('click', () => {
    document.querySelectorAll('.hw-btn[data-tab]').forEach(b => b.classList.remove('active'));
    document.querySelectorAll('.tab-pane').forEach(p => p.classList.add('hidden'));
    btn.classList.add('active');
    document.getElementById('tab-' + btn.dataset.tab).classList.remove('hidden');
    hideAllOverlays();
  });
});

// ── Render helpers ─────────────────────────────
function renderContacts() {
  const list = document.getElementById('contacts-list');
  list.innerHTML = '';

  if (contacts.length === 0) {
    list.innerHTML = '<div class="empty-msg">NO CONTACTS SAVED</div>';
    return;
  }

  contacts.forEach((c, i) => {
    const row = document.createElement('div');
    row.className = 'list-row';
    row.innerHTML = `
      <div class="list-row-main">
        <span class="list-row-name">${escHtml(c.name)}</span>
        <span class="list-row-sub">#${c.number}</span>
      </div>
      <span class="list-row-sub">&#9654;</span>
    `;
    row.addEventListener('click', () => openSendOverlay(c.number, c.name, i));
    list.appendChild(row);
  });
}

function renderInbox() {
  const list = document.getElementById('inbox-list');
  list.innerHTML = '';

  if (inbox.length === 0) {
    list.innerHTML = '<div class="empty-msg">NO MESSAGES</div>';
    return;
  }

  inbox.forEach(msg => {
    const row = document.createElement('div');
    row.className = 'list-row';
    row.innerHTML = `
      <div class="list-row-main">
        <span class="list-row-name">#${msg.sender}</span>
        <span class="list-row-sub">${escHtml(msg.message)}</span>
      </div>
      <span class="list-row-sub">${msg.time}</span>
    `;
    row.addEventListener('click', () => openInboxAction(msg));
    list.appendChild(row);
  });
}

function escHtml(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

// ── Open / close main UI ───────────────────────
function openPager(data) {
  myPagerNumber = data.pagerNumber;
  contacts      = data.contacts || [];
  inbox         = data.inbox    || [];

  document.getElementById('my-number').textContent = '#' + myPagerNumber;
  renderContacts();
  renderInbox();

  // Reset to contacts tab
  document.querySelectorAll('.hw-btn[data-tab]').forEach(b => b.classList.remove('active'));
  document.querySelectorAll('.tab-pane').forEach(p => p.classList.add('hidden'));
  document.querySelector('.hw-btn[data-tab="contacts"]').classList.add('active');
  document.getElementById('tab-contacts').classList.remove('hidden');

  hideAllOverlays();
  document.getElementById('pager-ui').classList.remove('hidden');
}

function closePager() {
  document.getElementById('pager-ui').classList.add('hidden');
  nuiCallback('closePager');
}

// ── Overlays ───────────────────────────────────
function hideAllOverlays() {
  document.getElementById('add-contact-overlay').classList.add('hidden');
  document.getElementById('send-overlay').classList.add('hidden');
  document.getElementById('inbox-action-overlay').classList.add('hidden');
}

// Send overlay (quick-dial from contact)
function openSendOverlay(number, name, contactIndex) {
  pendingSendTo = { number, name, contactIndex };
  document.getElementById('send-overlay-title').textContent =
    name ? `PAGE ${name.toUpperCase()} #${number}` : `PAGE #${number}`;
  document.getElementById('send-message').value = '';
  document.getElementById('send-overlay').classList.remove('hidden');
  document.getElementById('send-message').focus();
}

document.getElementById('confirm-send-btn').addEventListener('click', () => {
  if (!pendingSendTo) return;
  const msg = document.getElementById('send-message').value.trim();
  if (!msg) return;
  nuiCallback('sendPage', { number: pendingSendTo.number, message: msg });
  hideAllOverlays();
});

document.getElementById('cancel-send-btn').addEventListener('click', hideAllOverlays);

// Add contact overlay
document.getElementById('add-contact-btn').addEventListener('click', () => {
  document.getElementById('new-contact-name').value   = '';
  document.getElementById('new-contact-number').value = '';
  document.getElementById('add-contact-overlay').classList.remove('hidden');
  document.getElementById('new-contact-name').focus();
});

document.getElementById('save-contact-btn').addEventListener('click', () => {
  const name   = document.getElementById('new-contact-name').value.trim();
  const number = document.getElementById('new-contact-number').value.trim();
  if (!name || !number) return;
  nuiCallback('saveContact', { name, number: parseInt(number, 10) });
  hideAllOverlays();
});

document.getElementById('cancel-contact-btn').addEventListener('click', hideAllOverlays);

// Inbox action overlay
function openInboxAction(msg) {
  pendingInboxMsg = msg;
  document.getElementById('inbox-action-title').textContent   = `FROM #${msg.sender}  [${msg.time}]`;
  document.getElementById('inbox-action-message').textContent = msg.message;
  document.getElementById('inbox-action-overlay').classList.remove('hidden');
}

document.getElementById('inbox-reply-btn').addEventListener('click', () => {
  if (!pendingInboxMsg) return;
  hideAllOverlays();
  openSendOverlay(pendingInboxMsg.sender, null, null);
});

document.getElementById('inbox-save-btn').addEventListener('click', () => {
  if (!pendingInboxMsg) return;
  // Reuse the add-contact overlay with the sender's number pre-filled
  document.getElementById('new-contact-name').value   = '';
  document.getElementById('new-contact-number').value = pendingInboxMsg.sender;
  document.getElementById('inbox-action-overlay').classList.add('hidden');
  document.getElementById('add-contact-overlay').classList.remove('hidden');
  document.getElementById('new-contact-name').focus();
});

document.getElementById('inbox-back-btn').addEventListener('click', hideAllOverlays);

// Dial tab send
document.getElementById('dial-send-btn').addEventListener('click', () => {
  const number  = parseInt(document.getElementById('dial-number').value.trim(), 10);
  const message = document.getElementById('dial-message').value.trim();
  if (!number || !message) return;
  nuiCallback('sendPage', { number, message });
  document.getElementById('dial-number').value  = '';
  document.getElementById('dial-message').value = '';
});

// Close button
document.getElementById('close-btn').addEventListener('click', closePager);

// ESC to close
document.addEventListener('keydown', e => {
  if (e.key === 'Escape') {
    const overlay =
      !document.getElementById('add-contact-overlay').classList.contains('hidden') ||
      !document.getElementById('send-overlay').classList.contains('hidden') ||
      !document.getElementById('inbox-action-overlay').classList.contains('hidden');
    if (overlay) {
      hideAllOverlays();
    } else if (!document.getElementById('pager-ui').classList.contains('hidden')) {
      closePager();
    }
  }
});

// ── Incoming page popup ────────────────────────
let hideTimer = null;

function showPagePopup(data) {
  playPagerBeep();

  // Add to inbox state
  inbox.unshift({ sender: data.sender, message: data.message, time: data.time });
  renderInbox();

  const popup  = document.getElementById('pager-popup');
  document.getElementById('pager-from').textContent    = 'PAGE FROM #' + data.sender;
  document.getElementById('pager-message').textContent = data.message;
  document.getElementById('pager-time').textContent    = data.time || '';

  clearTimeout(hideTimer);
  popup.classList.remove('slide-out', 'hidden');

  const duration = typeof data.duration === 'number' ? data.duration : 8000;
  hideTimer = setTimeout(() => {
    popup.classList.add('slide-out');
    setTimeout(() => {
      popup.classList.add('hidden');
      popup.classList.remove('slide-out');
    }, 320);
  }, duration);
}

// ── NUI message handler ────────────────────────
window.addEventListener('message', function (event) {
  const data = event.data;
  if (!data || !data.action) return;

  switch (data.action) {
    case 'openPager':
      openPager(data);
      break;
    case 'closePager':
      document.getElementById('pager-ui').classList.add('hidden');
      break;
    case 'showPage':
      showPagePopup(data);
      break;
    case 'updateContacts':
      contacts = data.contacts || [];
      renderContacts();
      break;
  }
});
