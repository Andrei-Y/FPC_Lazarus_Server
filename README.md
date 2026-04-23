unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics,
  BGRABitmap, BGRABitmapTypes, BGRAGradients, Math, SQLite3Conn, SQLDB;

type
  { Твоя структура данных }
  TArgumentNode = record
    Importance: Double;  // 1.0 - Важно (белое), 0.0 - неважно (серое/черное)
    Novelty: Double;     // > 0.7 - Синее (неожиданность)
    TotalWeight: Double; // Кол-во реплик. Если > 20 и важность < 0.2 = Черная дыра
    X, Y: Integer;
    IslandCount: Integer; // Количество островов на планете (1-8)
    Scale: Single;        // Масштаб объекта (1.0 = нормальный размер)
    ParentIndex: Integer; // Индекс родительской планеты (0 = нет родителя)
    OrbitRadius: Single;  // Радиус орбиты вокруг родительской планеты
    OrbitAngle: Single;   // Текущий угол на орбите (в радианах)
    OrbitSpeed: Single;   // Скорость вращения по орбите (радиан/кадр)
  end;

  { TForm1 }

  TForm1 = class(TForm)
    procedure FormCreate(Sender: TObject);
    procedure FormPaint(Sender: TObject);
  private
    Nodes: array[1..15] of TArgumentNode;
    procedure DrawCosmosBackground(ABmp: TBGRABitmap);
    procedure RenderFrame(ACanvas: TCanvas);
    procedure DrawBlurredCircle(ABmp: TBGRABitmap; AX, AY: Integer;
      AColor: TBGRAPixel; ABaseRadius, ABlurRadius: Integer; AScale: Single);
    procedure DrawPlanetWithIslands(ABmp: TBGRABitmap; AX, AY: Integer;
      ABaseColor: TBGRAPixel; AIslandCount: Integer; AScale: Single);
    function GenerateComplementaryIslandColor(ABaseColor: TBGRAPixel): TBGRAPixel;
    procedure DrawThesisOrbits(ACanvas: TBGRABitmap; Center: TPointF; RX, RY: Single; AScale: Single);
    procedure DrawGaseousRing(ACanvas: TBGRABitmap; Center: TPointF; RX, RY: Single; AScale: Single; AColor: TBGRAPixel);
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

procedure TForm1.DrawGaseousRing(ACanvas: TBGRABitmap; Center: TPointF; RX, RY: Single; AScale: Single; AColor: TBGRAPixel);
var
  tempBmp: TBGRABitmap;
  ScaledRX, ScaledRY, ScaledBlur: Single;
  SideW, SideH: Integer;
begin
  // Настройки масштаба и размытия
  ScaledRX := RX * AScale;
  ScaledRY := RY * AScale;
  ScaledBlur := 15 * AScale; // Радиус размытия "газа"

  // Размер временного буфера (диаметр + запас на размытие)
  SideW := Round((ScaledRX + ScaledBlur) * 2) + 4;
  SideH := Round((ScaledRY + ScaledBlur) * 2) + 4;

  // Создаем прозрачный холст только под это кольцо
  tempBmp := TBGRABitmap.Create(SideW, SideH, BGRAPixelTransparent);
  try
    // 1. Рисуем само кольцо (контур) в центре буфера
    // Толщина линии (3 * AScale) задает плотность "костяка" аргументов
    tempBmp.EllipseAntialias(SideW / 2, SideH / 2, ScaledRX, ScaledRY, AColor, 3 * AScale);

    // 2. Применяем то самое идеальное размытие (Гаусс)
    // rbFast — оптимально для Jetson Nano
    BGRAReplace(tempBmp, tempBmp.FilterBlurRadial(Round(ScaledBlur), rbFast));

    // 3. Накладываем размытое газовое облако на основную карту
    ACanvas.PutImage(Round(Center.X - SideW / 2), Round(Center.Y - SideH / 2),
                     tempBmp, dmDrawWithTransparency);
  finally
    tempBmp.Free;
  end;
end;


function TForm1.GenerateComplementaryIslandColor(ABaseColor: TBGRAPixel): TBGRAPixel;
var
  invR, invG, invB: Integer;
