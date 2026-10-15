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
    FQueueBatchSize: Integer;
    FMaxWorkers: Integer;
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
    property QueueBatchSize: Integer read FQueueBatchSize;
    property MaxWorkers: Integer read FMaxWorkers;
  end;

implementation

{ TAppConfig }

constructor TAppConfig.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FIniFileName := ExtractFilePath(ParamStr(0)) + 'SvcFilaMensagens.ini';
  FPollingIntervalMs := 1000;
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
      Ini.WriteInteger('SERVICE', 'PollingIntervalMs', 1000);
      Ini.WriteString('SERVICE', 'LogLevel', 'INFO');
  Ini.WriteInteger('QUEUE', 'BatchSize', FQueueBatchSize);
  Ini.WriteInteger('QUEUE', 'MaxWorkers', FMaxWorkers);
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
        FPollingIntervalMs := Ini.ReadInteger('SERVICE', 'PollingIntervalMs', 1000);
        FLogLevel := Ini.ReadString('SERVICE', 'LogLevel', 'INFO');
  FQueueBatchSize := Ini.ReadInteger('QUEUE', 'BatchSize', 100);
  FMaxWorkers := Ini.ReadInteger('QUEUE', 'MaxWorkers', 4);
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
