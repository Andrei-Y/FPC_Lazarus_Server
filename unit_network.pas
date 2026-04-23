unit Unit_Network;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fphttpserver, fpjson, jsonparser;

type
  { Основной класс сетевого модуля }
  TForumNetwork = class
  private
    FServer: TFPHTTPServer;

    // Главный диспетчер: распределяет, кто пришел (браузер или админка)
    // Имена методов теперь на латинице (HandleRequest вместо ОбработкаЗапроса)
    procedure HandleRequest(Sender: TObject; var ARequest: TFPHTTPConnectionRequest;
      var AResponse: TFPHTTPConnectionResponse);

    // 1. Секция для обычных пользователей (Обычный Веб)
    procedure HandlePublicWeb(var ARequest: TFPHTTPConnectionRequest;
      var AResponse: TFPHTTPConnectionResponse);

    // 2. Секция для управления (Админ-API для Lazarus-клиента)
    procedure HandleAdminAPI(var ARequest: TFPHTTPConnectionRequest;
      var AResponse: TFPHTTPConnectionResponse);
  public
    constructor Create(APort: Word);
    destructor Destroy; override;
    procedure Start;
    procedure Stop; // Метод для корректной остановки сервера
  end;

implementation

{ TForumNetwork }

constructor TForumNetwork.Create(APort: Word);
begin
  FServer := TFPHTTPServer.Create(nil);
  FServer.Port := APort;
  // Назначаем обработчик события при получении запроса
  FServer.OnRequest := @HandleRequest;
end;

procedure TForumNetwork.HandleRequest(Sender: TObject; var ARequest: TFPHTTPConnectionRequest;
  var AResponse: TFPHTTPConnectionResponse);
begin
  // Используем универсальный метод GetCustomHeader
  if ARequest.GetCustomHeader('X-Custom-Client') = 'Lazarus-Astro-Admin' then
    HandleAdminAPI(ARequest, AResponse)
  else
    HandlePublicWeb(ARequest, AResponse);
end;


{ --- ПУБЛИЧНАЯ ЧАСТЬ: Для тех, кто зашел через обычный браузер --- }
procedure TForumNetwork.HandlePublicWeb(var ARequest: TFPHTTPConnectionRequest;
  var AResponse: TFPHTTPConnectionResponse);
begin
  AResponse.ContentType := 'text/html; charset=utf-8';

  if ARequest.PathInfo = '/' then
    AResponse.Content := '<html><body><h1>Космическая Система Знаний</h1>' +
                         '<p>Сервер работает. Используйте клиентское приложение для визуализации.</p></body></html>'
  else
  begin
    AResponse.Code := 404;
    AResponse.Content := '<html><body>Ошибка 404: Объект не найден.</body></html>';
  end;
end;

{ --- АДМИН-API: Для твоего клиентского приложения на ноутбуке --- }
procedure TForumNetwork.HandleAdminAPI(var ARequest: TFPHTTPConnectionRequest;
  var AResponse: TFPHTTPConnectionResponse);
begin
  AResponse.ContentType := 'application/json; charset=utf-8';

  // Пример маршрута: запрос очереди на модерацию
  if ARequest.PathInfo = '/admin/get_audit_list' then
  begin
    AResponse.Content := '{"nodes": [], "status": "нарушений не обнаружено"}';
  end
  // Пример маршрута: запрос данных всей системы
  else if ARequest.PathInfo = '/admin/get_system' then
  begin
    AResponse.Content := '{"root_id": 1, "nodes_count": 0, "info": "система пуста"}';
  end
  else
  begin
    AResponse.Code := 400;
    AResponse.Content := '{"error": "неизвестная команда"}';
  end;
end;

procedure TForumNetwork.Start;
begin
  FServer.Active := True;
end;

procedure TForumNetwork.Stop;
begin
  FServer.Active := False;
end;

destructor TForumNetwork.Destroy;
begin
  FServer.Free;
  inherited Destroy;
end;

end.

