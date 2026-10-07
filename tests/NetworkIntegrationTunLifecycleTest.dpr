program NetworkIntegrationTunLifecycleTest;
{$APPTYPE CONSOLE}
uses System.SysUtils, System.IOUtils, Winapi.Windows, NetworkIntegration;
procedure Check(Ok: Boolean; const Msg: string);
begin if not Ok then raise Exception.Create(Msg); Writeln('PASS: ', Msg) end;
var M: TNetworkIntegrationManager; Dir, Err, Previous, Config: string; I, J: Integer;
begin
  try
    if ParamCount <> 2 then raise Exception.Create('Supply app directory and synthetic user directory');
    Dir := TPath.GetFullPath(ParamStr(2)); ForceDirectories(Dir);
    M := TNetworkIntegrationManager.Create(TPath.GetFullPath(ParamStr(1)), Dir, 0);
    try
      Previous := '';
      for I := 1 to 3 do
      begin
        Check(M.Apply(False, True, '127.0.0.1', 9050, True, Err), 'actual TUN start: ' + Err);
        Check(M.TunActive, 'TUN reported active after native route readiness');
        Config := TFile.ReadAllText(TPath.Combine(Dir, 'network\sing-box.json'));
        Check(Config <> Previous, 'new engine gets a fresh interface identity');
        for J := 1 to 20 do
          Check(M.Apply(False, True, '127.0.0.1', 9050, False, Err), 'real unchanged reapply: ' + Err);
        Check(TFile.ReadAllText(TPath.Combine(Dir, 'network\sing-box.json')) = Config,
          'reapply preserves configuration');
        Previous := Config;
        Check(M.Apply(False, False, '127.0.0.1', 9050, False, Err), 'explicit stop: ' + Err);
        Check(not M.TunActive, 'TUN state off after stop');
      end;
    finally M.Free end;
  except on E: Exception do begin Writeln('FAIL: ', E.Message); Halt(1) end end;
end.