begin
  // Генерация комплементарного (дополнительного) цвета
  if (ABaseColor.red = 255) and (ABaseColor.green = 255) and (ABaseColor.blue = 255) then
  begin
    // Белый → темно-синий/фиолетовый (комплементарный)
    Result := BGRA(70, 0, 130, 255); // Индиго
  end
  else if (ABaseColor.red = 100) and (ABaseColor.green = 180) and (ABaseColor.blue = 255) then
  begin
    // Светло-синий → оранжево-коричневый (комплементарный)
    Result := BGRA(210, 105, 30, 255); // Шоколадный
  end
  else if (ABaseColor.red = 160) and (ABaseColor.green = 160) and (ABaseColor.blue = 160) then
  begin
    // Серый → насыщенный синий (комплементарный)
    Result := BGRA(30, 144, 255, 255); // Доджер блю
  end
  else
  begin
    // Общий случай: инвертирование с коррекцией яркости
    invR := 255 - ABaseColor.red;
    invG := 255 - ABaseColor.green;
    invB := 255 - ABaseColor.blue;

    // Добавляем небольшие вариации для разнообразия
    invR := Min(255, Max(0, invR + Random(41) - 20));
    invG := Min(255, Max(0, invG + Random(41) - 20));
    invB := Min(255, Max(0, invB + Random(41) - 20));

    Result := BGRA(invR, invG, invB, 255);
  end;
end;

procedure TForm1.DrawBlurredCircle(ABmp: TBGRABitmap; AX, AY: Integer;
  AColor: TBGRAPixel; ABaseRadius, ABlurRadius: Integer; AScale: Single);
var
  tempBmp: TBGRABitmap;
  ScaledRadius, ScaledBlurRadius: Integer;
begin
  // Защита от некорректного масштаба
  if AScale <= 0 then AScale := 0.1;

  // Масштабируем радиусы с минимальным значением 1
  ScaledRadius := Max(1, Round(ABaseRadius * AScale));
  ScaledBlurRadius := Max(1, Round(ABlurRadius * AScale));

  // Рисуем орбиты с масштабированием
  DrawThesisOrbits(ABmp, PointF(AX, AY), 15 * AScale, 15 * AScale, AScale);

  // Создаем временный bitmap для круга с размытием
  tempBmp := TBGRABitmap.Create(ScaledRadius * 2 + ScaledBlurRadius * 2,
                                 ScaledRadius * 2 + ScaledBlurRadius * 2);
  try
    // Рисуем круг в центре временного bitmap
    tempBmp.FillEllipseAntialias(ScaledRadius + ScaledBlurRadius,
                                 ScaledRadius + ScaledBlurRadius,
                                 ScaledRadius, ScaledRadius, AColor);

    // Применяем гауссово размытие
    BGRAReplace(tempBmp, tempBmp.FilterBlurRadial(ScaledBlurRadius, rbFast));

    // Наложение размытого круга на основной bitmap
    ABmp.PutImage(AX - ScaledRadius - ScaledBlurRadius,
                  AY - ScaledRadius - ScaledBlurRadius,
                  tempBmp, dmDrawWithTransparency);
  finally
    tempBmp.Free;
  end;
end;

procedure TForm1.DrawPlanetWithIslands(ABmp: TBGRABitmap; AX, AY: Integer;
  ABaseColor: TBGRAPixel; AIslandCount: Integer; AScale: Single);
var
  i, ring, posInRing: Integer;
  islandX, islandY: Integer;
  islandColor: TBGRAPixel;
  angle, hexRadius: Double;
  positions: array of TPoint;
  planetRadius, islandRadius: Integer;
  distanceBetweenIslands: Double;
  dx, dy: Integer;
  canPlace: Boolean;
  j: Integer;
  ScaledPlanetRadius, ScaledIslandRadius: Integer;
  maxAttempts, attempts: Integer;
