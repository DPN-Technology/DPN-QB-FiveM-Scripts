const state={reports:[],watchlists:[],links:[],supervisor:false};const $=id=>document.getElementById(id);const app=$('app');
function post(name,data={}){return fetch(`https://${GetParentResourceName()}/${name}`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)}).then(r=>r.json().catch(()=>({ok:true})))}
function esc(value){const d=document.createElement('div');d.textContent=String(value??'');return d.innerHTML}
function card(title,body,meta='',cls=''){return `<div class="card ${cls}"><h3>${esc(title)}</h3><div>${body}</div><div class="meta">${esc(meta)}</div></div>`}
function renderDashboard(){
 $('reportList').innerHTML=state.reports.length?state.reports.map(r=>card(`${r.report_id} • ${r.title}`,esc(r.classification),`${r.status} • ${r.created_by_name} • ${r.updated_at||r.created_at}`)).join(''):'<p>No reports.</p>';
 $('watchList').innerHTML=state.watchlists.length?state.watchlists.map(w=>`<div class="card ${Number(w.priority)===1?'critical':''}"><h3>P${esc(w.priority)} • ${esc(w.label)}</h3><div>${esc(w.reason)}</div><div class="meta">${esc(w.subject_type)} • ${esc(w.subject_key)}</div>${state.supervisor?`<button data-clear="${esc(w.id)}">Clear</button>`:''}</div>`).join(''):'<p>No active watchlists.</p>';
 $('linkList').innerHTML=state.links.length?state.links.map(l=>card(`${l.report_id} → ${l.entity_key}`,esc(l.relationship),`${l.entity_type} • ${l.created_by_name}`)).join(''):'<p>No entity links.</p>';
}
function renderSearch(data){
 $('people').innerHTML=(data.people||[]).length?data.people.map(p=>`<div class="card ${p.risk?.score>=75?'critical':''}"><span class="risk" style="color:${esc(p.risk?.color||'#fff')}">${esc(p.risk?.level||'Routine')} ${Number(p.risk?.score||0)}</span><h3>${esc(p.name||'Unknown')}</h3><div class="meta">${esc(p.citizenid)} • DOB ${esc(p.birthdate||'Unknown')}</div><div class="meta">Bookings ${Number(p.risk?.bookings||0)} • Citations ${Number(p.risk?.citations||0)} • Reports ${Number(p.risk?.linkedReports||0)}</div><button data-alert="${esc(p.citizenid)}" data-label="${esc(p.name)}">Dispatch Intel Alert</button></div>`).join(''):'<p>No people found.</p>';
 $('vehicles').innerHTML=(data.vehicles||[]).length?data.vehicles.map(v=>`<div class="card ${v.flagged?'critical':''}"><span class="risk">${v.flagged?'WATCHLIST':'CLEAR'}</span><h3>${esc(v.plate)} • ${esc(v.vehicle)}</h3><div class="meta">Owner CID ${esc(v.citizenid||'Unknown')} • Garage ${esc(v.garage||'Unknown')}</div>${v.reason?`<div>${esc(v.reason)}</div>`:''}<button data-alert="${esc(v.plate)}" data-label="Vehicle ${esc(v.plate)}">Dispatch Intel Alert</button></div>`).join(''):'<p>No vehicles found.</p>';
}
window.addEventListener('message',e=>{const d=e.data||{};if(d.action==='open'){app.classList.remove('hidden');Object.assign(state,d.data||{});renderDashboard()}if(d.action==='close')app.classList.add('hidden');if(d.action==='searchResults')renderSearch(d.data||{})});
document.querySelectorAll('.nav').forEach(b=>b.onclick=()=>{document.querySelectorAll('.nav').forEach(x=>x.classList.toggle('active',x===b));document.querySelectorAll('.tab').forEach(t=>t.classList.toggle('active',t.id===b.dataset.tab))});
$('close').onclick=()=>post('close');document.addEventListener('keyup',e=>{if(e.key==='Escape')post('close')});
$('runSearch').onclick=()=>post('search',{query:$('query').value});$('query').addEventListener('keyup',e=>{if(e.key==='Enter')$('runSearch').click()});
$('createReport').onclick=()=>post('createReport',{title:$('reportTitle').value,classification:$('classification').value,narrative:$('narrative').value});
$('addWatch').onclick=()=>post('addWatchlist',{subjectType:$('subjectType').value,subjectKey:$('subjectKey').value,label:$('subjectLabel').value,priority:$('watchPriority').value,reason:$('watchReason').value});
$('addLink').onclick=()=>post('addLink',{reportId:$('linkReport').value,entityType:$('linkType').value,entityKey:$('linkKey').value,relationship:$('relationship').value});
$('watchList').addEventListener('click',e=>{if(e.target.dataset.clear)post('clearWatchlist',{id:e.target.dataset.clear})});
function alertClick(e){if(!e.target.dataset.alert)return;post('dispatchAlert',{subject:e.target.dataset.alert,title:`Crime Intelligence Alert: ${e.target.dataset.label}`,description:`Intelligence attention requested for ${e.target.dataset.label}.`,priority:2})}
$('people').addEventListener('click',alertClick);$('vehicles').addEventListener('click',alertClick);
