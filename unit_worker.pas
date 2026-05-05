unit Unit_Worker;

interface

uses
  Classes, SysUtils, Unit_DB;

type
  { Переносим тип сюда, ПЕРЕД описанием класса }
  TLogEvent = procedure(const AMsg: string) of object;
  THTMLEvent = procedure(const AHtml: string) of object; // Добавь это

  TWorkerTask = (wtIdle, wtModeration, wtForecast, wtVacuum);

  TServerWorker = class(TThread)


  private
    FDB: TDatabaseModule;
    FOnLog: TLogEvent; // Теперь компилятор знает, что это такое
    FMsgForLog: string;
    FOnHtml: THTMLEvent; // Ссылка на вывод HTML
    FHtmlBuffer: string; // Временный буфер
    // ... остальное

    procedure DoLog(const AMsg: string);
    procedure SyncLog;  // Метод для синхронизации
    procedure SyncHtml;
  protected
    procedure Execute; override;
  public
    constructor Create(ADB: TDatabaseModule; ALogEv: TLogEvent; AHtmlEv: THTMLEvent; CreateSuspended: boolean);
    procedure AddMessageTask(AParentID: Integer; AContent: string);
    procedure ExposeSystem(AStartID: Integer);
  end;

  type
  TMapNode = record
    ID, ParentID, Level: Integer;
  end;

implementation

constructor TServerWorker.Create(ADB: TDatabaseModule; ALogEv: TLogEvent; AHtmlEv: THTMLEvent; CreateSuspended: boolean);
begin
  inherited Create(CreateSuspended);
  FDB := ADB;
  FOnLog := ALogEv;
  FOnHtml := AHtmlEv;
  FreeOnTerminate := True;
end;

procedure TServerWorker.SyncHtml;
begin
  if Assigned(FOnHtml) then FOnHtml(FHtmlBuffer);
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
  CurrentID, NodeB, NodeT, i, j, VisualLevel: Integer;
  Chrono, NodeContent, S_Open, S_Close, HTML_Row: string;
  StrList, TailStack, HTML_Acc: TStringList;
    S_Prefix: string; // ВОТ ОНА! Добавь эту строчку
    LastLevel: Integer;
      LineColor: string;
begin
  LastLevel := 0;
  HTML_Acc := TStringList.Create;
  // Темная тема: фон #1e1e1e, текст #d4d4d4
  HTML_Acc.Add('<html><body style="font-family:sans-serif; background:#1e1e1e; color:#d4d4d4; padding:15px;">');

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

      // --- ШАГ 1: НЫРОК ---
      if (NodeT <> 0) and (TailStack.IndexOf(IntToStr(CurrentID)) = -1) then
      begin
        DoLog('>>> НЫРОК В ВЕТКУ (из ' + IntToStr(CurrentID) + ')');
        TailStack.Add(IntToStr(CurrentID));
        CurrentID := NodeT;
        Continue;
      end;

      // --- ШАГ 2: ОПРЕДЕЛЯЕМ ВИЗУАЛЬНЫЙ УРОВЕНЬ ---
      // Если узел в стеке — значит это РОДИТЕЛЬ, из которого мы вынырнули.
      // Чтобы дети были ПРАВЕЕ него, его уровень должен быть меньше.
      if TailStack.IndexOf(IntToStr(CurrentID)) <> -1 then
        VisualLevel := TailStack.Count - 1
      else
        VisualLevel := TailStack.Count;

      // Защита от отрицательного уровня

      if VisualLevel < 0 then VisualLevel := 0;

      // --- ШАГ 3: ФИКСАЦИЯ И ОТРИСОВКА ---
      NodeContent := FDB.GetNodeContent(CurrentID);
      DoLog('ВЫДЕРНУТ УЗЕЛ: ' + IntToStr(CurrentID));

      // ФОРМИРУЕМ ПРЕФИКС (Сетка линий)
      S_Prefix := '';
      for j := 1 to VisualLevel do
      begin
        // Основной цвет линий — синий
        LineColor := '#4A90E2';

        if j < VisualLevel then
          // Рисуем проходящие линии (всегда синие)
          S_Prefix := S_Prefix + '<font color="' + LineColor + '">┃&nbsp;&nbsp;</font>'
        else
        begin
          // Это крайний индикатор уровня.
          // Если текущий уровень меньше предыдущего — значит, это "всплытие", красим в красный
          if VisualLevel < LastLevel then
             LineColor := '#FF0000'; // Ярко-красный для возврата

          S_Prefix := S_Prefix + '<font color="' + LineColor + '">┃(' + IntToStr(VisualLevel) + ')━</font>';
        end;
      end;

      // Запоминаем текущий уровень для сравнения на следующем шаге цикла
      LastLevel := VisualLevel;

      // СТРОИМ КАРТОЧКУ
      HTML_Row :=
        '<table border="0" cellpadding="0" cellspacing="0" width="100%">' +
        '<tr>' +
        '<td valign="top" style="white-space:nowrap;">' + S_Prefix + '</td>' +
        '<td width="100%" bgcolor="#2d2d2d" style="border:1px solid #3e3e3e; padding:8px;">' +
        '<font color="#6a9955" size="1">ID: ' + IntToStr(CurrentID)  + ')</font></font><br>' +
        '<font color="#d4d4d4">' + NodeContent + '</font>' +
        '</td>' +
        '</tr>' +
        '</table><br>';

      HTML_Acc.Add(HTML_Row);

      // --- ШАГ 4: ВСПЛЫТИЕ ---
      if TailStack.IndexOf(IntToStr(CurrentID)) <> -1 then
      begin
         TailStack.Delete(TailStack.IndexOf(IntToStr(CurrentID)));
         DoLog('<<< ВСПЛЫТИЕ ИЗ ВЕТКИ (возврат в ' + IntToStr(CurrentID) + ')');
      end;

      if (CurrentID = AStartID) and (TailStack.Count = 0) then Break;
      CurrentID := NodeB;
    end;

    HTML_Acc.Add('</body></html>');
    FHtmlBuffer := HTML_Acc.Text;
    Synchronize(@SyncHtml);

  finally
    HTML_Acc.Free;
    StrList.Free;
    TailStack.Free;
  end;
  DoLog('--- СТРУКТУРА ЗАВЕРШЕНА ---');
end;








procedure TServerWorker.Execute;
begin
  while not Terminated do
  begin
    Sleep(1000);
  end;
end;

end.

