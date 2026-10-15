unit uWorker;

{$mode objfpc}{$H+}
{$CODEPAGE UTF8}

interface

uses
  SysUtils, Classes, SyncObjs;

type
  { TServiceWorkerThread: Thread de execucao independente e segura }
  TServiceWorkerThread = class(TThread)
  private
    FTermEvent: TEvent;
    FIntervalMs: Cardinal;
    FPort: Word;
    procedure ProcessHeartbeat;
  protected
    procedure Execute; override;
  public
    constructor Create;
    destructor Destroy; override;
    procedure TerminateWork;
    procedure UpdateInterval(const ANewIntervalMs: Cardinal);
  end;

  { TServiceWorker: Fachada de controle do modulo de trabalho }
  TServiceWorker = class
  private
    FThread: TServiceWorkerThread;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Start;
    procedure Stop;
    procedure OnConfigReload;
  end;

implementation

uses
  uConfig, uServiceCore;

procedure TServiceWorkerThread.ProcessHeartbeat;
begin
  TServiceCore.LogMessage('DEBUG', '[MICROSERVICE] Servico HTTP ativo escutando na porta ' + IntToStr(FPort) + '...');
  // Aqui você conecta seu servidor HTTP (ex: fphttpapp, Brook, Horse, mORMot ou sockets nativos)
end;

{ TServiceWorkerThread }

constructor TServiceWorkerThread.Create;
begin
  inherited Create(True); // Cria suspensa
  FreeOnTerminate := False;
  FTermEvent := TEvent.Create(nil, True, False, '');
  FIntervalMs := TAppConfig.Instance.PollingIntervalMs;
  FPort := TAppConfig.Instance.HttpPort;
  TServiceCore.LogMessage('INFO', '[MICROSERVICE] Inicializando socket HTTP na porta ' + IntToStr(FPort));
end;

destructor TServiceWorkerThread.Destroy;
begin
  FreeAndNil(FTermEvent);
  inherited Destroy;
end;

procedure TServiceWorkerThread.TerminateWork;
begin
  Terminate;
  if Assigned(FTermEvent) then
    FTermEvent.SetEvent; // Desperta a thread imediatamente sem aguardar sleep
end;

procedure TServiceWorkerThread.UpdateInterval(const ANewIntervalMs: Cardinal);
begin
  FIntervalMs := ANewIntervalMs;
end;

procedure TServiceWorkerThread.Execute;
begin
  TServiceCore.LogMessage('INFO', 'Thread de trabalho iniciada. Intervalo: ' + IntToStr(FIntervalMs) + ' ms');
  while not Terminated do
  begin
    try
      ProcessHeartbeat;
    except
      on E: Exception do
        TServiceCore.LogMessage('ERROR', '[MICROSERVICE] Erro no microservico: ' + E.Message);
    end;
    // Aguarda o intervalo de forma responsiva ao sinal de encerramento
    if FTermEvent.WaitFor(FIntervalMs) = wrSignaled then
      Break;
  end;
  TServiceCore.LogMessage('INFO', 'Thread de trabalho finalizada com sucesso.');
end;

{ TServiceWorker }

constructor TServiceWorker.Create;
begin
  inherited Create;
end;

destructor TServiceWorker.Destroy;
begin
  Stop;
  inherited Destroy;
end;

procedure TServiceWorker.Start;
begin
  if not Assigned(FThread) then
  begin
    FThread := TServiceWorkerThread.Create;
    FThread.Start;
  end;
end;

procedure TServiceWorker.Stop;
begin
  if Assigned(FThread) then
  begin
    FThread.TerminateWork;
    FThread.WaitFor;
    FreeAndNil(FThread);
  end;
end;

procedure TServiceWorker.OnConfigReload;
begin
  if Assigned(FThread) then
    FThread.UpdateInterval(TAppConfig.Instance.PollingIntervalMs);
end;

end.
