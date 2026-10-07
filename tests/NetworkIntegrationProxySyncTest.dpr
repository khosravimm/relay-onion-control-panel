program NetworkIntegrationProxySyncTest;
{$APPTYPE CONSOLE}
uses Winapi.Windows, System.SysUtils, System.IOUtils, System.Win.Registry, NetworkIntegration;
type TTestManager = class(TNetworkIntegrationManager)
  public procedure Enable; procedure Restore;
end;
procedure TTestManager.Enable;
begin SaveProxySnapshot; ApplySystemProxy end;
procedure TTestManager.Restore;
begin RestoreSystemProxy end;
procedure Check(Value: Boolean; const Msg: string);
begin if not Value then raise Exception.Create(Msg); Writeln('PASS: ', Msg) end;
function ConnectionFlags: DWORD;
var R: TRegistry; B: TBytes;
begin
 R := TRegistry.Create(KEY_READ);
 try
  R.RootKey := HKEY_CURRENT_USER;
  Check(R.OpenKeyReadOnly('Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections'), 'connection settings readable');
  SetLength(B, R.GetDataSize('DefaultConnectionSettings'));
  R.ReadBinaryData('DefaultConnectionSettings', B[0], Length(B));
  Check(Length(B) >= 16, 'connection settings have flags');
  Move(B[8], Result, SizeOf(Result));
 finally R.Free end;
end;
var M: TTestManager; R: TRegistry; WasEnabled: Boolean; BeforeFlags: DWORD; Dir: string;
begin
 try
  Dir := TPath.Combine(TPath.GetTempPath, 'RelayOnion-ProxySync-' + IntToStr(GetCurrentProcessId));
  ForceDirectories(Dir);
  R := TRegistry.Create(KEY_READ);
  try R.RootKey := HKEY_CURRENT_USER;
   R.OpenKeyReadOnly('Software\Microsoft\Windows\CurrentVersion\Internet Settings');
   WasEnabled := R.ValueExists('ProxyEnable') and (R.ReadInteger('ProxyEnable') <> 0);
  finally R.Free end;
  BeforeFlags := ConnectionFlags;
  M := TTestManager.Create(Dir, Dir, 0);
  try
   try
    M.Enable;
    Check((ConnectionFlags and 2) <> 0, 'native connection proxy enabled');
    Check((ConnectionFlags and 12) = (BeforeFlags and 12), 'PAC and autodetection retained');
    M.Restore;
    Check(((ConnectionFlags and 2) <> 0) = WasEnabled, 'native connection proxy restored to saved state');
    Check(not FileExists(TPath.Combine(Dir, 'network\windows-proxy-state.ini')), 'snapshot removed after restore');
   finally M.Restore end;
  finally M.Free end;
 except on E: Exception do begin Writeln('FAIL: ', E.Message); Halt(1) end end;
end.