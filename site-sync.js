/* Piège Infernal Games : sauvegarde en ligne des jeux d'arcade (records, skins, pseudos).
   Même compte que Piège Infernal / Cubia / Ville Folle (clé 'piege-cu' : pseudo + PIN).
   Les records ne baissent jamais : on garde toujours le meilleur des deux (appareil / en ligne). */
window.SITE=(function(){
 const URL='https://sbnkndyvmhmfyijilmqd.supabase.co',KEY='sb_publishable_aXvh-KEaBdyCWFpHaWI0IQ_g2rKlVAd';
 const LS=window.localStorage,KEYRX=/^g-/;
 const get=k=>{try{return LS.getItem(k)}catch(e){return null}},set=(k,v)=>{try{LS.setItem(k,v)}catch(e){}};
 const acct=()=>{try{const a=JSON.parse(get('piege-cu')||'null');return a&&a.p&&a.pin?a:null}catch(e){return null}};
 async function rpc(fn,args,keep){const h={'apikey':KEY,'Content-Type':'application/json'};
  const r=await fetch(URL+'/rest/v1/rpc/'+fn,{method:'POST',headers:h,body:JSON.stringify(args),keepalive:!!keep});if(!r.ok)throw new Error('http '+r.status);return r.json()}
 function collect(){const o={};for(let i=0;i<LS.length;i++){const k=LS.key(i);if(KEYRX.test(k))o[k]=get(k)}return o}
 const num=v=>v!==null&&v!==''&&!isNaN(+v)&&isFinite(+v);
 function parse(v){try{const o=JSON.parse(v);return o&&typeof o==='object'&&!Array.isArray(o)?o:null}catch(e){return null}}
 function mergeVal(a,b){if(a==null)return b;if(b==null)return a;
  if(num(a)&&num(b))return String(Math.max(+a,+b));
  const oa=parse(a),ob=parse(b);if(oa&&ob){const o=Object.assign({},ob,oa);for(const k in ob)if(typeof ob[k]==='number'&&typeof oa[k]==='number')o[k]=Math.max(oa[k],ob[k]);return JSON.stringify(o)}
  return a} // texte (pseudo, skin…) : on garde celui de l'appareil
 function merge(loc,cl){const o={};for(const k of new Set(Object.keys(loc).concat(Object.keys(cl||{}))))if(KEYRX.test(k)){const v=mergeVal(loc[k],cl?cl[k]:null);if(v!=null)o[k]=v}return o}
 let state='off',busy=false,lastPush='';
 async function pull(){const a=acct();if(!a)return state='off';
  const r=await rpc('site_load',{p_pseudo:a.p,p_pin:a.pin});if(!r||!r.ok){state=r&&r.err==='bad'?'badlogin':'net';return state}
  let cl=null;try{cl=r.data?JSON.parse(r.data):null}catch(e){}
  const m=merge(collect(),cl);for(const k in m)if(get(k)!==m[k])set(k,m[k]);state='ok';return state}
 async function push(keep){const a=acct();if(!a)return;const d=JSON.stringify(collect());if(d===lastPush)return;
  const r=await rpc('site_save',{p_pseudo:a.p,p_pin:a.pin,p_data:d},keep);if(r&&r.ok){lastPush=d;state='ok'}else state=r&&r.err==='bad'?'badlogin':'net'}
 async function sync(){if(busy)return state;busy=true;try{await pull();if(state==='ok')await push()}catch(e){state='net'}busy=false;
  try{window.dispatchEvent(new Event('site-sync'))}catch(e){}if(typeof window.menuBest==='function')try{window.menuBest()}catch(e){}return state}
 // à l'ouverture : on récupère ; en quittant ou en changeant d'appli : on envoie
 if(acct())setTimeout(sync,300);
 const bye=()=>{if(acct())push(true).catch(()=>{})};
 addEventListener('pagehide',bye);document.addEventListener('visibilitychange',()=>{if(document.hidden)bye()});
 setInterval(()=>{if(acct()&&!document.hidden)push().catch(()=>{})},45000);
 return{acct,sync,push,pull,get state(){return state}};
})();
