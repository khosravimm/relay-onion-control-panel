program FlowNativeV3_Test;
{$APPTYPE CONSOLE}
uses
  System.SysUtils, System.Classes, System.Generics.Collections, System.IOUtils,
  System.NetEncoding, System.DateUtils, FlowNativeV3;
var
  UserDir, InstallRoot, ConsensusFile, CacheFile: string;
  Cache: TStringList;
  Lines: TStringList;
  Cands: TList<TFlowCandidateV3>;
  Parts: TArray<string>;
  C: TFlowCandidateV3;
  I, J, S, Ticks: Integer;
  PendingFP, PendingIP, M, ExitIP: string;
  Bytes: TBytes;
  OK: Boolean;
  Engine: TFlowNativeV3;
  ArrayData: TArray<TFlowCandidateV3>;
begin
  if ParamCount < 2 then
  begin
    Writeln('Usage: FlowNativeV3_Test.exe <InstallRoot> <TorUserDir>');
    Halt(2);
  end;
  InstallRoot := ParamStr(1);
  UserDir := ParamStr(2);
  CacheFile := TPath.Combine(UserDir, 'network-cache');
  ConsensusFile := TPath.Combine(UserDir, 'cached-microdesc-consensus');
  Cache := TStringList.Create;
  Lines := TStringList.Create;
  Cands := TList<TFlowCandidateV3>.Create;
  Engine := TFlowNativeV3.Create;
  try
    if not FileExists(CacheFile) or not FileExists(ConsensusFile) then
      raise Exception.Create('Tor network-cache or consensus unavailable');
    Cache.LoadFromFile(CacheFile);
    Lines.LoadFromFile(ConsensusFile);
    PendingFP := '';
    PendingIP := '';
    Randomize;
    for I := 0 to Lines.Count-1 do
    begin
      if Lines[I].StartsWith('r ') then
      begin
        Parts := Lines[I].Split([' '], TStringSplitOptions.ExcludeEmpty);
        PendingFP := '';
        if Length(Parts) > 5 then
        begin
          PendingIP := Parts[5];
          Bytes := TNetEncoding.Base64.DecodeStringToBytes(Parts[2]);
          for J := 0 to High(Bytes) do
            PendingFP := PendingFP + IntToHex(Bytes[J], 2);
        end;
      end
      else if (PendingFP <> '') and Lines[I].StartsWith('s ') then
      begin
        OK := (' ' + Lines[I] + ' ').Contains(' Exit ') and
          (' ' + Lines[I] + ' ').Contains(' Running ') and
          (' ' + Lines[I] + ' ').Contains(' Valid ') and
          not (' ' + Lines[I] + ' ').Contains(' BadExit');
        if OK then
          for J := 0 to Cache.Count - 1 do
            if Cache[J].StartsWith(PendingIP + ',us,') then
            begin
              C.Fingerprint := PendingFP;
              C.IPv4 := PendingIP;
              Cands.Add(C);
              Break;
            end;
        PendingFP := '';
      end;
    end;
    if Cands.Count = 0 then raise Exception.Create('No current US exit candidate');
    Writeln('LIVE_US_EXIT_CANDIDATES=', Cands.Count);
    ArrayData := Cands.ToArray;
    for I := High(ArrayData) downto 1 do
    begin
      J := Random(I+1);
      C := ArrayData[I]; ArrayData[I] := ArrayData[J]; ArrayData[J] := C;
    end;
    // Probe up to eight live, dynamically discovered exits; no fixed IPs.
    SetLength(ArrayData, 8);
    Writeln('TEST_EXIT=', ArrayData[0].IPv4);
    Engine.Start(InstallRoot, UserDir, ArrayData);
    for Ticks := 1 to 90 do
    begin
      Sleep(3000);
      Engine.Snapshot(S, M, ExitIP);
      Writeln('TICK=', Ticks, ' STATUS=', S, ' EXIT=', ExitIP, ' MESSAGE=', M);
      if S in [2,3] then Break;
    end;
    Engine.Stop;
    Writeln('TEST_STOPPED');
  finally
    Engine.Free;
    Cands.Free;
    Lines.Free;
    Cache.Free;
  end;
end.
