program CosmicConsole;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}cthreads, baseunix, unix,{$ENDIF}
  SysUtils, Classes,
  Unit_DB, Unit_Network, Unit_Worker;

var
  FDB: TDatabaseModule;
  FNet: TForumNetwork;
  S: String;

begin
  WriteLn('=== STARTING COSMIC CORE ===');
  try
    // Инициализация
    FDB := TDatabaseModule.Create('forum.db');
    FNet := TForumNetwork.Create(8080);

    FNet.Start; // Тут наш Threaded := True

    WriteLn('Server LIVE on port 8080.');
    WriteLn('Press ENTER to shutdown safely...');

    ReadLn(S); // Консоль замирает и ждет твоего приказа

    WriteLn('Stopping components...');
    FNet.Stop; // Тут сработает наш "будильник" или FpKill

    FNet.Free;
    FDB.Free;

    WriteLn('=== SYSTEM OFFLINE ===');
  except
    on E: Exception do
      WriteLn('CRITICAL ERROR: ' + E.Message);
  end;
end.


