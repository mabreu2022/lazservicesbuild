unit uServiceCore;

{$mode objfpc}{$H+}
{$CODEPAGE UTF8}

interface

uses
  SysUtils, Classes, SyncObjs,
  {$IFDEF WINDOWS}
  Windows,
  {$ENDIF}
  {$IFDEF UNIX}
  BaseUnix,
  {$ENDIF}
  uConfig, uWorker;

type
  { TServiceCore: Núcleo de gerenciamento de ciclo de vida multiplataforma }
  TServiceCore = class
  private
    class var FIsRunning: Boolean;
    class var FIsDebugMode: Boolean;
    class var FTermEvent: TEvent;
    class var FWorker: TServiceWorker;
    class procedure SetupSignals;
    class procedure RunInteractiveDebug;
    {$IFDEF WINDOWS}
    class procedure RunWindowsService;
    {$ENDIF}
    {$IFDEF UNIX}
    class procedure RunLinuxDaemon;
    {$ENDIF}
  public
    class procedure Run(const AIsDebug: Boolean);
    class procedure RequestStop;
    class procedure ReloadConfiguration;
    class procedure LogMessage(const ALevel, AMsg: string);
    class procedure InstallService;
    class procedure UninstallService;
    class procedure PrintHelp;
    class property IsDebugMode: Boolean read FIsDebugMode;
  end;

implementation

{$IFDEF WINDOWS}
var
  GServiceStatusHandle: SERVICE_STATUS_HANDLE;
  GServiceStatus: SERVICE_STATUS;

procedure SetCurrentServiceStatus(const ACurrentState, AExitCode, AWaitHint: DWORD);
begin
  GServiceStatus.dwCurrentState := ACurrentState;
  GServiceStatus.dwWin32ExitCode := AExitCode;
  GServiceStatus.dwWaitHint := AWaitHint;
  if ACurrentState = SERVICE_START_PENDING then
    GServiceStatus.dwControlsAccepted := 0
  else
    GServiceStatus.dwControlsAccepted := SERVICE_ACCEPT_STOP or SERVICE_ACCEPT_SHUTDOWN;
  SetServiceStatus(GServiceStatusHandle, GServiceStatus);
end;

function ServiceCtrlHandler(Opcode: DWORD): BOOL; stdcall;
begin
  Result := True;
  case Opcode of
    SERVICE_CONTROL_STOP, SERVICE_CONTROL_SHUTDOWN:
    begin
      SetCurrentServiceStatus(SERVICE_STOP_PENDING, NO_ERROR, 5000);
      TServiceCore.RequestStop;
    end;
    SERVICE_CONTROL_INTERROGATE:
      SetServiceStatus(GServiceStatusHandle, GServiceStatus);
  end;
end;

procedure ServiceMain(dwArgc: DWORD; lpszArgv: PPChar); stdcall;
begin
  GServiceStatus.dwServiceType := SERVICE_WIN32_OWN_PROCESS;
  GServiceStatus.dwCurrentState := SERVICE_START_PENDING;
  GServiceStatus.dwControlsAccepted := 0;
  GServiceStatus.dwWin32ExitCode := 0;
  GServiceStatus.dwServiceSpecificExitCode := 0;
  GServiceStatus.dwCheckPoint := 0;
  GServiceStatus.dwWaitHint := 5000;

  GServiceStatusHandle := RegisterServiceCtrlHandlerA('SvcFilaMensagens', @ServiceCtrlHandler);
  if GServiceStatusHandle = 0 then
    Exit;

  SetCurrentServiceStatus(SERVICE_START_PENDING, NO_ERROR, 3000);

  // Inicia o worker em background
  TServiceCore.FTermEvent := TEvent.Create(nil, True, False, '');
  TServiceCore.FWorker := TServiceWorker.Create;
  TServiceCore.FWorker.Start;

  SetCurrentServiceStatus(SERVICE_RUNNING, NO_ERROR, 0);
  TServiceCore.LogMessage('INFO', 'Servico SvcFilaMensagens iniciado com sucesso pelo Windows SCM.');

  // Aguarda sinal de encerramento
  TServiceCore.FTermEvent.WaitFor(INFINITE);

  SetCurrentServiceStatus(SERVICE_STOP_PENDING, NO_ERROR, 3000);
  if Assigned(TServiceCore.FWorker) then
  begin
    TServiceCore.FWorker.Stop;
    FreeAndNil(TServiceCore.FWorker);
  end;
  FreeAndNil(TServiceCore.FTermEvent);

  SetCurrentServiceStatus(SERVICE_STOPPED, NO_ERROR, 0);
  TServiceCore.LogMessage('INFO', 'Servico SvcFilaMensagens parado com sucesso.');
