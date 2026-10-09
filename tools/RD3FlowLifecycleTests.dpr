program RD3FlowLifecycleTests;
{$APPTYPE CONSOLE}
uses System.SysUtils, FlowNativeV3;
var E: TFlowNativeV3; C: TArray<TFlowCandidateV3>; I, S: Integer; Msg, IP: string;
begin
 E:=TFlowNativeV3.Create;
 try
  SetLength(C,0);
  for I:=1 to 100 do
  begin
   E.Start('','',C);
   E.Snapshot(S,Msg,IP);
   if S<>3 then Halt(1);
   if Pos('no candidate',LowerCase(Msg))=0 then Halt(2);
   E.Stop;
   E.Snapshot(S,Msg,IP);
   if S<>0 then Halt(3);
  end;
  Writeln('RD3 FLOW PROFILE LIFECYCLE: PASS (100 load-reject/unload cycles, no process started)');
 finally E.Free end;
end.
