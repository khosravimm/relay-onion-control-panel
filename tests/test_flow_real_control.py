import socket, subprocess, pathlib, tempfile, time, os
ROOT=pathlib.Path(__file__).resolve().parents[1]
BUNDLE=pathlib.Path(os.environ.get('FLOW_TEST_BUNDLE', str(ROOT/'release/RelayOnionControlPanel-2.13.8.0-TorExpertBundle-15.0.24-windows-x64')))
with tempfile.TemporaryDirectory(prefix='flow-tor-wire-') as temp:
 temp=pathlib.Path(temp)
 with socket.socket() as reserve:
  reserve.bind(('127.0.0.1',0)); port=reserve.getsockname()[1]
 cfg=temp/'torrc'
 cfg.write_text(f'DataDirectory "{temp.as_posix()}"\nControlPort {port}\nSocksPort auto\nCookieAuthentication 1\nDisableNetwork 1\n')
 tor=subprocess.Popen([str(BUNDLE/'Tor/tor.exe'),'-f',str(cfg)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,creationflags=subprocess.CREATE_NO_WINDOW)
 try:
  for _ in range(50):
   if (temp/'control_auth_cookie').exists(): break
   time.sleep(.1)
  auth=(temp/'control_auth_cookie').read_bytes().hex()
  def query(cmd):
   with socket.create_connection(('127.0.0.1',port),timeout=3) as c:
    f=c.makefile('rb')
    c.sendall(('AUTHENTICATE '+auth+'\r\n').encode()); assert f.readline().startswith(b'250')
    c.sendall((cmd+'\r\n').encode()); lines=[]
    while True:
     line=f.readline().decode().rstrip(); lines.append(line)
     if len(line)>3 and line[3]==' ': break
    assert lines[-1].startswith('250 '), lines
    return lines
  before=query('GETCONF ExitNodes StrictNodes SocksPort HTTPTunnelPort DNSPort TransPort DisableNetwork')
  query('SETCONF SocksPort=0 HTTPTunnelPort="127.0.0.1:auto SessionGroup=123456789" __LeaveStreamsUnattached=1 DisableNetwork=0')
  listeners=query('GETINFO net/listeners/httptunnel')
  assert '127.0.0.1:' in listeners[0],listeners
  isolation=query('GETCONF HTTPTunnelPort __LeaveStreamsUnattached')
  assert any('SessionGroup=123456789' in line for line in isolation) and any('__LeaveStreamsUnattached=1' in line for line in isolation),isolation
  query('SETCONF SocksPort=auto HTTPTunnelPort=0 __LeaveStreamsUnattached=0 DisableNetwork=1')
  before=query('GETCONF ExitNodes StrictNodes SocksPort HTTPTunnelPort DNSPort TransPort DisableNetwork __LeaveStreamsUnattached')
  result=subprocess.run([str(ROOT/'artifacts/FlowExitFilterHarness.exe'),str(port),'seed-timeout',auth,str(temp/'cache.ini')],capture_output=True,text=True,timeout=25)
  print(result.stdout)
  assert result.returncode==0,result.stderr
  assert 'STATE=3' in result.stdout
  after=query('GETCONF ExitNodes StrictNodes SocksPort HTTPTunnelPort DNSPort TransPort DisableNetwork __LeaveStreamsUnattached')
  assert before==after,(before,after)
  result=subprocess.run([str(ROOT/'artifacts/FlowExitFilterHarness.exe'),str(port),'preflight-seed-timeout',auth,str(temp/'preflight-cache.ini')],capture_output=True,text=True,timeout=25)
  print(result.stdout)
  assert result.returncode==0,(result.stdout,result.stderr)
  assert 'STATE=4' in result.stdout
  after=query('GETCONF ExitNodes StrictNodes SocksPort HTTPTunnelPort DNSPort TransPort DisableNetwork __LeaveStreamsUnattached')
  assert before==after,(before,after)
  print('PASS: real Tor preflight stays pending beyond activation timeout and preserves normal configuration.')
  print('PASS: real Tor listener syntax, missing seed circuit waits with blocked listeners; exact settings restored, exact GETCONF restoration.')
 finally:
  tor.terminate(); tor.wait(timeout=10)

