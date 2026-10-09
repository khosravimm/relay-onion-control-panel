program RD3NetworkExclusivityTests;
{$APPTYPE CONSOLE}
uses Winapi.Windows, System.SysUtils, System.IOUtils, NetworkIntegration;
var M: TNetworkIntegrationManager; E, D: string;
begin
 D:=TPath.Combine(TPath.GetTempPath, 'rd3-isolation-test-'+IntToStr(GetTickCount));
 M:=TNetworkIntegrationManager.Create(TPath.GetTempPath, D, 0);
 try
  if M.Apply(True, True, '127.0.0.1', 9050, False, E) then Halt(1);
  if Pos('simultaneous', LowerCase(E))=0 then Halt(2);
  if M.SystemProxyActive or M.TunActive then Halt(3);
  Writeln('PASS: NetworkIntegration rejects simultaneous Proxy/TUN before mutation');
 finally
  M.Free;
  if TDirectory.Exists(D) then TDirectory.Delete(D, True);
 end;
end.
