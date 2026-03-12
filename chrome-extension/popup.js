'use strict';

const views = {
  onboarding: document.getElementById('onboarding-view'),
  main:       document.getElementById('main-view'),
  settings:   document.getElementById('settings-view'),
};
const el = {
  loading:       document.getElementById('loading'),
  errorView:     document.getElementById('error-view'),
  errorMsg:      document.getElementById('error-msg'),
  budgetContent: document.getElementById('budget-content'),
  lastUpdated:   document.getElementById('last-updated'),
  baseUrlInput:  document.getElementById('base-url'),
  tokenInput:    document.getElementById('token'),
  ghTokenInput:  document.getElementById('gh-token'),
  settingsError: document.getElementById('settings-error'),
};

// ── View helpers ──────────────────────────────────────────────────────────────
function showView(name) {
  Object.values(views).forEach(v => v.classList.add('hidden'));
  views[name].classList.remove('hidden');
}
function setMainState(state) {
  el.loading.classList.add('hidden');
  el.errorView.classList.add('hidden');
  el.budgetContent.classList.add('hidden');
  if (state === 'loading') el.loading.classList.remove('hidden');
  else if (state === 'error') el.errorView.classList.remove('hidden');
  else if (state === 'data') el.budgetContent.classList.remove('hidden');
}

// ── Helpers ───────────────────────────────────────────────────────────────────
const fmt  = n => `$${Number(n).toFixed(2)}`;
const pct  = (a, b) => b > 0 ? Math.round((a / b) * 100) : 0;
const cls  = r => r <= 10 ? 'red' : r <= 25 ? 'yellow' : 'green';

function fmtReset(iso) {
  if (!iso) return null;
  try {
    const d = new Date(iso);
    const days = Math.ceil((d - Date.now()) / 86_400_000);
    return `${d.toLocaleDateString('en-US',{month:'short',day:'numeric',year:'numeric'})} (in ${days}d)`;
  } catch { return iso; }
}

function progressBar(pctUsed, color) {
  return `<div class="progress-section">
    <div class="progress-track"><div class="progress-fill ${color}" style="width:${pctUsed}%"></div></div>
    <div class="progress-labels"><span>${pctUsed}% used</span><span>${100-pctUsed}% left</span></div>
  </div>`;
}

// ── API fetch ─────────────────────────────────────────────────────────────────
async function apiFetch(url, headers = {}, withCredentials = false) {
  const res = await fetch(url, {
    headers: { accept: 'application/json', ...headers },
    credentials: withCredentials ? 'include' : 'omit',
  });
  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new Error(body.error || body.message || `HTTP ${res.status}`);
  }
  return res.json();
}

// ── LiteLLM section ───────────────────────────────────────────────────────────
async function buildLiteLLMSection(baseUrl, token) {
  const auth = { Authorization: `Bearer ${token}` };
  const [keyData, userData] = await Promise.all([
    apiFetch(`${baseUrl}/key/info`, auth),
    apiFetch(`${baseUrl}/user/info`, auth),
  ]);

  const cards = [];
  const k = keyData.info;

  // Key budget card
  {
    const spend = k.spend, budget = k.max_budget;
    const rem = budget - spend;
    const pu = pct(spend, budget), pr = 100 - pu;
    const c = cls(pr);
    const reset = fmtReset(k.budget_reset_at);
    cards.push(`<div class="card">
      <div class="card-title">${k.key_alias || k.key_name || 'My Key'}</div>
      <div class="stat-row"><span class="label">Spent</span><span class="value">${fmt(spend)} <span class="dim">/ ${fmt(budget)}</span></span></div>
      <div class="stat-row"><span class="label">Remaining</span><span class="value highlight ${c}">${fmt(rem)} <span class="dim">(${pr}%)</span></span></div>
      ${reset ? `<div class="stat-row"><span class="label">Resets</span><span class="value dim-value">${reset}</span></div>` : ''}
      ${progressBar(pu, c)}
    </div>`);
  }

  // User lifetime
  {
    const u = userData.user_info;
    cards.push(`<div class="card">
      <div class="card-title">👤 ${u.user_email || 'Lifetime Spend'}</div>
      <div class="stat-row"><span class="label">Total Spent</span><span class="value">${fmt(u.spend)} <span class="dim">lifetime</span></span></div>
    </div>`);
  }

  // Team (if available)
  const teamId = k.team_id;
  if (teamId) {
    try {
      const td = await apiFetch(`${baseUrl}/team/info?team_id=${teamId}`, auth);
      const t = td.team_info;
      if (t.max_budget) {
        const spend = t.spend, budget = t.max_budget;
        const rem = budget - spend;
        const pu = pct(spend, budget), pr = 100 - pu;
        const c = cls(pr);
        const reset = fmtReset(t.budget_reset_at);
        cards.push(`<div class="card">
          <div class="card-title">🏢 ${t.team_alias || t.team_id}</div>
          <div class="stat-row"><span class="label">Spent</span><span class="value">${fmt(spend)} <span class="dim">/ ${fmt(budget)}</span></span></div>
          <div class="stat-row"><span class="label">Remaining</span><span class="value highlight ${c}">${fmt(rem)} <span class="dim">(${pr}%)</span></span></div>
          ${reset ? `<div class="stat-row"><span class="label">Resets</span><span class="value dim-value">${reset}</span></div>` : ''}
          ${progressBar(pu, c)}
        </div>`);
      }
    } catch { /* skip */ }
  }

  return `<div class="service-group">
    <div class="service-title">🤖 LiteLLM</div>
    ${cards.join('')}
  </div>`;
}