begin
  // Защита от некорректного масштаба
  if AScale <= 0 then AScale := 0.1;

  // Масштабируем базовые радиусы с минимальным значением 1
  ScaledPlanetRadius := Max(1, Round(6 * AScale));
  ScaledIslandRadius := Max(1, Round(2 * AScale));

  // 1. Сначала рисуем орбиты тезисов (фон) с масштабированием
  DrawThesisOrbits(ABmp, PointF(AX, AY), 15 * AScale, 15 * AScale, AScale);

  // 2. Затем рисуем размытую атмосферу планеты с масштабированием
  DrawBlurredCircle(ABmp, AX, AY,
    BGRA(ABaseColor.red, ABaseColor.green, ABaseColor.blue, 80),
    Max(1, Round(8 * AScale)), Max(1, Round(3 * AScale)), AScale);

  // 3. Основное тело планеты с масштабированием
  ABmp.FillEllipseAntialias(AX, AY, ScaledPlanetRadius, ScaledPlanetRadius, ABaseColor);

  // Острова на поверхности планеты (гексагональная сетка)
  if (AIslandCount > 0) and (ScaledPlanetRadius > ScaledIslandRadius) then
  begin
    // Параметры с масштабированием
    planetRadius := ScaledPlanetRadius;     // Радиус планеты
    islandRadius := ScaledIslandRadius;     // Радиус острова
    distanceBetweenIslands := islandRadius * 2; // Расстояние между центрами

    // Гексагональная сетка: центральный остров + кольца
    SetLength(positions, 0);

    // Центральный остров
    SetLength(positions, 1);
    positions[0] := Point(0, 0);

    // Добавляем острова по кольцам гексагональной сетки
    ring := 1;
    maxAttempts := 10; // Защита от бесконечного цикла
    attempts := 0;

    while (Length(positions) < AIslandCount) and (attempts < maxAttempts) do
    begin
      // В каждом кольце 6 островов
      for posInRing := 0 to 5 do
      begin
        if Length(positions) >= AIslandCount then Break;

        // Угол для позиции в кольце (60 градусов между островами)
        angle := Pi / 3 * posInRing;

        // Для четных колец добавляем смещение 30 градусов для плотной упаковки
        if ring mod 2 = 0 then
          angle := angle + Pi / 6;

        // Радиус кольца
        hexRadius := ring * distanceBetweenIslands;

        // Координаты в гексагональной сетке
        islandX := Round(Cos(angle) * hexRadius);
        islandY := Round(Sin(angle) * hexRadius);

        // Проверяем, что остров полностью внутри круга планеты
        // (центр острова должен быть не дальше чем planetRadius - islandRadius)
        if Sqrt(islandX*islandX + islandY*islandY) <= (planetRadius - islandRadius) then
        begin
          // Проверяем, что остров не перекрывается с существующими
          canPlace := True;
          for i := 0 to Length(positions) - 1 do
          begin
            dx := islandX - positions[i].X;
            dy := islandY - positions[i].Y;
            if Sqrt(dx*dx + dy*dy) < distanceBetweenIslands - 0.5 then // Небольшой зазор
            begin
              canPlace := False;
              Break;
            end;
          end;

          if canPlace then
          begin
            SetLength(positions, Length(positions) + 1);
            positions[High(positions)] := Point(islandX, islandY);
          end;
        end;
      end;

      // Если не удалось добавить острова в этом кольце, переходим к следующему
      Inc(ring);
      Inc(attempts);

      // Защита от бесконечного цикла (максимум 3 кольца)
      if ring > 3 then Break;
    end;

    // Если все еще не хватает островов, добавляем случайные с проверкой перекрытия
    maxAttempts := AIslandCount * 10; // Максимум 10 попыток на остров
    attempts := 0;

    while (Length(positions) < AIslandCount) and (attempts < maxAttempts) do
    begin
      // Случайная точка внутри допустимой области
      angle := 2 * Pi * Random;
      hexRadius := Random * (planetRadius - islandRadius);

      islandX := Round(Cos(angle) * hexRadius);
      islandY := Round(Sin(angle) * hexRadius);

      // Проверка на перекрытие
      canPlace := True;
      for i := 0 to Length(positions) - 1 do
      begin
        dx := islandX - positions[i].X;
        dy := islandY - positions[i].Y;
        if Sqrt(dx*dx + dy*dy) < distanceBetweenIslands then
        begin
          canPlace := False;
          Break;
        end;
      end;

      if canPlace then
      begin
        SetLength(positions, Length(positions) + 1);
        positions[High(positions)] := Point(islandX, islandY);
      end;

      Inc(attempts);
    end;

    // Отрисовываем острова
    for i := 0 to Min(AIslandCount, Length(positions)) - 1 do
    begin
      // Позиция острова относительно центра планеты
      islandX := AX + positions[i].X;
      islandY := AY + positions[i].Y;

      // Генерация комплементарного цвета острова
      islandColor := GenerateComplementaryIslandColor(ABaseColor);

      // Остров как маленький круг с масштабированием
      ABmp.FillEllipseAntialias(islandX, islandY, islandRadius, islandRadius, islandColor);
    end;
  end;

  // Четкое ядро планеты (меньше, чтобы не перекрывать острова) с масштабированием
  ABmp.FillEllipseAntialias(AX, AY, Max(1, Round(2 * AScale)), Max(1, Round(2 * AScale)), ABaseColor);
