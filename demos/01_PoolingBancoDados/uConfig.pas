unit uConfig;

{$mode objfpc}{$H+}
{$CODEPAGE UTF8}

interface

uses
  SysUtils, Classes, IniFiles, SyncObjs;

type
  { TAppConfig: Gerenciador de configuracao do servico (.ini) }
  TAppConfig = class
  private
    FLock: TCriticalSection;
    FIniFileName: string;
    FPollingIntervalMs: Cardinal;
    FLogLevel: string;
    FDatabaseHost: string;
    FDatabasePort: Integer;
    FDatabaseName: string;
    FDatabaseUser: string;
    FDatabasePass: string;
    procedure EnsureDefaultsCreated(const AIniPath: string);
    class var FInstance: TAppConfig;
  public
    constructor Create;
    destructor Destroy; override;
    class function Instance: TAppConfig;
    class procedure ReleaseInstance;
    procedure Reload;
    property IniFileName: string read FIniFileName;
    property PollingIntervalMs: Cardinal read FPollingIntervalMs;
    property LogLevel: string read FLogLevel;
    property DatabaseHost: string read FDatabaseHost;
    property DatabasePort: Integer read FDatabasePort;
    property DatabaseName: string read FDatabaseName;
    property DatabaseUser: string read FDatabaseUser;
    property DatabasePass: string read FDatabasePass;
  end;

implementation

{ TAppConfig }

constructor TAppConfig.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FIniFileName := ExtractFilePath(ParamStr(0)) + 'SvcPoolBancoDados.ini';
  FPollingIntervalMs := 5000;
  FLogLevel := 'INFO';
  EnsureDefaultsCreated(FIniFileName);
  Reload;
end;

destructor TAppConfig.Destroy;
begin
  FreeAndNil(FLock);
  inherited Destroy;
end;

class function TAppConfig.Instance: TAppConfig;
begin
  if not Assigned(FInstance) then
    FInstance := TAppConfig.Create;
  Result := FInstance;
end;

class procedure TAppConfig.ReleaseInstance;
begin
  FreeAndNil(FInstance);
end;

procedure TAppConfig.EnsureDefaultsCreated(const AIniPath: string);
var
  Ini: TIniFile;
begin
  if not FileExists(AIniPath) then
  begin
    Ini := TIniFile.Create(AIniPath);
    try
      Ini.WriteInteger('SERVICE', 'PollingIntervalMs', 5000);
      Ini.WriteString('SERVICE', 'LogLevel', 'INFO');
  Ini.WriteString('DATABASE', 'Host', FDatabaseHost);
  Ini.WriteInteger('DATABASE', 'Port', FDatabasePort);
  Ini.WriteString('DATABASE', 'Database', FDatabaseName);
  Ini.WriteString('DATABASE', 'User', FDatabaseUser);
  Ini.WriteString('DATABASE', 'Password', FDatabasePass);
    finally
      FreeAndNil(Ini);
    end;
  end;
end;

procedure TAppConfig.Reload;
var
  Ini: TIniFile;
begin
  FLock.Enter;
  try
    if FileExists(FIniFileName) then
    begin
      Ini := TIniFile.Create(FIniFileName);
      try
        FPollingIntervalMs := Ini.ReadInteger('SERVICE', 'PollingIntervalMs', 5000);
        FLogLevel := Ini.ReadString('SERVICE', 'LogLevel', 'INFO');
  FDatabaseHost := Ini.ReadString('DATABASE', 'Host', '127.0.0.1');
  FDatabasePort := Ini.ReadInteger('DATABASE', 'Port', 3050);
  FDatabaseName := Ini.ReadString('DATABASE', 'Database', 'meu_banco.fdb');
  FDatabaseUser := Ini.ReadString('DATABASE', 'User', 'SYSDBA');
  FDatabasePass := Ini.ReadString('DATABASE', 'Password', 'masterkey');
      finally
        FreeAndNil(Ini);
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

initialization

finalization
  TAppConfig.ReleaseInstance;

end.
