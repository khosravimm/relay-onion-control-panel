program RD3SelectedExitTests;
{$APPTYPE CONSOLE}
uses Winapi.Windows, System.SysUtils, System.IOUtils, System.IniFiles, FlowNativeV3;
var A,B:TArray<TFlowCandidateV3>;D,F:string; I:TMemIniFile;
begin
 D:=TPath.Combine(TPath.GetTempPath,'rd3-profile-test-'+IntToStr(GetCurrentProcessId));
 ForceDirectories(TPath.Combine(D,'RelayOnionControlPanel\FlowV3Native'));
 SetEnvironmentVariable('LOCALAPPDATA',PChar(D));
 SetLength(A,2);
 A[0].Fingerprint:=StringOfChar('A',40);A[0].IPv4:='1.2.3.4';
 A[1].Fingerprint:=StringOfChar('B',40);A[1].IPv4:='5.6.7.8';
 B:=TFlowNativeV3.PrioritizeCached(A);
 if Length(B)<>2 then Halt(1);
 F:=TPath.Combine(D,'RelayOnionControlPanel\FlowV3Native\Flow.ini');
 I:=TMemIniFile.Create(F,TEncoding.UTF8);
 try
  I.WriteString('Routers','ExitNodes','$'+A[1].Fingerprint);
  I.WriteString('RelayIPs',A[1].Fingerprint,A[1].IPv4);
  I.UpdateFile;
 finally I.Free end;
 B:=TFlowNativeV3.PrioritizeCached(A);
 if (Length(B)<>1) or (B[0].IPv4<>A[1].IPv4) then Halt(2);
 Writeln('PASS: Flow profile selected ExitNodes restrict candidates to only selected relays');
end.
