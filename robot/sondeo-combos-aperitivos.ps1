# Sondeo (solo lectura, sin datos de clientes): que son los codigos 3791, 2732, 4996 y 0027 que pidio Bruno (27/10/2026)
$ErrorActionPreference = 'Stop'
$clave = $env:GESCOM_LPE_CLAVE; if (-not $clave) { throw 'Falta la variable de entorno GESCOM_LPE_CLAVE' }
$BASE = 'https://datos-gescom.panelempresas.workers.dev'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
function Sql([string]$sql) {
  $p = @{ Uri = "$BASE/consulta"; Method = 'POST'; UseBasicParsing = $true; Headers = @{ Authorization = "Bearer $clave" }; ContentType = 'application/json'
          Body = [Text.Encoding]::UTF8.GetBytes((@{ sql = $sql } | ConvertTo-Json -Compress)) }
  $r = Invoke-WebRequest @p; $j = [Text.Encoding]::UTF8.GetString($r.RawContentStream.ToArray()) | ConvertFrom-Json
  if ($j.error) { "ERROR: $($j.error)"; return }; $j.filas }
function Ver($t, $s) { "===== $t"; try { Sql $s | ConvertTo-Json -Depth 5 -Compress } catch { "FALLO: $_" } }
$C = "('3791','2732','4996','0027','27')"
Ver 'como articulos' "SELECT a.codigo, a.descripcion, a.proveedor, p.nombre AS prov FROM articulos a LEFT JOIN proveedores p ON p.codigo = a.proveedor WHERE a.codigo IN $C OR ltrim(a.codigo,'0') IN $C"
Ver 'como combos: renglones y unidades desde el 22/10' "SELECT c.combo, COUNT(*) AS renglones, SUM(c.cantidad) AS cant, MIN(v.fecha) AS desde, MAX(v.fecha) AS hasta FROM venta_combos c JOIN ventas v ON v.id = c.venta_id WHERE (c.combo IN $C OR ltrim(c.combo,'0') IN $C) AND v.fecha >= '2026-10-22' GROUP BY c.combo"
Ver 'todos los combos vendidos desde el 22/10' "SELECT c.combo, COUNT(*) AS renglones, SUM(c.cantidad) AS cant FROM venta_combos c JOIN ventas v ON v.id = c.venta_id WHERE v.fecha >= '2026-10-22' GROUP BY c.combo ORDER BY 2 DESC"
Ver 'tablas con combo en el nombre' "SELECT name FROM sqlite_master WHERE type IN ('table','view') AND name LIKE '%combo%'"
