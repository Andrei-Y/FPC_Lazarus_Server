unit Unit_Worker;

interface


uses Classes, SysUtils;

type
  { Сначала описываем сам тип задачи }
  TWorkerTask = (wtIdle, wtModeration, wtForecast, wtVacuum);

  { Теперь описываем класс, который использует этот тип }
  TServerWorker = class(TThread)
  private
    FForcedTask: TWorkerTask;
    procedure RunNightlyAudit;    // Ночной ИИ-судья
    procedure RunCosmosForecast; // Прогнозист
  protected
    procedure Execute; override;
  public
    procedure ForceTask(ATask: TWorkerTask); // Для отладки с ноутбука
  end;


implementation
// Функция IsNightTime должна быть здесь (мы её добавили ранее)
function IsNightTime: Boolean;
var
  Hour, Min, Sec, MSec: Word;
begin
  DecodeTime(Now, Hour, Min, Sec, MSec);
  Result := (Hour >= 2) and (Hour <= 6);
end;

{ TServerWorker }

procedure TServerWorker.Execute; // Строго так, без override
begin
  while not Terminated do
  begin
    if FForcedTask <> wtIdle then
    begin
       // Логика ручных задач
       FForcedTask := wtIdle;
    end;

    if IsNightTime then RunNightlyAudit else RunCosmosForecast;

    Sleep(5000);
  end;
end;

// Не забудь добавить пустые тела для этих процедур, если их еще нет:
procedure TServerWorker.RunNightlyAudit;
begin
end;

procedure TServerWorker.RunCosmosForecast;
begin
end;

procedure TServerWorker.ForceTask(ATask: TWorkerTask);
begin
  FForcedTask := ATask;
end;

end.