end;

procedure TForm1.DrawCosmosBackground(ABmp: TBGRABitmap);
var
  i, x, y: Integer;
  c: TBGRAPixel;
  tempBmp: TBGRABitmap;
  radius: Integer;
begin
  // Создаем глубокий космос (темно-синий градиент)
  for y := 0 to ABmp.Height - 1 do
  begin
    for x := 0 to ABmp.Width - 1 do
    begin
      // Базовый темно-синий цвет
      c := BGRA(5, 10, 40, 255);

      // Добавляем немного шума для текстуры
      c.red := min(255, c.red + Random(10));
      c.green := min(255, c.green + Random(15));
      c.blue := min(255, c.blue + Random(20));

      ABmp.SetPixel(x, y, c);
    end;
  end;
end;

procedure TForm1.RenderFrame(ACanvas: TCanvas);
var
  bmp: TBGRABitmap;
  i, parentIndex: Integer;
  BaseColor: TBGRAPixel;
  IsBlackHole: Boolean;
  parentX, parentY: Integer;
  orbitX, orbitY: Integer;
begin
  bmp := TBGRABitmap.Create(ClientWidth, ClientHeight);
  try
    DrawCosmosBackground(bmp);

    RandSeed := 42; // Чтобы звезды не прыгали
    for i := 1 to 15 do
    begin
      // Генерируем тестовые данные, если они пустые
      if Nodes[i].TotalWeight = 0 then
      begin
        Nodes[i].Importance := Random;
        Nodes[i].Novelty := Random;
        Nodes[i].TotalWeight := Random(30);

        // Определяем родительскую планету
        if i <= 5 then
        begin
          // Первые 5 планет - родительские (центральные)
          Nodes[i].ParentIndex := 0; // Нет родителя
          Nodes[i].X := 50 + Random(bmp.Width - 100);
          Nodes[i].Y := 50 + Random(bmp.Height - 100);
          Nodes[i].OrbitRadius := 0;
          Nodes[i].OrbitAngle := 0;
          Nodes[i].OrbitSpeed := 0;
        end
        else
        begin
          // Остальные планеты - спутники родительских планет
          // Каждая родительская планета имеет 2 спутника
          parentIndex := ((i - 6) div 2) + 1;
          if parentIndex > 5 then parentIndex := 5;

          Nodes[i].ParentIndex := parentIndex;

          // Устанавливаем параметры орбиты
          // Радиус орбиты зависит от масштаба родительской планеты
          Nodes[i].OrbitRadius := 40 + Random(60); // Радиус орбиты от 40 до 100
          Nodes[i].OrbitAngle := 2 * Pi * Random; // Начальный случайный угол
          Nodes[i].OrbitSpeed := 0; // Анимация не нужна, скорость = 0

          // Позиция будет рассчитана позже, после генерации родительских планет
          Nodes[i].X := 0;
          Nodes[i].Y := 0;
        end;

        // Определяем количество островов на основе важности
        // Round(Importance * 7) + 1 дает диапазон 1-8 островов
        Nodes[i].IslandCount := Round(Nodes[i].Importance * 7) + 1;
        // Ограничиваем от 1 до 8 островов
        if Nodes[i].IslandCount < 1 then Nodes[i].IslandCount := 1;
        if Nodes[i].IslandCount > 8 then Nodes[i].IslandCount := 8;

        // Устанавливаем масштаб
        if Nodes[i].ParentIndex = 0 then
        begin
          // Родительские планеты: масштаб от 0.5 до 1.5
          Nodes[i].Scale := 0.5 + Nodes[i].Importance * 1.0;
        end
        else
        begin
          // Спутники: масштаб меньше родительских (от 0.2 до 0.8)
          Nodes[i].Scale := 0.2 + Nodes[i].Importance * 0.6;
        end;

        if Nodes[i].Scale <= 0 then Nodes[i].Scale := 0.1;
      end;

      // Условие Черной Дыры
      IsBlackHole := (Nodes[i].Importance < 0.2) and (Nodes[i].TotalWeight > 18);

      // Логика цвета
      if IsBlackHole then
        BaseColor := BGRABlack
      else if Nodes[i].Novelty > 0.7 then
        BaseColor := BGRA(100, 180, 255, 255) // Синий
      else if Nodes[i].Importance < 0.3 then
        BaseColor := BGRA(160, 160, 160, 255) // Серый астероид
      else
        BaseColor := BGRA(255, 255, 255, 255); // Белый (Важно)

      // Расчет позиции для спутников
      if Nodes[i].ParentIndex > 0 then
      begin
        // Получаем позицию родительской планеты
        parentX := Nodes[Nodes[i].ParentIndex].X;
        parentY := Nodes[Nodes[i].ParentIndex].Y;

        // Рассчитываем позицию на орбите
        orbitX := Round(parentX + Cos(Nodes[i].OrbitAngle) * Nodes[i].OrbitRadius);
        orbitY := Round(parentY + Sin(Nodes[i].OrbitAngle) * Nodes[i].OrbitRadius);

        Nodes[i].X := orbitX;
        Nodes[i].Y := orbitY;
      end;

      // Отрисовка с масштабированием
      if IsBlackHole then
      begin
        // Черная дыра с размытым оранжевым горизонтом событий
        DrawBlurredCircle(bmp, Nodes[i].X, Nodes[i].Y,
          BGRA(255, 140, 0, 180), 12, 4, Nodes[i].Scale);

        // Черное ядро (остается четким) с масштабированием
        bmp.FillEllipseAntialias(Nodes[i].X, Nodes[i].Y,
          Max(1, Round(8 * Nodes[i].Scale)), Max(1, Round(8 * Nodes[i].Scale)), BGRABlack);
      end
      else
      begin
        // Планета с островами с масштабированием
        DrawPlanetWithIslands(bmp, Nodes[i].X, Nodes[i].Y, BaseColor,
          Nodes[i].IslandCount, Nodes[i].Scale);
      end;
    end;

    bmp.Draw(ACanvas, 0, 0, True);
  finally
    bmp.Free;
  end;
