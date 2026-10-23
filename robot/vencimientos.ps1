# Tablero de vencimientos (pedido de Bruno, 22/10/2026): "lo que mas plata pone en riesgo".
# Lee de la base de Gescom las tablas del deposito (Digip): los lotes por vencer y vencidos, la venta de 30 dias
# del analitico y el costo del articulo, y arma vencimientos/datos.json para vencimientos/index.html.
#
# Por cada articulo, los lotes se venden en orden de vencimiento (primero el que vence antes):
#   venta esperada hasta que vence un lote = venta de 30 dias / 30 x dias que faltan
#   sin vender = unidades del lote que esa venta no alcanza a cubrir
#   en riesgo  = sin vender x costo de una unidad (costo del bulto / unidades del bulto)
# Los pesables (quesos, fiambres) tienen el costo por kilo y el deposito los cuenta por pieza: el peso de una pieza
# se estima con los gramos vendidos en Gescom en 30 dias / las piezas que el deposito dio por vendidas en 30 dias.
$ErrorActionPreference = 'Stop'
$clave = $env:GESCOM_LPE_CLAVE
if (-not $clave) { throw 'Falta la variable de entorno GESCOM_LPE_CLAVE' }
$BASE = 'https://datos-gescom.panelempresas.workers.dev'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
function Sql([string]$sql) {
  $p = @{ Uri = "$BASE/consulta"; Method = 'POST'; UseBasicParsing = $true; Headers = @{ Authorization = "Bearer $clave" }; ContentType = 'application/json'
          Body = [Text.Encoding]::UTF8.GetBytes((@{ sql = $sql } | ConvertTo-Json -Compress)) }
  # hasta 4 intentos: a veces la base corta la conexion
  for ($n = 1; ; $n++) {
    try { $r = Invoke-WebRequest @p; break }
    catch { if ($n -ge 4 -or ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -lt 500)) { throw }
      Write-Warning "La base no respondio (intento $n): $($_.Exception.Message). Reintento en $(15 * $n) s"; Start-Sleep -Seconds (15 * $n) }
  }
  $j = [Text.Encoding]::UTF8.GetString($r.RawContentStream.ToArray()) | ConvertFrom-Json
  if ($j.error) { throw "La base respondio error: $($j.error)" }
  @($j.filas)
}

$lotes = Sql "SELECT v.tipo, v.articulo, v.descripcion, v.vencimiento, v.dias, SUM(v.unidades) AS unidades, MAX(v.actualizado) AS act
  FROM digip_vencimientos v GROUP BY v.tipo, v.articulo, v.descripcion, v.vencimiento, v.dias"
$an = Sql "SELECT articulo, vendido_30, stock_disponible, dia FROM digip_analitico WHERE dia = (SELECT MAX(dia) FROM digip_analitico)"
$cods = @($lotes | ForEach-Object { "'" + ([string]$_.articulo).Replace("'", "''") + "'" } | Sort-Object -Unique) -join ','
if (-not $cods) { throw 'La base no devolvio lotes por vencer' }
$art = Sql "SELECT a.codigo, a.descripcion, a.unidades_bulto, a.costo_bulto, COALESCE(p.nombre, a.proveedor) AS proveedor
  FROM articulos a LEFT JOIN proveedores p ON p.codigo = a.proveedor WHERE a.codigo IN ($cods)"
$gramos = Sql "SELECT i.articulo, SUM(i.cantidad * COALESCE(NULLIF(i.factor,0),1)) AS g FROM venta_items i JOIN ventas v ON v.id = i.venta_id
  WHERE v.fecha >= date('now','-30 day') AND i.articulo IN (SELECT codigo FROM articulos WHERE codigo IN ($cods) AND unidades_bulto >= 500) GROUP BY i.articulo"

$A = @{}; foreach ($x in $art) { $A[[string]$x.codigo] = $x }
$V = @{}; foreach ($x in $an) { $V[[string]$x.articulo] = $x }
$G = @{}; foreach ($x in $gramos) { $G[[string]$x.articulo] = [double]$x.g }
$diaAn = ($an | Select-Object -First 1).dia
$actStock = ($lotes | Measure-Object -Property act -Maximum).Maximum

