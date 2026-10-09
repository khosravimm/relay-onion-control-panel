unit LocalizationV3;

interface

uses
  System.SysUtils, System.Classes, System.IniFiles;

type
  TTextDirection = (tdLeftToRight, tdRightToLeft);
  TLocalizationV3 = class
  private
    FRoot: string;
    FLocale: string;
    FFallbackLocale: string;
    function ResourcePath(const ALocale: string): string;
    function ReadValue(const ALocale, AKey: string): string;
  public
    constructor Create(const AResourcesDirectory: string);
    procedure SelectLocale(const ALocale: string);
    function Text(const AKey: string): string;
    function FormatText(const AKey: string; const Args: array of const): string;
    function Direction: TTextDirection;
    function AvailableLocales: TStringList;
    property Locale: string read FLocale;
  end;

implementation

constructor TLocalizationV3.Create(const AResourcesDirectory: string);
begin
  inherited Create;
  FRoot := IncludeTrailingPathDelimiter(AResourcesDirectory);
  FFallbackLocale := 'en-US';
  FLocale := 'fa-IR';
end;

function TLocalizationV3.ResourcePath(const ALocale: string): string;
var
  I: Integer;
begin
  // Only BCP-47 ASCII letters, digits and hyphens are permitted in file names.
  if (ALocale = '') or (Length(ALocale) > 35) then
    raise EArgumentException.Create('Invalid locale identifier');
  for I := 1 to Length(ALocale) do
    if not CharInSet(ALocale[I], ['A'..'Z', 'a'..'z', '0'..'9', '-']) then
      raise EArgumentException.Create('Invalid locale identifier');
  Result := FRoot + ALocale + '.ini';
end;

procedure TLocalizationV3.SelectLocale(const ALocale: string);
var
  FileName: string;
begin
  FileName := ResourcePath(ALocale);
  if not FileExists(FileName) then
    raise EFileNotFoundException.CreateFmt('Language pack missing: %s', [ALocale]);
  FLocale := ALocale;
end;

function TLocalizationV3.ReadValue(const ALocale, AKey: string): string;
var
  Ini: TMemIniFile;
begin
  Result := '';
  if not FileExists(ResourcePath(ALocale)) then Exit;
  Ini := TMemIniFile.Create(ResourcePath(ALocale), TEncoding.UTF8);
  try
    Result := Ini.ReadString('strings', AKey, '');
  finally
    Ini.Free;
  end;
end;

function TLocalizationV3.Text(const AKey: string): string;
begin
  Result := ReadValue(FLocale, AKey);
  if (Result = '') and (FLocale <> FFallbackLocale) then
    Result := ReadValue(FFallbackLocale, AKey);
  if Result = '' then
    Result := '[' + AKey + ']';
end;

function TLocalizationV3.FormatText(const AKey: string;
  const Args: array of const): string;
begin
  Result := System.SysUtils.Format(Text(AKey), Args);
end;

function TLocalizationV3.Direction: TTextDirection;
var
  Ini: TMemIniFile;
  DirectionName: string;
begin
  Result := tdLeftToRight;
  if not FileExists(ResourcePath(FLocale)) then Exit;
  Ini := TMemIniFile.Create(ResourcePath(FLocale), TEncoding.UTF8);
  try
    DirectionName := Ini.ReadString('meta', 'direction', 'ltr');
    if SameText(DirectionName, 'rtl') then Result := tdRightToLeft;
  finally
    Ini.Free;
  end;
end;

function TLocalizationV3.AvailableLocales: TStringList;
var
  Search: TSearchRec;
  Ini: TMemIniFile;
  Code: string;
begin
  Result := TStringList.Create;
  if FindFirst(FRoot + '*.ini', faAnyFile, Search) = 0 then
  try
    repeat
      Code := ChangeFileExt(Search.Name, '');
      try
        Ini := TMemIniFile.Create(ResourcePath(Code), TEncoding.UTF8);
        try
          if Ini.ReadString('meta', 'name', '') <> '' then
            Result.Add(Code);
        finally
          Ini.Free;
        end;
      except
        on EArgumentException do ; // Skip invalid file names.
      end;
    until FindNext(Search) <> 0;
  finally
    FindClose(Search);
  end;
  Result.Sort;
end;

end.
