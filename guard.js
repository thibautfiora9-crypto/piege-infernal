/* Piège Infernal Games : statistiques de visite anonymes + écran « banni ».
   Enregistre seulement : la page, un identifiant d'appareil aléatoire, le type d'appareil et le pseudo si connecté. */
(function(){
  var URL='https://sbnkndyvmhmfyijilmqd.supabase.co',KEY='sb_publishable_aXvh-KEaBdyCWFpHaWI0IQ_g2rKlVAd';
  function get(k){try{return localStorage.getItem(k)}catch(e){return null}}
  function set(k,v){try{localStorage.setItem(k,v)}catch(e){}}
  var did=get('pi-did');if(!did||did.length<12){did='';var c='abcdefghijkmnpqrstuvwxyz23456789';for(var i=0;i<16;i++)did+=c[Math.floor(Math.random()*c.length)];set('pi-did',did)}
  var acct=null;try{acct=JSON.parse(get('piege-cu')||'null')}catch(e){}
  var ua=navigator.userAgent||'',dev=/iPad|Macintosh.*Mobile/.test(ua)||(/Macintosh/.test(ua)&&navigator.maxTouchPoints>1)?'iPad':/iPhone/.test(ua)?'iPhone':/Android/.test(ua)?'Android':/Mac/.test(ua)?'Mac':/Windows/.test(ua)?'Windows':/CrOS/.test(ua)?'Chromebook':'Autre';
  var page=(location.pathname.split('/').pop()||'index.html').replace(/\.html$/,'')||'index';
  function banScreen(b){if(document.getElementById('pi-ban'))return;var d=document.createElement('div');d.id='pi-ban';
    d.style.cssText='position:fixed;inset:0;z-index:2147483647;background:radial-gradient(circle,#2a0008,#050005);color:#fff;display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center;padding:24px;font-family:Inter,-apple-system,system-ui,sans-serif';
    var until=b.until?new Date(b.until):null,txt=until&&until.getFullYear()<9000?'jusqu’au '+until.toLocaleString('fr-FR',{dateStyle:'medium',timeStyle:'short'}):'définitivement';
    d.innerHTML='<div style="font-size:80px">🚫</div><div style="font:900 clamp(34px,8vw,64px) Impact,Oswald,sans-serif;letter-spacing:2px;color:#ff3d5a">TU ES BANNI</div><div style="font-size:18px;margin-top:10px;opacity:.9">Tu ne peux plus jouer sur Piège Infernal Games '+txt+'.</div>'+(b.reason?'<div style="margin-top:14px;padding:10px 16px;border-radius:12px;background:#ffffff14;font-size:16px">Raison : '+String(b.reason).replace(/[<>&]/g,'')+'</div>':'');
    (document.body||document.documentElement).appendChild(d);try{document.exitPointerLock&&document.exitPointerLock()}catch(e){}
    // coupe le son et les entrées
    ['keydown','keyup','mousedown','touchstart','pointerdown','click'].forEach(function(ev){addEventListener(ev,function(e){if(!d.contains(e.target)){e.stopImmediatePropagation();e.preventDefault()}},true)})}
  var cached=null;try{cached=JSON.parse(get('pi-ban')||'null')}catch(e){}
  if(cached&&(!cached.until||new Date(cached.until)>new Date()))document.readyState==='loading'?addEventListener('DOMContentLoaded',function(){banScreen(cached)}):banScreen(cached);
  if(location.hostname==='localhost'||location.hostname==='127.0.0.1')return; // pas de statistiques en test local
  fetch(URL+'/rest/v1/rpc/site_hello',{method:'POST',headers:{apikey:KEY,'Content-Type':'application/json'},body:JSON.stringify({p_did:did,p_pseudo:acct&&acct.p||null,p_page:page,p_ua:dev})})
    .then(function(r){return r.json()}).then(function(r){if(!r||!r.ok)return;if(r.banned){set('pi-ban',JSON.stringify({reason:r.reason,until:r.until}));banScreen(r)}else if(cached){try{localStorage.removeItem('pi-ban')}catch(e){};var o=document.getElementById('pi-ban');if(o)location.reload()}}).catch(function(){});
})();
