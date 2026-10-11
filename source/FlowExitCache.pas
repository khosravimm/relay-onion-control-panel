unit FlowExitCache;

interface

uses Winapi.Windows, System.SysUtils, System.Classes, System.IniFiles,
  System.Generics.Collections, System.Generics.Defaults, System.DateUtils;

type
  TFlowCacheEntry = record
    ActualIP: string;
    LastSuccessUtc, LatencyMs: Int64;
    Successes, Failures: Integer;
    LastPassed: Boolean;
  end;

  // Hints only: cache entries never populate the active exit pool.
  TFlowExitCache = class
  private
    FPath: string;
    FEntries: TDictionary<string, TFlowCacheEntry>;
    class function ValidFingerprint(const Value: string): Boolean; static;
    procedure Load;
  public
    constructor Create(const Path: string);
    destructor Destroy; override;
    class function UtcNow: Int64; static;
    function OrderedHints: TArray<string>;
    procedure RecordSuccess(const FP, ActualIP: string; LatencyMs: Int64);
    procedure RecordFailure(const FP: string);
    procedure Save;
  end;

implementation

const
  FRESH_SECONDS = 86400;
  MAX_AGE_SECONDS = 7 * FRESH_SECONDS;
  MAX_CACHE_ENTRIES = 100;

class function TFlowExitCache.UtcNow: Int64;
begin
  Result := DateTimeToUnix(TTimeZone.Local.ToUniversalTime(Now));
end;

class function TFlowExitCache.ValidFingerprint(const Value: string): Boolean;
var C: Char;
begin
  Result := Length(Value) = 40;
  if Result then
    for C in Value do
      if not CharInSet(C, ['0'..'9', 'A'..'F', 'a'..'f']) then Exit(False);
end;

constructor TFlowExitCache.Create(const Path: string);
begin
  inherited Create;
  FPath := Path;
  FEntries := TDictionary<string, TFlowCacheEntry>.Create;
  try Load;
  except
    // A damaged cache must not prevent fresh discovery.
    FEntries.Clear;
  end;
end;

destructor TFlowExitCache.Destroy;
begin
  FEntries.Free;
  inherited;
end;

procedure TFlowExitCache.Load;
var Ini: TMemIniFile; FP, RawFP, Section, List: string; Entry: TFlowCacheEntry;
    Stamp: Int64;
begin
  Stamp := UtcNow;
  Ini := TMemIniFile.Create(FPath, TEncoding.UTF8);
  try
    List := Ini.ReadString('Flow', 'Fingerprints', Ini.ReadString('Flow', 'Fingerprint', ''));
    for RawFP in List.Split([',']) do
    begin
      FP := UpperCase(Trim(RawFP));
      if not ValidFingerprint(FP) or FEntries.ContainsKey(FP) then Continue;
      Entry := Default(TFlowCacheEntry);
      Section := 'Exit.' + FP;
      if Ini.SectionExists(Section) then
      begin
        if Ini.ReadString(Section, 'Country', '') <> 'us' then Continue;
        Entry.ActualIP := Ini.ReadString(Section, 'ActualIP', '');
        Entry.LastSuccessUtc := StrToInt64Def(Ini.ReadString(Section, 'LastSuccessUtc', ''), 0);
        Entry.LatencyMs := StrToInt64Def(Ini.ReadString(Section, 'FlowLatencyMs', ''), 0);
        Entry.Successes := Ini.ReadInteger(Section, 'Successes', 0);
        Entry.Failures := Ini.ReadInteger(Section, 'Failures', 0);
        Entry.LastPassed := Ini.ReadBool(Section, 'LastPassed', False);
        if (Entry.ActualIP = '') or (Entry.LastSuccessUtc <= 0) or
          (Entry.LastSuccessUtc > Stamp) or (Stamp - Entry.LastSuccessUtc > MAX_AGE_SECONDS) or
          (Entry.LatencyMs <= 0) or (Entry.LatencyMs > 300000) or
          (Entry.Successes < 1) or (Entry.Successes > 1000000) or
          (Entry.Failures < 0) or (Entry.Failures > 1000000) then Continue;
      end;
      // Older releases only stored fingerprints: retain these as low-priority hints.
      FEntries.Add(FP, Entry);
      if FEntries.Count >= MAX_CACHE_ENTRIES then Break;
    end;
  finally Ini.Free end;
end;

