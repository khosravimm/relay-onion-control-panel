import socket, threading, subprocess, tempfile, pathlib, shlex, time
ROOT=pathlib.Path(__file__).resolve().parents[1]
GOOD=[c*40 for c in 'ADEF1234569']; BAD='B'*40; FOREIGN='C'*40; PREFIX=['7'*40,'8'*40]
class Server:
 def __init__(self, mode):
  self.mode=mode; self.commands=[]; self.circuits={}; self.events=None; self.group=None
  self.ready_at=None; self.snapshots=[]; self.unknown=[]; self.extended=[]
  self.saved={'ExitNodes':['$'+'9'*40],'StrictNodes':['0'],
   'SocksPort':['127.0.0.1:19050 IsolateSOCKSAuth','[::1]:19050'],
   'HTTPTunnelPort':['0'],'DNSPort':['0'],'TransPort':['0'],
   'DisableNetwork':['0'],'__LeaveStreamsUnattached':['0']}
  self.config={k:list(v) for k,v in self.saved.items()}
  self.sock=socket.socket(); self.sock.bind(('127.0.0.1',0)); self.sock.listen(); self.port=self.sock.getsockname()[1]
  self.proxy=socket.socket(); self.proxy.bind(('127.0.0.1',0)); self.proxy.listen(); self.proxyport=self.proxy.getsockname()[1]; self.connects=[]
  threading.Thread(target=self.accept,daemon=True).start()
  threading.Thread(target=self.proxy_serve,daemon=True).start()
 def proxy_serve(self):
  while True:
   try:c,_=self.proxy.accept()
   except OSError:return
   with c:
    self.connects.append(c.recv(8192).decode(errors='replace'))
    c.sendall(b'HTTP/1.1 403 Forbidden\r\nContent-Length: 0\r\nConnection: close\r\n\r\n')
 def accept(self):
  while True:
   try:c,_=self.sock.accept()
   except OSError:return
   threading.Thread(target=self.serve,args=(c,),daemon=True).start()
 def inject(self):
  time.sleep(.08)
  if self.mode=='router-disconnect':
   self.events.shutdown(socket.SHUT_RDWR);return
  if self.mode=='background':
   self.events.sendall((f'650 STREAM 101 NEW 0 flow.google.com:443 SESSION_GROUP={self.group}\r\n'
    +'650 STREAM 102 NEW 0 example.com:443 SESSION_GROUP=-4\r\n'
    +f'650 STREAM 103 NEW 0 example.com:443 SOCKS_USERNAME="spoof SESSION_GROUP={self.group}" SESSION_GROUP=-4\r\n').encode())
 def serve(self,c):
  with c:
   f=c.makefile('rb')
   while True:
    raw=f.readline()
    if not raw:return
    cmd=raw.decode().strip(); self.commands.append(cmd)
    if cmd.startswith('AUTHENTICATE'):out='250 OK\r\n'
    elif cmd=='SETEVENTS STREAM':self.events=c;out='250 OK\r\n'
    elif cmd.startswith('GETCONF'):
     entries=[k+('='+v if v else '') for k in cmd.split()[1:] for v in self.config[k]]
     out=''.join('250-'+x+'\r\n' for x in entries)+'250 OK\r\n'
    elif cmd.startswith('SETCONF'):
     changes={}
     for token in shlex.split(cmd)[1:]:
      k,_,v=token.partition('=');changes.setdefault(k,[]).append(v)
     self.config.update(changes)
     for v in changes.get('HTTPTunnelPort',[]):
      if 'SessionGroup=' in v:self.group=int(v.split('SessionGroup=')[1])
     if self.config['SocksPort'][0].startswith('127.0.0.1:19050') and self.config['StrictNodes']==['1']:
      if self.ready_at is None:self.ready_at=len(self.extended)
     self.snapshots.append((cmd,{k:list(v) for k,v in self.config.items()}));out='250 OK\r\n'
    elif cmd.startswith('GETINFO consensus/'):
     value='2000-01-01 00:00:00' if cmd.endswith('valid-after') or self.mode=='expired' else '2099-10-11 00:00:00'
     out='250-'+cmd.split()[1]+'='+value+'\r\n250 OK\r\n'
    elif cmd.startswith('GETINFO ns/id/'):
     fp=cmd.split('/')[-1]; ip='192.0.2.2' if fp==FOREIGN else '192.0.2.1'
     if fp in PREFIX:ip=('198.51.100.1' if fp==PREFIX[0] else '203.0.113.1')
     flags='Exit Running Valid'+(' BadExit' if fp==BAD else '')
     out=f'250+ns/id/{fp}=\r\nr test ident digest 2026-10-11 00:00:00 {ip} 443 0\r\ns {flags}\r\n.\r\n250 OK\r\n'
    elif cmd.startswith('GETINFO md/id/'):
     extra=('family $'+PREFIX[0]+'\r\n') if self.mode=='family' else ''
     out='250+'+cmd.split()[1]+'=\r\nntor-onion-key test\r\n'+extra+'.\r\n250 OK\r\n'
    elif cmd=='GETINFO ns/all':out='250+ns/all=\r\n.\r\n250 OK\r\n'
    elif cmd.startswith('GETINFO ip-to-country/'):
     out='250-'+cmd.split()[1]+'='+('de' if cmd.endswith('.2') else 'us')+'\r\n250 OK\r\n'
    elif cmd.startswith('EXTENDCIRCUIT'):
     path=cmd.split()[2].split(',');fp=path[-1].lstrip('$');self.extended.append(fp)
     assert path[:2]==['$'+x for x in PREFIX] and cmd.endswith('purpose=controller'),cmd
     cid=str(10+len(self.extended));self.circuits[cid]=fp
     if len(self.extended)==4:threading.Thread(target=self.inject,daemon=True).start()
     out=f'250 EXTENDED {cid}\r\n'
    elif cmd=='GETINFO circuit-status':
     lines=['1 BUILT '+','.join('$'+x for x in PREFIX+['9'*40])+' PURPOSE=GENERAL']
     if self.ready_at is not None:lines.append('999 BUILT '+','.join('$'+x for x in PREFIX+[GOOD[0]])+' PURPOSE=GENERAL')
     for cid,fp in self.circuits.items():
      if self.mode=='wrong-circuit':fp='9'*40
      lines.append(cid+' BUILT '+','.join('$'+x for x in PREFIX+[fp])+' PURPOSE=CONTROLLER')
     out='250+circuit-status=\r\n'+'\r\n'.join(lines)+'\r\n.\r\n250 OK\r\n'
    elif cmd.startswith('CLOSECIRCUIT'):self.circuits.pop(cmd.split()[1],None);out='250 OK\r\n'
    elif cmd.startswith(('ATTACHSTREAM','CLOSESTREAM')):out='250 OK\r\n'
    elif cmd=='GETINFO net/listeners/httptunnel':out=f'250-net/listeners/httptunnel="127.0.0.1:{self.proxyport}"\r\n250 OK\r\n'
    else:self.unknown.append(cmd);out='552 Unexpected command\r\n'
    c.sendall(out.encode())
 def check(self,ready):
  assert not self.unknown,self.unknown
  assert self.config==self.saved,(self.config,self.saved)
  assert BAD not in self.extended and FOREIGN not in self.extended
  if ready:
   assert self.ready_at==3,(self.ready_at,self.commands)
   post=self.commands.index(next(c for c in self.commands if c.startswith('SETCONF SocksPort="127.0.0.1:19050')))
   assert any(c.startswith('EXTENDCIRCUIT') for c in self.commands[post:]),'No background discovery'
   for cmd,state in self.snapshots:
    if state['StrictNodes']==['1'] and state['SocksPort'][0]!='0':
     exits=state['ExitNodes'][0].split(',');assert len(exits)>=3 and all(x.lstrip('$') in GOOD for x in exits),exits
   blocks=[c for c in self.commands[post:] if c.startswith('SETCONF') and 'DisableNetwork=1' in c]
   if self.mode not in ['router-disconnect','fail-member']:assert len(blocks)==1,blocks # shutdown only
  else:assert self.ready_at is None,self.ready_at
  if self.mode=='background':
   assert 'CLOSECIRCUIT 999' not in self.commands[post:self.commands.index('SETCONF DisableNetwork=1',post)],'Healthy user circuit interrupted'
   assert 'ATTACHSTREAM 101 14' in self.commands and 'ATTACHSTREAM 102 0' in self.commands,self.commands
   assert 'ATTACHSTREAM 102 14' not in self.commands
   assert 'ATTACHSTREAM 103 0' in self.commands and 'ATTACHSTREAM 103 14' not in self.commands
  if self.mode=='cap':
   assert len(self.extended)==10,('Discovery continued past ten',self.extended)
   assert GOOD[10] not in self.extended
  if self.mode=='wire-deny':assert any('check.torproject.org:443' in x for x in self.connects)
  if self.mode=='router-disconnect':
   assert any(cmd.startswith('SETCONF SocksPort=0') and 'DisableNetwork=1' in cmd for cmd in self.commands[post:]),'Router loss did not block users'
  if self.mode=='fail-member':
   assert 'CLOSECIRCUIT 999' in self.commands[post:]
   assert any(state['SocksPort']==['0'] and state['StrictNodes']==['1'] and len(state['ExitNodes'][0].split(','))<3 for cmd,state in self.snapshots[5:])
  self.sock.close();self.proxy.close()

for mode in ['allow','cap','background','duplicate','deny','wrong-circuit','cancel','wire-deny','expired','family','router-disconnect','fail-member']:
 with tempfile.TemporaryDirectory(prefix='flow-pool-test-') as temp:
  s=Server(mode);testmode='positive-rejected' if mode=='wrong-circuit' else mode
  p=subprocess.run([str(ROOT/'artifacts/FlowExitFilterHarness.exe'),str(s.port),testmode,'00',str(pathlib.Path(temp)/'cache.ini')],capture_output=True,text=True,timeout=20)
  print(mode+': '+p.stdout.strip())
  assert p.returncode==0,(p.stdout,p.stderr,s.commands)
  s.check(mode in ['allow','cap','background','router-disconnect','fail-member'])
print('PASS: three distinct IP threshold; stop discovery at ten; background discovery; private/user stream isolation; strict pool; cancellation; exact restoration.')
