'use strict';

let hideTimer    = null;
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

    // Three short square-wave beeps — classic pager tone
    function beep(startTime) {
      const osc  = ctx.createOscillator();
      const gain = ctx.createGain();

      osc.connect(gain);
      gain.connect(ctx.destination);

      osc.type            = 'square';
      osc.frequency.value = 1050; // Hz

      gain.gain.setValueAtTime(0.25, startTime);
      gain.gain.exponentialRampToValueAtTime(0.001, startTime + 0.12);

      osc.start(startTime);
      osc.stop(startTime + 0.12);
    }

    const t = ctx.currentTime;
    beep(t);
    beep(t + 0.22);
    beep(t + 0.44);
  } catch (e) {
    // Audio not available — silently skip
  }
}

window.addEventListener('message', function (event) {
  const data = event.data;
  if (!data || data.action !== 'showPage') return;

  const popup   = document.getElementById('pager-popup');
  const fromEl  = document.getElementById('pager-from');
  const msgEl   = document.getElementById('pager-message');
  const timeEl  = document.getElementById('pager-time');

  // Play pager beep
  playPagerBeep();

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
