# Sondeo (solo lectura, solo conteos y nombres de columnas): desde cuando hay ventas en la base y si la ficha del
# cliente trae fecha de ultima compra (pedido de Bruno, 11/11/2026: no compradores de los ultimos 6 meses).
# No imprime datos de clientes (el registro de Actions es publico).
$ErrorActionPreference = 'Stop'
$clave = $env:GESCOM_LPE_CLAVE
if (-not $clave) { throw 'Falta la variable de entorno GESCOM_LPE_CLAVE' }
$BASE = 'https://datos-gescom.panelempresas.workers.dev'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
function Sql([string]$sql) {
  $p = @{ Uri = "$BASE/consulta"; Method = 'POST'; UseBasicParsing = $true; Headers = @{ Authorization = "Bearer $clave" }; ContentType = 'application/json'
          Body = [Text.Encoding]::UTF8.GetBytes((@{ sql = $sql } | ConvertTo-Json -Compress)) }
  $r = Invoke-WebRequest @p
  $j = [Text.Encoding]::UTF8.GetString($r.RawContentStream.ToArray()) | ConvertFrom-Json
  if ($j.error) { "ERROR: $($j.error)"; return }
  $j.filas
}
function Ver($titulo, $sql) { "===== $titulo"; try { Sql $sql | ConvertTo-Json -Depth 5 -Compress } catch { "FALLO: $_" } }
Ver 'tablas' "SELECT name FROM sqlite_master WHERE type IN ('table','view') ORDER BY name"
Ver 'columnas de clientes' "SELECT name, type FROM pragma_table_info('clientes')"
Ver 'columnas de ventas' "SELECT name, type FROM pragma_table_info('ventas')"
Ver 'ventas por mes' "SELECT substr(v.fecha,1,7) AS mes, COUNT(*) AS comprobantes, COUNT(DISTINCT v.cliente) AS clientes FROM ventas v GROUP BY 1 ORDER BY 1"
Ver 'primera y ultima venta' "SELECT MIN(v.fecha) AS desde, MAX(v.fecha) AS hasta FROM ventas v"
