program FlowCatalogV3_Test;
{$APPTYPE CONSOLE}
uses System.SysUtils, FlowNativeV3, FlowCatalogV3;
var Candidates: TArray<TFlowCandidateV3>;
begin
  if ParamCount <> 1 then Halt(2);
  Candidates := TFlowCatalogV3.FromCache(ParamStr(1));
  Writeln('DYNAMIC_US_EXIT_COUNT=', Length(Candidates));
  if Length(Candidates) = 0 then Halt(1);
end.