function CacheRank(const Entry: TFlowCacheEntry; Stamp: Int64): Integer;
begin
  if Entry.LastSuccessUtc = 0 then Exit(3);
  if not Entry.LastPassed then Exit(2);
  if Stamp - Entry.LastSuccessUtc <= FRESH_SECONDS then Exit(0);
  Result := 1;
end;

function TFlowExitCache.OrderedHints: TArray<string>;
var Items: TList<string>; Pair: TPair<string, TFlowCacheEntry>; Stamp: Int64;
begin
  Stamp := UtcNow;
  Items := TList<string>.Create;
  try
    for Pair in FEntries do
      if (Pair.Value.LastSuccessUtc = 0) or
        ((Pair.Value.LastSuccessUtc <= Stamp) and
         (Stamp - Pair.Value.LastSuccessUtc <= MAX_AGE_SECONDS)) then Items.Add(Pair.Key);
    Items.Sort(TComparer<string>.Construct(
      function(const Left, Right: string): Integer
      var A, B: TFlowCacheEntry;
      begin
        A := FEntries[Left]; B := FEntries[Right];
        Result := CacheRank(A, Stamp) - CacheRank(B, Stamp);
        if Result <> 0 then Exit;
        if A.LatencyMs < B.LatencyMs then Exit(-1);
        if A.LatencyMs > B.LatencyMs then Exit(1);
        if A.Failures < B.Failures then Exit(-1);
        if A.Failures > B.Failures then Exit(1);
        if A.LastSuccessUtc > B.LastSuccessUtc then Exit(-1);
        if A.LastSuccessUtc < B.LastSuccessUtc then Exit(1);
        Result := CompareStr(Left, Right);
      end));
    while Items.Count > MAX_CACHE_ENTRIES do Items.Delete(Items.Count - 1);
    Result := Items.ToArray;
  finally Items.Free end;
end;

procedure TFlowExitCache.RecordSuccess(const FP, ActualIP: string; LatencyMs: Int64);
var Entry: TFlowCacheEntry;
begin
  if not ValidFingerprint(FP) or (ActualIP = '') or (LatencyMs <= 0) then Exit;
  if not FEntries.TryGetValue(UpperCase(FP), Entry) then Entry := Default(TFlowCacheEntry);
  if (Entry.LatencyMs > 0) and (Entry.ActualIP = ActualIP) then
    Entry.LatencyMs := (3 * Entry.LatencyMs + LatencyMs) div 4
  else Entry.LatencyMs := LatencyMs;
  Entry.ActualIP := ActualIP;
  Entry.LastSuccessUtc := UtcNow;
  Entry.LastPassed := True;
  if Entry.Successes < 1000000 then Inc(Entry.Successes);
  FEntries.AddOrSetValue(UpperCase(FP), Entry);
end;

procedure TFlowExitCache.RecordFailure(const FP: string);
var Entry: TFlowCacheEntry;
begin
  if not FEntries.TryGetValue(UpperCase(FP), Entry) then Exit;
  Entry.LastPassed := False;
  if Entry.Failures < 1000000 then Inc(Entry.Failures);
  FEntries.AddOrSetValue(UpperCase(FP), Entry);
end;

procedure TFlowExitCache.Save;
var Ini: TMemIniFile; FP, Section, Temp: string; Entry: TFlowCacheEntry;
    Hints: TArray<string>;
begin
  Hints := OrderedHints;
  Temp := FPath + '.tmp';
  Ini := TMemIniFile.Create(Temp, TEncoding.UTF8);
  try
    Ini.Clear;
    Ini.WriteInteger('Flow', 'SchemaVersion', 2);
    Ini.WriteString('Flow', 'Fingerprints', string.Join(',', Hints));
    for FP in Hints do
    begin
      Entry := FEntries[FP];
      if Entry.LastSuccessUtc = 0 then Continue;
      Section := 'Exit.' + FP;
      Ini.WriteString(Section, 'Country', 'us');
      Ini.WriteString(Section, 'ActualIP', Entry.ActualIP);
      Ini.WriteString(Section, 'LastSuccessUtc', IntToStr(Entry.LastSuccessUtc));
      Ini.WriteString(Section, 'FlowLatencyMs', IntToStr(Entry.LatencyMs));
      Ini.WriteInteger(Section, 'Successes', Entry.Successes);
      Ini.WriteInteger(Section, 'Failures', Entry.Failures);
      Ini.WriteBool(Section, 'LastPassed', Entry.LastPassed);
    end;
    Ini.UpdateFile;
  finally Ini.Free end;
  if not MoveFileEx(PChar(Temp), PChar(FPath), MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH) then
    RaiseLastOSError;
end;

end.
