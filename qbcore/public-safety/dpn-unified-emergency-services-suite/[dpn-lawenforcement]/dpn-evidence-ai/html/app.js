let state = { cases: [], evidence: [], config: { types: [], statuses: {} } };
const byId = id => document.getElementById(id);
function post(name, data = {}) {
  return fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data)
  }).catch(() => {});
}
function make(tag, value, className) {
  const element = document.createElement(tag);
  if (className) element.className = className;
  if (value !== undefined) element.textContent = String(value ?? '');
  return element;
}
function button(label, callback) {
  const element = make('button', label);
  element.addEventListener('click', callback);
  return element;
}
function closeUi() { post('close'); }
function createCase() {
  post('createCase', { title: byId('caseTitle').value, description: byId('caseDesc').value });
  byId('caseTitle').value = ''; byId('caseDesc').value = '';
}
function addEvidence() {
  post('addEvidence', {
    case_id: byId('evCase').value || null,
    type: byId('evType').value,
    title: byId('evTitle').value,
    notes: byId('evNotes').value,
    meta: { source: 'manual-nui' }
  });
  byId('evTitle').value = ''; byId('evNotes').value = '';
}
function render() {
  const typeSelect = byId('evType');
  typeSelect.replaceChildren();
  (state.config.types || ['other']).forEach(type => {
    const option = make('option', type);
    option.value = type;
    typeSelect.appendChild(option);
  });

  const caseList = byId('cases');
  caseList.replaceChildren();
  if (!(state.cases || []).length) caseList.appendChild(make('div', 'No cases found.'));
  (state.cases || []).forEach(record => {
    const row = make('div', undefined, 'row');
    const title = make('b');
    title.append(document.createTextNode(record.case_id || 'UNKNOWN'), document.createElement('br'), document.createTextNode(record.title || 'Untitled Case'));
    row.appendChild(title);
    row.appendChild(make('span', record.status || 'open', 'tag'));
    row.appendChild(make('span', record.created_by_name || 'Unknown'));
    const actions = make('span');
    actions.appendChild(button('Court', () => post('court', { case_id: record.case_id })));
    actions.append(' ');
    actions.appendChild(button('Close', () => post('status', { case_id: record.case_id, status: 'closed' })));
    row.appendChild(actions);
    caseList.appendChild(row);
  });

  const evidenceList = byId('evidence');
  evidenceList.replaceChildren();
  if (!(state.evidence || []).length) evidenceList.appendChild(make('div', 'No evidence found.'));
  (state.evidence || []).forEach(record => {
    const row = make('div', undefined, 'row');
    const title = make('b');
    title.append(document.createTextNode(record.evidence_id || 'UNKNOWN'), document.createElement('br'), document.createTextNode(record.title || 'Evidence Item'));
    row.appendChild(title);
    row.appendChild(make('span', record.type || 'other', 'tag'));
    const custody = make('span');
    custody.append(document.createTextNode(record.case_id || 'No Case'), document.createElement('br'), document.createTextNode(record.custody_holder_name || 'Digital Evidence Locker'));
    row.appendChild(custody);
    const actions = make('span');
    actions.appendChild(button('Transfer', () => {
      const target = prompt('Transfer custody to officer / locker name:');
      if (target) post('transferCustody', { evidence_id: record.evidence_id, to_holder: target, to_name: target, notes: 'NUI custody transfer' });
    }));
    row.appendChild(actions);
    evidenceList.appendChild(row);
  });
}
window.addEventListener('message', event => {
  const message = event.data || {};
  if (message.action === 'show') byId('app').classList.remove('hidden');
  if (message.action === 'hide') byId('app').classList.add('hidden');
  if (message.action === 'data') { state = message.data || state; render(); }
  if (message.action === 'courtReport') {
    const courtCase = message.data?.case || {};
    const items = message.data?.evidence || [];
    byId('report').textContent = `DPN COURT REPORT\nCase: ${courtCase.case_id || ''}\nTitle: ${courtCase.title || ''}\nStatus: ${courtCase.status || ''}\nCreated By: ${courtCase.created_by_name || ''}\n\nSummary:\n${courtCase.description || ''}\n\nEvidence (${items.length}):\n` + items.map((item, index) => `${index + 1}. ${item.evidence_id} | ${item.type} | ${item.title} | Custody: ${item.custody_holder_name || ''}`).join('\n');
  }
});
document.addEventListener('keydown', event => { if (event.key === 'Escape') closeUi(); });
