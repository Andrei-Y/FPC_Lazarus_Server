unit Unit_Main;

interface

uses
  Classes, SysUtils, Unit_DB, Unit_Network, Unit_Worker;

type
  { Обязательно добавь это определение типа перед классом }
    TForumServer = class
  private
    FDB: TDatabaseModule;
    FNet: TForumNetwork;
    FWorker: TServerWorker;
    FOnLog: TLogEvent;
    procedure DoLog(const AMsg: string);
  public
    constructor Create(ADBName: string);
    procedure Start;
    procedure Stop;

    // Добавляем свойства, чтобы форма могла обращаться к ним
    property DB: TDatabaseModule read FDB;
    property Worker: TServerWorker read FWorker;
    property OnLog: TLogEvent read FOnLog write FOnLog;
  end;

implementation

uses UMainForm;

constructor TForumServer.Create(ADBName: string);
begin
  FDB := TDatabaseModule.Create(ADBName);
  FNet := TForumNetwork.Create(8080);

  // Добавляем @Form1.UpdateForumView как третий параметр.
  // Теперь Воркер будет знать, куда отправлять HTML-код.
  FWorker := TServerWorker.Create(FDB, @DoLog, @Form1.UpdateForumView, emToViewer, False);
end;



//procedure TForumServer.Start;
//begin
//  FNet.Start;
//  FWorker.Start; // Запускаем воркера
//  WriteLn('Сервер запущен. Ожидание сигналов из космоса...');
//end;


{ Добавь это в секцию implementation }
procedure TForumServer.DoLog(const AMsg: string);
begin
  if Assigned(FOnLog) then FOnLog(AMsg);
end;

{ И убедись, что метод Start использует именно DoLog, а не WriteLn }
procedure TForumServer.Start;
var
  NewID: Integer;
begin
  try
    FNet.Start;
    DoLog('Сеть запущена на порту 8080');

    FWorker.Start;
    DoLog('Фоновый воркер запущен');

    // ТЕСТ: Создаем узел через базу
    NewID := FDB.AddNode(0, 'Первый контакт: начало формирования системы', 100.0, 100.0);
    DoLog('База активна. Создан тестовый узел ID: ' + IntToStr(NewID));
  except
    on E: Exception do DoLog('ОШИБКА СТАРТА: ' + E.Message);
  end;
end;





procedure TForumServer.Stop;
begin
  FNet.Stop;
  FWorker.Terminate;
  FWorker.WaitFor;
end;



end.


