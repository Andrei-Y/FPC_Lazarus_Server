unit Unit_Worker;

interface

uses
  Classes, SysUtils, Unit_DB;

type
  { Переносим тип сюда, ПЕРЕД описанием класса }
  TLogEvent = procedure(const AMsg: string) of object;

  TWorkerTask = (wtIdle, wtModeration, wtForecast, wtVacuum);

  TServerWorker = class(TThread)


  private
    FDB: TDatabaseModule;
    FOnLog: TLogEvent; // Теперь компилятор знает, что это такое
    FMsgForLog: string;
    // ... остальное

    procedure DoLog(const AMsg: string);
    procedure SyncLog;  // Метод для синхронизации
  protected
    procedure Execute; override;
  public
    constructor Create(ADB: TDatabaseModule; ALogEvent: TLogEvent; CreateSuspended: boolean);
    procedure AddMessageTask(AParentID: Integer; AContent: string);
    procedure ExposeSystem(AStartID: Integer);
  end;

  type
  TMapNode = record
    ID, ParentID, Level: Integer;
  end;

implementation

constructor TServerWorker.Create(ADB: TDatabaseModule; ALogEvent: TLogEvent; CreateSuspended: boolean);
begin
  inherited Create(CreateSuspended);
  FDB := ADB;
  FOnLog := ALogEvent; // Не забудь присвоить событие!
  FreeOnTerminate := True;
end;

procedure TServerWorker.AddMessageTask(AParentID: Integer; AContent: string);
var
  NewID: Integer;
  CheckChrono: string;
begin
  // 1. Приземляем
  NewID := FDB.LandingNode(AParentID, AContent);

  if NewID > 0 then
  begin
    // 2. СРАЗУ ПРОВЕРЯЕМ РОДИТЕЛЯ
    CheckChrono := FDB.GetNodeChrono(AParentID);

    // 3. Докладываем в TMemo
    DoLog('ВОРКЕР: Приземлил ID ' + IntToStr(NewID) +
          '. У родителя ' + IntToStr(AParentID) +
          ' Хроно теперь = "' + CheckChrono + '"');
  end
  else
    DoLog('ВОРКЕР: Ошибка приземления к ID ' + IntToStr(AParentID));
end;



procedure TServerWorker.SyncLog;
begin
  // Вызываем событие лога, которое привязано к твоему TMemo
  if Assigned(FOnLog) then FOnLog(FMsgForLog);
end;

procedure TServerWorker.DoLog(const AMsg: string);
begin
  FMsgForLog := AMsg;
  // Жёсткая синхронизация: поток воркера ждёт, пока форма примет сообщение
  Synchronize(@SyncLog);
end;




procedure TServerWorker.ExposeSystem(AStartID: Integer);
var
  CurrentID: Integer;
  Chrono: string;
  NodeB, NodeT: Integer;
  StrList, TailStack: TStringList;
