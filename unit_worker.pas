unit Unit_Worker;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Unit_DB;

type
  TWorkerTask = (wtIdle, wtModeration, wtForecast, wtVacuum);

  TServerWorker = class(TThread)
  private
    FDB: TDatabaseModule;
    FForcedTask: TWorkerTask;
    procedure DoLog(const AMsg: string);
  protected
    procedure Execute; override;
  public
    constructor Create(ADB: TDatabaseModule; CreateSuspended: boolean);
    procedure ExposeSystem(AStartID: Integer);
  end;

implementation

constructor TServerWorker.Create(ADB: TDatabaseModule; CreateSuspended: boolean);
begin
  inherited Create(CreateSuspended);
  FDB := ADB;
  FreeOnTerminate := True;
end;

procedure TServerWorker.DoLog(const AMsg: string);
begin
  // Просто выводим в консоль, чтобы не вызвать ошибок интерфейса
  WriteLn('LOG: ' + AMsg);
end;

procedure TServerWorker.ExposeSystem(AStartID: Integer);
var
  CurrentID, LastID: Integer;
  Chrono: string;
  NodeB, NodeT: Integer; // Убедись, что эти переменные объявлены здесь!
  StrList: TStringList;
begin


    // САМАЯ ВАЖНАЯ ПРОВЕРКА
  if FDB = nil then
  begin
    DoLog('КРИТИЧЕСКАЯ ОШИБКА: Воркер не видит FDB (базу)!');
    Exit;
  end;

  try
    DoLog('ВОРКЕР: Начинаю обход системы ID ' + IntToStr(AStartID));

    // Тут твой код с StrList и циклом while...
    // ...

  except
    on E: Exception do
      DoLog('ОШИБКА В ЦИКЛЕ: ' + E.Message);
  end;


  DoLog('Воркер: Вхожу в систему ID ' + IntToStr(AStartID));
  CurrentID := AStartID;
  LastID := 0;

    DoLog('ВОРКЕР: Проверка головы ' + IntToStr(AStartID));
  Chrono := FDB.GetNodeChrono(AStartID);
  DoLog('ВОРКЕР: Получена строка: "' + Chrono + '"');

  StrList := TStringList.Create;
  try
    StrList.Delimiter := '.';
    StrList.StrictDelimiter := True;

    // 1. Читаем голову
    Chrono := FDB.GetNodeChrono(AStartID);
    DoLog('Воркер: Хронология головы = "' + Chrono + '"');

    StrList.DelimitedText := Chrono;
    if StrList.Count > 2 then
      CurrentID := StrToIntDef(StrList[2], 0) // Прыгаем в Хвост
    else
    begin
      DoLog('Воркер: У головы нет хвоста. Выход.');
      Exit;
    end;

    if (CurrentID = 0) or (CurrentID = AStartID) then Exit;

    // 2. ЦИКЛ ВЫДЕРГИВАНИЯ
    while (CurrentID <> 0) and (CurrentID <> AStartID) do
    begin
      Chrono := FDB.GetNodeChrono(CurrentID);
      if Chrono = '' then Break;

      StrList.DelimitedText := Chrono;
      if StrList.Count < 3 then Break;

      // Инициализируем те самые переменные из ошибки
      NodeB := StrToIntDef(StrList[1], 0); // Предшественник
      NodeT := StrToIntDef(StrList[2], 0); // Хвост

      DoLog('Воркер: Читаю узел ' + IntToStr(CurrentID) + ' (B:'+IntToStr(NodeB)+' T:'+IntToStr(NodeT)+')');

      // ПРАВИЛО: Если у узла есть хвост И мы там еще не были — НЫРЯЕМ
      if (NodeT <> 0) and (NodeT <> LastID) then
      begin
        LastID := CurrentID;
        CurrentID := NodeT;
      end
      else
      begin
        DoLog('ВЫДЕРНУТ УЗЕЛ: ' + IntToStr(CurrentID));
        LastID := CurrentID;
        CurrentID := NodeB; // Возвращаемся к предшественнику
      end;
    end;
  finally
    StrList.Free;
  end;
  DoLog('Воркер: Обход завершен.');
end;


procedure TServerWorker.Execute;
begin
  while not Terminated do
  begin
    Sleep(1000);
  end;
end;

end.

