program SvcMonitorDiretorio;

{$mode objfpc}{$H+}
{$CODEPAGE UTF8}
{$APPTYPE CONSOLE}

uses
  {$IFDEF UNIX}
  cthreads, BaseUnix,
  {$ENDIF}
  SysUtils, Classes,
  uConfig in 'uConfig.pas',
  uWorker in 'uWorker.pas',
  uServiceCore in 'uServiceCore.pas';

var
  LParam: string;
  I: Integer;
  LIsDebug: Boolean;
begin
  LIsDebug := False;

  // Processamento de parâmetros de linha de comando
  if ParamCount > 0 then
  begin
    for I := 1 to ParamCount do
    begin
      LParam := LowerCase(ParamStr(I));
      if (LParam = '/debug') or (LParam = '-d') or (LParam = '--debug') then
        LIsDebug := True
      else if (LParam = '/install') or (LParam = '--install') or (LParam = '-i') then
      begin
        TServiceCore.InstallService;
        Exit;
      end
      else if (LParam = '/uninstall') or (LParam = '--uninstall') or (LParam = '-u') then
      begin
        TServiceCore.UninstallService;
        Exit;
      end
      else if (LParam = '/help') or (LParam = '--help') or (LParam = '-h') or (LParam = '/?') then
      begin
        TServiceCore.PrintHelp;
        Exit;
      end;
    end;
  end;

  // Inicialização e despacho do serviço
  TServiceCore.Run(LIsDebug);
end.
