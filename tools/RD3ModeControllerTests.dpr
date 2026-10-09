program RD3ModeControllerTests;
{$APPTYPE CONSOLE}
uses System.SysUtils, RD3ModeController;
var C: TRD3ModeController; T, T2: Cardinal; R: string; S: TRD3Snapshot; I: Integer;
begin
 C:=TRD3ModeController.Create;
 try
  if not C.BeginTransition(rmFlow,T,R) then Halt(1);
  if C.BeginTransition(rmTun,T2,R) then Halt(2);
  if C.Mode<>rmOff then Halt(3);
  if C.Commit(T,rmTun) then Halt(4);
  if not C.Rollback(T) then Halt(5);
  for I:=1 to 100 do begin
   if not C.BeginTransition(rmFlow,T,R) then Halt(6);
   if not C.Commit(T,rmFlow) then Halt(7);
   if not C.BeginTransition(rmOff,T,R) then Halt(8);
   if not C.Commit(T,rmOff) then Halt(9);
  end;
  S:=C.Snapshot;
  if C.RestoreAfterCrash(S,R) then Halt(10);
  if C.Phase<>rpRecovering then Halt(11);
  Writeln('PASS: RD3-S1; 100 transitions; overlap, rollback, wrong token and crash fail-closed');
 finally C.Free end;
end.
