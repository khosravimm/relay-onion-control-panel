program MachineInterfacePolicyTest;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  System.IniFiles,
  System.IOUtils,
  MachineInterface in '..\source\MachineInterface.pas';

procedure Check(Condition: Boolean; const Msg: string);
begin
  if not Condition then
    raise Exception.Create(Msg);
end;

var
  S, S2: TTcpMachineSettings;
  K: TTcpApiKeyMaterial;
  Ini: TMemIniFile;
  FileName, ErrorText, Raw: string;
begin
  S := TTcpMachineSettings.Create;
  try
    Check(not S.Enabled, 'machine interface must default disabled');
    Check(not S.ApiEnabled, 'API must default disabled');
    Check(S.ApiBindAddress = '127.0.0.1', 'API bind default must be loopback');
    Check(S.ApiAllowLoopbackWithoutKey, 'loopback must default to no key required');
    Check(not TTcpApiKeyPolicy.RequiresKey('127.0.0.1', S), '127.0.0.1 should not require key by default');
    Check(not TTcpApiKeyPolicy.RequiresKey('::1', S), 'IPv6 loopback should not require key by default');
    Check(TTcpApiKeyPolicy.RequiresKey('192.168.1.10', S), 'non-loopback must require key');
    Check(TTcpApiKeyPolicy.RequiresKey('', S), 'unknown source must require key');

    K := TTcpApiKeyPolicy.GenerateKey;
    Check(K.PlainText.StartsWith('tcp_'), 'generated key prefix');
    Check(K.Hash <> '', 'generated key hash');
    Check(TTcpApiKeyPolicy.ValidateKey(K.PlainText, K.Hash), 'generated key must validate');
    Check(not TTcpApiKeyPolicy.ValidateKey(K.PlainText + 'x', K.Hash), 'wrong key must fail');

    S.ApiKeyHash := K.Hash;
    S.ApiKeyId := K.KeyId;
    S.ApiKeyCreatedAt := K.CreatedAt;
    Check(TTcpApiKeyPolicy.IsAuthorized('127.0.0.1', '', S), 'loopback no-key authorization');
    Check(TTcpApiKeyPolicy.IsAuthorized('10.1.2.3', K.PlainText, S), 'remote valid-key authorization');
    Check(not TTcpApiKeyPolicy.IsAuthorized('10.1.2.3', 'wrong', S), 'remote wrong-key rejection');

    S.ApiEnabled := True;
    S.ApiBindAddress := '0.0.0.0';
    Check(not S.Validate(ErrorText), 'remote bind must require explicit AllowRemote');
    S.ApiAllowRemote := True;
    Check(S.Validate(ErrorText), 'remote bind with explicit AllowRemote and key should validate');
    S.ApiKeyHash := '';
    Check(not S.Validate(ErrorText), 'remote bind without key must fail validation');
    S.ApiBindAddress := '127.0.0.1';
    S.ApiAllowRemote := False;
    Check(S.Validate(ErrorText), 'loopback bind without key should validate');

    FileName := IncludeTrailingPathDelimiter(GetEnvironmentVariable('TEMP')) + 'tcp-machine-interface-policy-test.ini';
    Ini := TMemIniFile.Create(FileName, TEncoding.UTF8);
    try
      S.ApiKeyHash := K.Hash;
      S.ApiKeyId := K.KeyId;
      S.ApiKeyCreatedAt := K.CreatedAt;
      S.Save(Ini);
      Ini.UpdateFile;
    finally
      Ini.Free;
    end;
    Raw := TFile.ReadAllText(FileName, TEncoding.UTF8);
    Check(Pos(K.PlainText, Raw) = 0, 'plaintext key must never be persisted');
    Check(Pos(K.Hash, LowerCase(Raw)) > 0, 'key hash must be persisted');

    S2 := TTcpMachineSettings.Create;
    try
      Ini := TMemIniFile.Create(FileName, TEncoding.UTF8);
      try
        S2.Load(Ini);
      finally
        Ini.Free;
      end;
      Check(S2.ApiKeyHash = K.Hash, 'key hash round-trip');
      Check(S2.ApiBindAddress = '127.0.0.1', 'bind round-trip');
      Check(S2.ApiAllowLoopbackWithoutKey, 'loopback policy round-trip');
    finally
      S2.Free;
    end;
    DeleteFile(FileName);
  finally
    S.Free;
  end;
  Writeln('PASS MachineInterfacePolicyTest');
end.