end;

function ConsoleCtrlHandler(dwCtrlType: DWORD): BOOL; stdcall;
begin
  case dwCtrlType of
    CTRL_C_EVENT, CTRL_BREAK_EVENT, CTRL_CLOSE_EVENT:
    begin
      Writeln('');
      TServiceCore.LogMessage('WARN', 'Sinal de encerramento recebido (Ctrl+C). Parando servico...');
      TServiceCore.RequestStop;
      Result := True;
    end;
  else
    Result := False;
  end;
end;
{$ENDIF}

{$IFDEF UNIX}
procedure PosixSigHandler(Sig: LongInt); cdecl;
begin
  case Sig of
    SIGTERM, SIGINT:
    begin
      TServiceCore.LogMessage('WARN', 'Sinal POSIX ' + IntToStr(Sig) + ' recebido. Encerrando servico...');
      TServiceCore.RequestStop;
    end;
    SIGHUP:
    begin
      TServiceCore.LogMessage('INFO', 'Sinal SIGHUP recebido. Recarregando configuracoes...');
      TServiceCore.ReloadConfiguration;
    end;
  end;
end;
{$ENDIF}

{ TServiceCore }

class procedure TServiceCore.SetupSignals;
begin
  {$IFDEF WINDOWS}
  SetConsoleCtrlHandler(@ConsoleCtrlHandler, True);
  {$ENDIF}
  {$IFDEF UNIX}
  fpSignal(SIGTERM, SignalHandler(@PosixSigHandler));
  fpSignal(SIGINT,  SignalHandler(@PosixSigHandler));
  fpSignal(SIGHUP,  SignalHandler(@PosixSigHandler));
  {$ENDIF}
end;

class procedure TServiceCore.LogMessage(const ALevel, AMsg: string);
var
  LLine, LDateStr, LLogFile: string;
  F: TextFile;
begin
  LDateStr := FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now);
  LLine := '[' + LDateStr + '] [' + UpperCase(ALevel) + '] ' + AMsg;

  // Se estiver no modo interativo ou terminal
  if FIsDebugMode or (ParamCount > 0) then
    Writeln(LLine);

  // Gravação em arquivo de log rotativo
  try
    LLogFile := ExtractFilePath(ParamStr(0)) + 'SvcFilaMensagens-' + FormatDateTime('yyyy-mm-dd', Now) + '.log';
    AssignFile(F, LLogFile);
    if FileExists(LLogFile) then
      Append(F)
    else
      Rewrite(F);
    Writeln(F, LLine);
    CloseFile(F);
  except
    // Não interrompe o serviço em falha de escrita de log
  end;
end;

class procedure TServiceCore.RequestStop;
begin
  FIsRunning := False;
  if Assigned(FTermEvent) then
    FTermEvent.SetEvent;
end;

class procedure TServiceCore.ReloadConfiguration;
begin
  TAppConfig.Instance.Reload;
  if Assigned(FWorker) then
    FWorker.OnConfigReload;
  LogMessage('INFO', 'Configuracoes recarregadas com sucesso a partir de: ' + TAppConfig.Instance.IniFileName);
end;