function CostoU([string]$c) {
  # costo de una unidad del deposito; $null si no se puede saber
  $a = $A[$c]; if (-not $a -or -not $a.costo_bulto -or -not $a.unidades_bulto) { return @{ c = $null; peso = $null } }
  if ([double]$a.unidades_bulto -ge 500) {   # pesable: costo por kilo (bulto de 1000 g)
    $v30 = if ($V[$c]) { [double]$V[$c].vendido_30 } else { 0 }
    if ($G[$c] -gt 0 -and $v30 -gt 0) { $g = $G[$c] / $v30; return @{ c = [double]$a.costo_bulto / [double]$a.unidades_bulto * $g; peso = [math]::Round($g / 1000, 2) } }
    return @{ c = $null; peso = $null }
  }
  @{ c = [double]$a.costo_bulto / [double]$a.unidades_bulto; peso = $null }
}

$filas = @(); $vencidos = @()
foreach ($grp in ($lotes | Where-Object { $_.tipo -eq 'proximo' } | Group-Object { [string]$_.articulo })) {
  $c = $grp.Name; $ls = @($grp.Group | Sort-Object vencimiento)
  $v30 = if ($V[$c] -and $V[$c].vendido_30) { [double]$V[$c].vendido_30 } else { 0 }
  $ritmo = $v30 / 30; $usado = 0; $sin = 0; $stock = 0
  foreach ($l in $ls) {
    $u = [double]$l.unidades; $stock += $u
    $cubre = [math]::Max(0, $ritmo * [math]::Max([double]$l.dias, 0) - $usado)   # venta que le queda a este lote antes de vencer
    $vende = [math]::Min($u, $cubre); $usado += $vende; $sin += $u - $vende
  }
  $k = CostoU $c; $a = $A[$c]
  $filas += [ordered]@{ art = $c; desc = ([string]$ls[0].descripcion).Trim(); prov = $(if ($a) { ([string]$a.proveedor).Trim() } else { '' })
    vence = $ls[0].vencimiento; dias = [int]$ls[0].dias; lotes = $ls.Count; stock = $stock; venta30 = $v30
    sin = [math]::Round($sin); costo = $(if ($k.c -ne $null) { [math]::Round($k.c, 2) } else { $null }); peso = $k.peso
    riesgo = $(if ($k.c -ne $null) { [math]::Round([math]::Round($sin) * $k.c) } else { $null }) }
}
foreach ($grp in ($lotes | Where-Object { $_.tipo -eq 'vencido' } | Group-Object { [string]$_.articulo })) {
  $c = $grp.Name; $ls = @($grp.Group | Sort-Object vencimiento); $u = ($ls | Measure-Object -Property unidades -Sum).Sum
  $k = CostoU $c; $a = $A[$c]
  $vencidos += [ordered]@{ art = $c; desc = ([string]$ls[0].descripcion).Trim(); prov = $(if ($a) { ([string]$a.proveedor).Trim() } else { '' })
    vence = $ls[0].vencimiento; dias = [int]$ls[0].dias; unidades = $u; costo = $(if ($k.c -ne $null) { [math]::Round($k.c, 2) } else { $null }); peso = $k.peso
    importe = $(if ($k.c -ne $null) { [math]::Round($u * $k.c) } else { $null }) }
}
$filas = @($filas | Sort-Object { if ($_.riesgo -ne $null) { $_.riesgo } else { -1 } } -Descending)
$vencidos = @($vencidos | Sort-Object { if ($_.importe -ne $null) { $_.importe } else { -1 } } -Descending)

$ahora = (Get-Date).ToUniversalTime().AddHours(-3)
$out = [ordered]@{ generado = $ahora.ToString('yyyy-MM-dd HH:mm'); stock_al = $actStock; venta_al = $diaAn; filas = $filas; vencidos = $vencidos }
New-Item -ItemType Directory -Force -Path 'vencimientos' | Out-Null
[IO.File]::WriteAllText((Join-Path (Get-Location) 'vencimientos\datos.json'), ($out | ConvertTo-Json -Depth 6 -Compress), (New-Object Text.UTF8Encoding $false))
$tot = ($filas | Where-Object { $_.riesgo -ne $null } | Measure-Object -Property riesgo -Sum).Sum
Write-Host "Vencimientos: $($filas.Count) articulos por vencer, $($vencidos.Count) vencidos, en riesgo `$ $([math]::Round($tot).ToString('N0')) (stock al $actStock, venta 30 dias al $diaAn)"