// ── GitHub Copilot section ────────────────────────────────────────────────────
async function buildCopilotSection(ghToken) {
  if (!ghToken) return `<div class="service-group">
    <div class="service-title">🐙 GitHub Copilot</div>
    <div class="card-skipped">No GitHub token configured — add one in Settings.</div>
  </div>`;

  const data = await apiFetch('https://api.github.com/copilot_internal/user', {
    Authorization: `Bearer ${ghToken}`,
    'X-GitHub-Api-Version': '2022-11-28',
  });

  const snapshots = data.quota_snapshots || {};
  const resetDate = data.quota_reset_date
    ? new Date(data.quota_reset_date).toLocaleDateString('en-US',{month:'short',day:'numeric',year:'numeric'})
    : null;

  const rows = Object.entries(snapshots).map(([id, q]) => {
    const label = id.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
    if (q.unlimited) {
      return `<div class="quota-row">
        <span class="quota-label">${label}</span>
        <span class="quota-val unlimited">Unlimited</span>
      </div>`;
    }
    const used = (q.entitlement || 0) - (q.remaining || 0);
    const total = q.entitlement || 0;
    const pu = pct(used, total);
    const pr = 100 - pu;
    const c = cls(pr);
    return `<div class="quota-row">
      <span class="quota-label">${label}</span>
      <span class="quota-val">${q.remaining} <span class="dim">/ ${total}</span></span>
    </div>
    <div class="progress-section" style="margin-bottom:4px">
      <div class="progress-track"><div class="progress-fill ${c}" style="width:${pu}%"></div></div>
      <div class="progress-labels"><span>${pu}% used</span><span>${pr}% left</span></div>
    </div>`;
  });

  const plan = data.copilot_plan || 'unknown';
  const resetLine = resetDate ? `<div class="stat-row" style="margin-bottom:6px"><span class="label">Resets</span><span class="value dim-value">${resetDate}</span></div>` : '';

  return `<div class="service-group">
    <div class="service-title">🐙 GitHub Copilot <span style="font-weight:400;text-transform:none;letter-spacing:0">(${plan})</span></div>
    <div class="card">
      ${resetLine}
      ${rows.join('')}
    </div>
  </div>`;
}

