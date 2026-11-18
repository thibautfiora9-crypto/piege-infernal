/* Cubia : compte + sauvegarde en ligne + serveurs (partagé par cubia.html et blocs.html) */
window.CB=(function(){
 const SB={url:'https://sbnkndyvmhmfyijilmqd.supabase.co',key:'sb_publishable_aXvh-KEaBdyCWFpHaWI0IQ_g2rKlVAd'};
 const LS=window.localStorage;
 const get=k=>{try{return LS.getItem(k)}catch(e){return null}},set=(k,v)=>{try{LS.setItem(k,v)}catch(e){}};
 const to=(p,ms)=>Promise.race([p,new Promise((_,r)=>setTimeout(()=>r(new Error('timeout')),ms||15000))]);
 async function rpc(fn,args){const h={'apikey':SB.key,'Content-Type':'application/json'};if(/^eyJ/.test(SB.key))h.Authorization='Bearer '+SB.key;
  const r=await to(fetch(SB.url+'/rest/v1/rpc/'+fn,{method:'POST',headers:h,body:JSON.stringify(args||{})}),20000);if(!r.ok)throw new Error('http '+r.status);return r.json()}
 // compte : le même que Piège Infernal (clé 'piege-cu')
 const acct=()=>{try{const a=JSON.parse(get('piege-cu')||'null');return a&&a.p&&a.pin?a:null}catch(e){return null}};
 const setAcct=(p,pin)=>{set('piege-cu',JSON.stringify({p,pin}));set('piege-nick',p)};
 const logout=()=>{try{LS.removeItem('piege-cu')}catch(e){}};
 async function login(p,pin){const r=await rpc('gp_login',{p_pseudo:p,p_pin:pin});if(r&&r.ok){setAcct(r.pseudo||p,pin);return{ok:true,pseudo:r.pseudo||p}}return{ok:false,err:(r&&r.err)||'bad'}}
 async function register(p,pin){const r=await rpc('gp_register',{p_pseudo:p,p_pin:pin,p_data:{},p_stars:0,p_perfect:false,p_bt:{}});if(r&&r.ok){setAcct(p,pin);return{ok:true,pseudo:p}}return{ok:false,err:(r&&r.err)||'bad'}}
 // compression
 const b64=u8=>{let s='';for(let i=0;i<u8.length;i+=0x8000)s+=String.fromCharCode.apply(null,u8.subarray(i,i+0x8000));return btoa(s)};
 const unb64=s=>{const b=atob(s),u=new Uint8Array(b.length);for(let i=0;i<b.length;i++)u[i]=b.charCodeAt(i);return u};
 async function pack(str){const u=new TextEncoder().encode(str);if(window.CompressionStream){try{const cs=new CompressionStream('gzip'),w=cs.writable.getWriter();w.write(u);w.close();const buf=await new Response(cs.readable).arrayBuffer();return 'g:'+b64(new Uint8Array(buf))}catch(e){}}return 'r:'+b64(u)}
 async function unpack(s){if(!s)return'';const k=s.slice(0,2),u=unb64(s.slice(2));if(k==='g:'){const ds=new DecompressionStream('gzip'),w=ds.writable.getWriter();w.write(u);w.close();return new TextDecoder().decode(await new Response(ds.readable).arrayBuffer())}return new TextDecoder().decode(u)}
 // clés de la sauvegarde solo
 const skip=k=>k.indexOf('cubia')!==0||k.indexOf('cubia-tex')===0||k==='cubia-ctl'||k==='cubia-cloud-ts'||k==='cubia-local-ts';
 const soloKeys=()=>{const a=[];for(let i=0;i<LS.length;i++){const k=LS.key(i);if(!skip(k))a.push(k)}return a};
 const hasLocal=()=>!!get('cubia-save-v1');
 async function packLocal(){const o={};for(const k of soloKeys())o[k]=get(k);return pack(JSON.stringify(o))}
 async function applyPacked(s){const o=JSON.parse(await unpack(s));for(const k of soloKeys())try{LS.removeItem(k)}catch(e){}for(const k in o)if(!skip(k))set(k,o[k])}
 async function push(){const a=acct();if(!a)return{ok:false,err:'noacct'};if(!hasLocal())return{ok:false,err:'empty'};const d=await packLocal();const r=await rpc('cb_save',{p_pseudo:a.p,p_pin:a.pin,p_data:d});if(r&&r.ok){set('cubia-cloud-ts',String(r.ts||Date.now()));return{ok:true,size:d.length}}return{ok:false,err:(r&&r.err)||'bad'}}
 async function pull(){const a=acct();if(!a)return{ok:false,err:'noacct'};const r=await rpc('cb_load',{p_pseudo:a.p,p_pin:a.pin});if(!r||!r.ok)return{ok:false,err:(r&&r.err)||'bad'};if(!r.data)return{ok:true,none:true};return{ok:true,data:r.data,ts:r.ts||0}}
 // Synchronise au lancement : renvoie 'none' | 'loaded' | 'pushed' | 'conflict' | 'same'
 async function sync(askFn){const a=acct();if(!a)return'off';const c=await pull();if(!c.ok)return'err';
  const synced=+get('cubia-cloud-ts')||0,localTs=+get('cubia-local-ts')||0,hasL=hasLocal();
  if(c.none){if(hasL){const p=await push();return p.ok?'pushed':'err'}return'none'}
  if(c.ts>synced){ // le cloud a du nouveau
   if(hasL&&localTs>synced){const keepCloud=askFn?await askFn():true;if(!keepCloud){const p=await push();return p.ok?'pushed':'err'}}
   await applyPacked(c.data);set('cubia-cloud-ts',String(c.ts));return'loaded'}
  if(hasL&&localTs>synced){const p=await push();return p.ok?'pushed':'err'}
  return'same'}
 // serveurs
 const srv={
  create:async name=>{const a=acct();if(!a)return{ok:false,err:'noacct'};return rpc('cb_srv_create',{p_pseudo:a.p,p_pin:a.pin,p_name:name})},
  get:async code=>rpc('cb_srv_get',{p_code:code}),
  mine:async()=>{const a=acct();if(!a)return{ok:false,err:'noacct'};return rpc('cb_srv_mine',{p_pseudo:a.p,p_pin:a.pin})},
  del:async code=>{const a=acct();if(!a)return{ok:false,err:'noacct'};return rpc('cb_srv_delete',{p_pseudo:a.p,p_pin:a.pin,p_code:code})},
  save:async(code,editsStr)=>{const a=acct();if(!a)return{ok:false,err:'noacct'};return rpc('cb_srv_save',{p_pseudo:a.p,p_pin:a.pin,p_code:code,p_edits:await pack(editsStr)})}
 };
 return{SB,rpc,acct,setAcct,logout,login,register,pack,unpack,push,pull,sync,srv,hasLocal,get,set};
})();
