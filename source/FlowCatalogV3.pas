unit FlowCatalogV3;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  System.NetEncoding, System.IOUtils, FlowNativeV3;

type
  TFlowCatalogV3 = class
  public
    // Reads the application's existing Tor network-cache and consensus.
    // This is only a discovery source: all candidates must be retested live.
    class function FromCache(const UserDir: string): TArray<TFlowCandidateV3>; static;
  end;

implementation

class function TFlowCatalogV3.FromCache(
  const UserDir: string): TArray<TFlowCandidateV3>;
var
  US: TDictionary<string, Boolean>;
  Nodes, Cache: TStringList;
  P: TArray<string>;
  Line, FlagsLine, IP, FP: string;
  B: TBytes;
  I, J: Integer;
  C: TFlowCandidateV3;
  Items: TList<TFlowCandidateV3>;
begin
  Result := nil;
  if not FileExists(TPath.Combine(UserDir, 'network-cache')) or
     not FileExists(TPath.Combine(UserDir, 'cached-microdesc-consensus')) then
    Exit;
  US := TDictionary<string, Boolean>.Create;
  Cache := TStringList.Create;
  Nodes := TStringList.Create;
  Items := TList<TFlowCandidateV3>.Create;
  try
    Cache.LoadFromFile(TPath.Combine(UserDir, 'network-cache'));
    for Line in Cache do
    begin
      P := Line.Split([',']);
      if (Length(P) > 1) and SameText(P[1], 'us') and (P[0] <> '') then
        US.AddOrSetValue(P[0], True);
    end;
    Nodes.LoadFromFile(TPath.Combine(UserDir, 'cached-microdesc-consensus'));
    FP := '';
    IP := '';
    for I := 0 to Nodes.Count - 1 do
    begin
      if Nodes[I].StartsWith('r ') then
      begin
        P := Nodes[I].Split([' '], TStringSplitOptions.ExcludeEmpty);
        FP := '';
        IP := '';
        if Length(P) > 5 then
        begin
          IP := P[5];
          if US.ContainsKey(IP) then
          try
            B := TNetEncoding.Base64.DecodeStringToBytes(P[2]);
            if Length(B) = 20 then
              for J := 0 to High(B) do
                FP := FP + IntToHex(B[J], 2);
          except
            FP := '';
          end;
        end;
      end
      else if (FP <> '') and Nodes[I].StartsWith('s ') then
      begin
        FlagsLine := ' ' + Nodes[I] + ' ';
        if (Pos(' Exit ', FlagsLine) > 0) and
           (Pos(' Running ', FlagsLine) > 0) and
           (Pos(' Valid ', FlagsLine) > 0) and
           (Pos(' BadExit ', FlagsLine) = 0) then
        begin
          C.IPv4 := IP;
          C.Fingerprint := FP;
          Items.Add(C);
        end;
        FP := '';
      end;
    end;
    Result := Items.ToArray;
  finally
    Items.Free;
    Nodes.Free;
    Cache.Free;
    US.Free;
  end;
end;

end.
