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
    FHttpPort: Word;
    FBindAddress: string;
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
    property HttpPort: Word read FHttpPort;
    property BindAddress: string read FBindAddress;
  end;

implementation

{ TAppConfig }

constructor TAppConfig.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FIniFileName := ExtractFilePath(ParamStr(0)) + 'SvcApiMicroservico.ini';
  FPollingIntervalMs := 10000;
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
      Ini.WriteInteger('SERVICE', 'PollingIntervalMs', 10000);
      Ini.WriteString('SERVICE', 'LogLevel', 'INFO');
  Ini.WriteInteger('HTTP', 'Port', FHttpPort);
  Ini.WriteString('HTTP', 'BindAddress', FBindAddress);
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
        FPollingIntervalMs := Ini.ReadInteger('SERVICE', 'PollingIntervalMs', 10000);
        FLogLevel := Ini.ReadString('SERVICE', 'LogLevel', 'INFO');
  FHttpPort := Ini.ReadInteger('HTTP', 'Port', 8080);
  FBindAddress := Ini.ReadString('HTTP', 'BindAddress', '0.0.0.0');
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