class procedure TServiceCore.RunInteractiveDebug;
begin
  FIsDebugMode := True;
  SetupSignals;

  Writeln('================================================================');
  Writeln('  Servico de Fila Continua de Mensagens');
  Writeln('  Modo: Console Interativo de Debug (/debug)');
  Writeln('  Pressione Ctrl+C para encerrar limpo e com segurança');
  Writeln('================================================================');
  Writeln('');

  LogMessage('INFO', 'Iniciando modulo de trabalho (Worker)...');
  FTermEvent := TEvent.Create(nil, True, False, '');
  try
    FWorker := TServiceWorker.Create;
    FWorker.Start;
    FIsRunning := True;
    LogMessage('INFO', 'Servico executando no terminal interativo. Aguardando eventos...');

    // Aguarda encerramento
    FTermEvent.WaitFor(INFINITE);

    LogMessage('INFO', 'Encerrando modulo de trabalho...');
    FWorker.Stop;
    FreeAndNil(FWorker);
    LogMessage('INFO', 'Servico finalizado com sucesso.');
  finally
    FreeAndNil(FTermEvent);
  end;
end;

{$IFDEF WINDOWS}
class procedure TServiceCore.RunWindowsService;
var
  LServiceTable: array[0..1] of SERVICE_TABLE_ENTRYA;
begin
  LServiceTable[0].lpServiceName := PAnsiChar('SvcFilaMensagens');
  LServiceTable[0].lpServiceProc := @ServiceMain;
  LServiceTable[1].lpServiceName := nil;
  LServiceTable[1].lpServiceProc := nil;

  if not StartServiceCtrlDispatcherA(@LServiceTable[0]) then
  begin
    // Se falhar ao conectar ao SCM (ex: executado em janela comum sem /debug)
    Writeln('Aviso: Este programa e um servico do Windows e deve ser iniciado pelo SCM.');
    Writeln('Para testar interativamente, use o parametro: /debug');
    Writeln('Para registrar o servico, use: /install ou executar instalar.bat');
  end;
end;
{$ENDIF}

{$IFDEF UNIX}
class procedure TServiceCore.RunLinuxDaemon;
begin
  // No Linux moderno com Systemd (Type=simple), o daemon roda como processo primário
  SetupSignals;
  LogMessage('INFO', 'Iniciando daemon Linux SvcFilaMensagens via Systemd...');

  FTermEvent := TEvent.Create(nil, True, False, '');
  try
    FWorker := TServiceWorker.Create;
    FWorker.Start;
    FIsRunning := True;
    LogMessage('INFO', 'Daemon SvcFilaMensagens rodando com sucesso.');

    FTermEvent.WaitFor(INFINITE);

    LogMessage('INFO', 'Parando daemon SvcFilaMensagens...');
    FWorker.Stop;
    FreeAndNil(FWorker);
    LogMessage('INFO', 'Daemon finalizado.');
  finally
    FreeAndNil(FTermEvent);
  end;
end;
{$ENDIF}

class procedure TServiceCore.Run(const AIsDebug: Boolean);
begin
  // Carrega configurações iniciais
  TAppConfig.Instance;

  if AIsDebug then
    RunInteractiveDebug
  else
  begin
    {$IFDEF WINDOWS}
    RunWindowsService;
    {$ENDIF}
    {$IFDEF UNIX}
    RunLinuxDaemon;
    {$ENDIF}
  end;
end;

class procedure TServiceCore.InstallService;
begin
  Writeln('Para instalar este servico com privilegios elevados, utilize:');
  {$IFDEF WINDOWS}
  Writeln('  Execute o script: instalar.bat (como Administrador)');
  {$ENDIF}
  {$IFDEF UNIX}
  Writeln('  Execute o script: sudo ./instalar.sh');
  {$ENDIF}
end;

class procedure TServiceCore.UninstallService;
begin
  Writeln('Para desinstalar este servico com privilegios elevados, utilize:');
  {$IFDEF WINDOWS}
  Writeln('  Execute o script: desinstalar.bat (como Administrador)');
  {$ENDIF}
  {$IFDEF UNIX}
  Writeln('  Execute o script: sudo ./remover.sh');
  {$ENDIF}
end;

class procedure TServiceCore.PrintHelp;
begin
  Writeln('Uso do executavel SvcFilaMensagens:');
  Writeln('  /debug  ou -d   : Executa em modo Console interativo com logs coloridos');
  Writeln('  /install ou -i  : Orienta a instalacao como servico no SCM/Systemd');
  Writeln('  /uninstall ou -u: Orienta a desinstalacao do servico');
  Writeln('  /help   ou -h   : Exibe esta mensagem de ajuda');
end;

end.