end;

procedure TForm1.DrawThesisOrbits(ACanvas: TBGRABitmap; Center: TPointF; RX, RY: Single; AScale: Single);
var
  MainColor: TBGRAPixel;
begin
  // Цвет: Нежно-голубой газ с прозрачностью (160 из 255)
  // Это "базовый" цвет объекта мейкера
  MainColor := BGRA(150, 200, 255, 50);

  // Рисуем одно газовое кольцо.
  // Его внутренний край — зона аргументов, внешний — контраргументов.
  // RX + 30 — это дистанция кольца от центра объекта
  DrawGaseousRing(ACanvas, Center, RX + 30, RY + 30, AScale, MainColor);
end;

procedure TForm1.FormCreate(Sender: TObject);
var
  i: Integer;
begin
  DoubleBuffered := True;
  // Инициализируем все узлы нулевыми значениями
  for i := 1 to 15 do
  begin
    Nodes[i].Importance := 0;
    Nodes[i].Novelty := 0;
    Nodes[i].TotalWeight := 0;
    Nodes[i].X := 0;
    Nodes[i].Y := 0;
    Nodes[i].IslandCount := 0;
    Nodes[i].Scale := 1.0; // Начальный масштаб
    Nodes[i].ParentIndex := 0; // По умолчанию нет родителя
    Nodes[i].OrbitRadius := 0;
    Nodes[i].OrbitAngle := 0;
    Nodes[i].OrbitSpeed := 0;
  end;
end;

procedure TForm1.FormPaint(Sender: TObject);
begin
  RenderFrame(Canvas);
end;

end.
