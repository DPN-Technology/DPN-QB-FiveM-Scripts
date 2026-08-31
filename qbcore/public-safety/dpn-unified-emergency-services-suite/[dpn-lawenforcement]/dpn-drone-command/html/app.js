const app=document.getElementById('app');
const res=()=>GetParentResourceName();
function post(name,data={}){fetch(`https://${res()}/${name}`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)})}
function closeUI(){post('close')}
function recall(){post('recall')}
function scan(){post('scan')}
function alertDispatch(){post('alert',{title:'Drone Operator Alert',description:'Drone operator requested dispatch attention.'})}
window.addEventListener('message',e=>{const d=e.data;if(d.type==='open')app.classList.remove('hidden');if(d.type==='close')app.classList.add('hidden');if(d.type==='telemetry'){let b=Math.floor(d.battery||0);document.getElementById('battery').textContent=b+'%';document.getElementById('bar').style.width=b+'%';document.getElementById('mode').textContent=d.thermal?'THERMAL':d.night?'NIGHT':'NORMAL';document.getElementById('lock').textContent=d.locked?'YES':'NO';if(d.coords)document.getElementById('coords').textContent=`${d.coords.x.toFixed(1)}, ${d.coords.y.toFixed(1)}, ${d.coords.z.toFixed(1)}`;}if(d.type==='scan'){document.getElementById('scan').textContent=`Vehicles: ${d.vehicles} | Pedestrians: ${d.peds}`;}});
document.addEventListener('keydown',e=>{if(e.key==='Escape')closeUI()});