begin
  DoLog('--- СТАРТ ФОРМИРОВАНИЯ СТРУКТУРЫ ---');

  CurrentID := AStartID;
  StrList := TStringList.Create;
  TailStack := TStringList.Create;

  try
    StrList.Delimiter := '.';
    StrList.StrictDelimiter := True;

    while (CurrentID <> 0) do
    begin
      Chrono := FDB.GetNodeChrono(CurrentID);
      StrList.DelimitedText := Chrono;
      if StrList.Count < 3 then Break;

      NodeB := StrToIntDef(StrList[1], 0);
      NodeT := StrToIntDef(StrList[2], 0);

      // --- ПЕРЕНЕСЛИ СЮДА: ФИКСИРУЕМ УЗЕЛ СРАЗУ ---
      // Мы выводим его только если еще не "ныряли" из него (его нет в стеке)
      if TailStack.IndexOf(IntToStr(CurrentID)) = -1 then
         DoLog('ВЫДЕРНУТ УЗЕЛ: ' + IntToStr(CurrentID));

      // ПРОВЕРКА НА НЫРОК:
      if (NodeT <> 0) and (TailStack.IndexOf(IntToStr(CurrentID)) = -1) then
      begin
        DoLog('>>> НЫРОК В ВЕТКУ (из ' + IntToStr(CurrentID) + ')');
        TailStack.Add(IntToStr(CurrentID));
        CurrentID := NodeT;
        Continue;
      end;

      // ПРОВЕРКА НА ВСПЛЫТИЕ:
      if TailStack.IndexOf(IntToStr(CurrentID)) <> -1 then
      begin
         TailStack.Delete(TailStack.IndexOf(IntToStr(CurrentID)));
         DoLog('<<< ВСПЛЫТИЕ ИЗ ВЕТКИ (возврат в ' + IntToStr(CurrentID) + ')');
      end;

      CurrentID := NodeB;

      if (CurrentID = AStartID) and (TailStack.Count = 0) then Break;
    end;

    // Корень выводим отдельно в конце, если цикл на нем завершился
    if (AStartID <> 0) and (CurrentID = AStartID) then
       DoLog('ВЫДЕРНУТ УЗЕЛ (КОРЕНЬ): ' + IntToStr(AStartID));






    if (AStartID <> 0) then DoLog('ВЫДЕРНУТ УЗЕЛ (КОРЕНЬ): ' + IntToStr(AStartID));

  finally
    StrList.Free;
    TailStack.Free;
  end;
  DoLog('--- СТРУКТУРА ЗАВЕРШЕНА ---');
end;










//procedure TServerWorker.ExposeSystem(AStartID: Integer);
//var
//  CurrentID, LastID: Integer;
//  Chrono: string;
//  NodeB, NodeT: Integer;
//  StrList: TStringList;
//begin
//  // МАЯК 1: Вход в процедуру
//  FDB.ExecSQL('INSERT INTO nodes (content, chronology) VALUES (''Воркер: Начал обход системы ' + IntToStr(AStartID) + ''', ''0.0.0.'')');
//
//  CurrentID := AStartID;
//  LastID := 0;
//  StrList := TStringList.Create;
//  try
//    StrList.Delimiter := '.';
//    StrList.StrictDelimiter := True;
//
//    Chrono := FDB.GetNodeChrono(AStartID);
//
//    // МАЯК 2: Что прочитали из головы
//    FDB.ExecSQL('INSERT INTO nodes (content, chronology) VALUES (''Воркер: Голова ' + IntToStr(AStartID) + ' имеет хроно ' + Chrono + ''', ''0.0.0.'')');
//
//    StrList.DelimitedText := Chrono;
//    if StrList.Count > 2 then
//      CurrentID := StrToIntDef(StrList[2], 0) // Хвост
//    else
//      Exit;
//
//    while (CurrentID <> 0) and (CurrentID <> AStartID) do
//    begin
//      Chrono := FDB.GetNodeChrono(CurrentID);
//      StrList.DelimitedText := Chrono;
//      if StrList.Count < 3 then Break;
//
//      NodeB := StrToIntDef(StrList[1], 0);
//      NodeT := StrToIntDef(StrList[2], 0);
//
//      // МАЯК 3: Лог каждого шага в цикле
//      FDB.ExecSQL('INSERT INTO nodes (content, chronology) VALUES (''Воркер: Читаю узел ' + IntToStr(CurrentID) + ' (B:' + IntToStr(NodeB) + ' T:' + IntToStr(NodeT) + ')'', ''0.0.0.'')');
//
//      if (NodeT <> 0) and (NodeT <> LastID) then
//      begin
//        LastID := CurrentID;
//        CurrentID := NodeT;
//      end
//      else
//      begin
//        LastID := CurrentID;
//        CurrentID := NodeB;
//      end;
//    end;
//  finally
//    StrList.Free;
//  end;
//
//  // МАЯК 4: Конец
//  FDB.ExecSQL('INSERT INTO nodes (content, chronology) VALUES (''Воркер: Обход завершен успешно'', ''0.0.0.'')');
//end;






procedure TServerWorker.Execute;
begin
  while not Terminated do
  begin
    Sleep(1000);
  end;
end;

end.