// ── Cursor section ────────────────────────────────────────────────────────────
async function buildCursorSection() {
  let data;
  try {
    data = await apiFetch('https://cursor.com/api/usage', {}, true /* include cookies */);
  } catch (e) {
    const msg = e.message?.includes('not_authenticated') || e.message?.includes('401')
      ? 'Not logged in to cursor.com — open cursor.com in this browser and sign in.'
      : `Error: ${e.message}`;
    return `<div class="service-group">
      <div class="service-title">🖱️ Cursor</div>
      <div class="card-skipped">${msg}</div>
    </div>`;
  }

  // Cursor API returns model-keyed usage: { gpt-4: { numRequests, numRequestsTotal, maxRequestUsage, ... }, ... }
  const rows = [];
  for (const [model, info] of Object.entries(data)) {
    if (typeof info !== 'object' || info === null) continue;
    const used = info.numRequests ?? 0;
    const max  = info.maxRequestUsage;
    const label = model.replace(/-/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
    if (max == null) {
      rows.push(`<div class="quota-row">
        <span class="quota-label">${label}</span>
        <span class="quota-val">${used} <span class="dim">req</span></span>
      </div>`);
    } else {
      const pu = pct(used, max), pr = 100 - pu;
      const c = cls(pr);
      rows.push(`<div class="quota-row">
        <span class="quota-label">${label}</span>
        <span class="quota-val">${max - used} <span class="dim">/ ${max} left</span></span>
      </div>
      <div class="progress-section" style="margin-bottom:4px">
        <div class="progress-track"><div class="progress-fill ${c}" style="width:${pu}%"></div></div>
        <div class="progress-labels"><span>${pu}% used</span><span>${pr}% left</span></div>
      </div>`);
    }
  }

  if (!rows.length) rows.push('<div class="card-skipped">No usage data returned.</div>');

  return `<div class="service-group">
    <div class="service-title">🖱️ Cursor</div>
    <div class="card">${rows.join('')}</div>
  </div>`;
}

// ── Main load ─────────────────────────────────────────────────────────────────
async function loadBudget() {
  const { baseUrl, token, ghToken } = await chrome.storage.local.get(['baseUrl', 'token', 'ghToken']);
  if (!baseUrl || !token) { showView('onboarding'); return; }

  showView('main');
  setMainState('loading');

  try {
    const [litellm, copilot, cursor] = await Promise.allSettled([
      buildLiteLLMSection(baseUrl, token),
      buildCopilotSection(ghToken),
      buildCursorSection(),
    ]);

    const htmlParts = [litellm, copilot, cursor].map((r, i) => {
      if (r.status === 'fulfilled') return r.value;
      const labels = ['🤖 LiteLLM', '🐙 GitHub Copilot', '🖱️ Cursor'];
      return `<div class="service-group">
        <div class="service-title">${labels[i]}</div>
        <div class="card-error">${r.reason?.message || 'Failed to load'}</div>
      </div>`;
    });

    el.budgetContent.innerHTML = htmlParts.join('');
    el.lastUpdated.textContent = new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    setMainState('data');
  } catch (err) {
    el.errorMsg.textContent = err.message || 'Unexpected error.';
    setMainState('error');
  }
}

// ── Settings ──────────────────────────────────────────────────────────────────
async function openSettings() {
  const { baseUrl, token, ghToken } = await chrome.storage.local.get(['baseUrl', 'token', 'ghToken']);
  el.baseUrlInput.value = baseUrl || '';
  el.tokenInput.value   = token   || '';
  el.ghTokenInput.value = ghToken || '';
  el.settingsError.classList.add('hidden');
  showView('settings');
}

async function saveSettings() {
  const baseUrl = el.baseUrlInput.value.trim();
  const token   = el.tokenInput.value.trim();
  const ghToken = el.ghTokenInput.value.trim();
  if (!baseUrl || !token) {
    el.settingsError.textContent = 'LiteLLM URL and token are required.';
    el.settingsError.classList.remove('hidden');
    return;
  }
  el.settingsError.classList.add('hidden');
  await chrome.storage.local.set({ baseUrl, token, ghToken: ghToken || null });
  await loadBudget();
}

// ── Events ────────────────────────────────────────────────────────────────────
document.getElementById('configure-btn').addEventListener('click', openSettings);
document.getElementById('settings-icon').addEventListener('click', openSettings);
document.getElementById('save-btn').addEventListener('click', saveSettings);
document.getElementById('cancel-btn').addEventListener('click', loadBudget);
document.getElementById('retry-btn').addEventListener('click', loadBudget);
document.getElementById('refresh-btn').addEventListener('click', loadBudget);
[el.baseUrlInput, el.tokenInput, el.ghTokenInput].forEach(i =>
  i.addEventListener('keydown', e => e.key === 'Enter' && saveSettings())
);

loadBudget();
