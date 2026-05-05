unit UMainForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ComCtrls,
  IpHtml, Unit_Main; // Подключаем нашего Дирижёра

type

  { TForm1 }

  TForm1 = class(TForm)
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    EditParentID: TEdit;
    IpHtmlPanel1: TIpHtmlPanel;
    MemoInput: TMemo;
//    MemoLog: TMemo;
    MemoLog: TMemo; // Добавь TMemo на форму, чтобы видеть, что происходит
    PageControl1: TPageControl;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure PageControl1Change(Sender: TObject);
  private
    FServer: TForumServer;
  public
    procedure Log(const AMsg: string); // Добавь CONST перед AMsg
    procedure UpdateForumView(const AHtml: string);
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

procedure TForm1.UpdateForumView(const AHtml: string);
begin
  // Этот метод выполняется в главном потоке и обновляет панель
  IpHtmlPanel1.SetHtmlFromStr(AHtml);
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  Log('Запуск сервера...');
  try
    // Создаем экземпляр Дирижёра
    FServer := TForumServer.Create('forum.db'); // Добавь имя файла
      FServer.OnLog := @Log; // Привязываем наш метод Log формы к серверу
    // Запускаем все системы (БД, Сеть, Воркер)
    FServer.Start;
    Log('Сервер запущен на порту 8080.');
    Log('Открой в браузере: http://localhost:8080');
  except
    on E: Exception do
      Log('ОШИБКА СТАРТА: ' + E.Message);
  end;
end;

procedure TForm1.Button1Click(Sender: TObject);
var
  TargetID: Integer;
  UserText: string;
begin
  TargetID := StrToIntDef(EditParentID.Text, 1);
  UserText := MemoInput.Text;

  if UserText = '' then
  begin
    Log('Ошибка: Нельзя отправить пустое сообщение!');
    Exit;
  end;

  Log('Отправляю воркеру: ответ на ID ' + IntToStr(TargetID));

  // Даем команду воркеру приземлить реальный текст
  FServer.Worker.AddMessageTask(TargetID, UserText);

  // Очищаем поле ввода для следующего сообщения
  MemoInput.Clear;
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
  // Команда на чтение
  FServer.Worker.ExposeSystem(1);
end;

procedure TForm1.Button3Click(Sender: TObject);
begin
  Log('--- СОЗДАНИЕ КОРНЯ ---');
  // Используем ExecSQL для вставки ID 1
  FServer.DB.ExecSQL('INSERT INTO nodes (id, content, chronology) VALUES (1, ''КОРЕНЬ'', ''0.0.0.'')');
  Log('Узел №1 создан. Хроно: 0.0.0.');
end;




procedure TForm1.Log(const AMsg: string); // Добавь const и сюда!
begin
  MemoLog.Lines.Add(FormatDateTime('HH:nn:ss ', Now) + AMsg);
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  if Assigned(FServer) then
  begin
    FServer.Stop;
    FServer.Free;
  end;
end;

procedure TForm1.PageControl1Change(Sender: TObject);
begin

end;

end.


