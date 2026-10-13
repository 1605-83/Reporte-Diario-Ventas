# Sondeo (solo lectura): como vienen las carteras de clientes por vendedor en la base de Gescom
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
Ver 'totales' "SELECT COUNT(*) AS total, SUM(activo) AS activos, MAX(actualizado) AS actualizado FROM clientes"
Ver 'activos por vendedor (primera ruta)' "SELECT vendedor, COUNT(*) AS n FROM clientes WHERE activo = 1 GROUP BY vendedor ORDER BY n DESC"
Ver 'ejemplo de rutas con mas de una ruta' "SELECT codigo, vendedor, frecuencia, rutas FROM clientes WHERE activo = 1 AND rutas LIKE '%},{%' LIMIT 4"
Ver 'ejemplo de rutas simple' "SELECT codigo, vendedor, rutas FROM clientes WHERE activo = 1 LIMIT 2"
Ver 'clientes por vendedor contando todas sus rutas' "SELECT json_extract(r.value, '$.vendedor') AS vend, COUNT(DISTINCT c.codigo) AS n FROM clientes c, json_each(c.rutas) r WHERE c.activo = 1 GROUP BY vend ORDER BY n DESC"
Ver 'clientes con rutas de mas de un vendedor' "SELECT COUNT(*) AS n FROM (SELECT c.codigo FROM clientes c, json_each(c.rutas) r WHERE c.activo = 1 GROUP BY c.codigo HAVING COUNT(DISTINCT json_extract(r.value, '$.vendedor')) > 1)"
Ver 'ventas de octubre: clientes que no estan en la tabla' "SELECT COUNT(DISTINCT v.cliente) AS clientes, COUNT(DISTINCT CASE WHEN c.codigo IS NULL THEN v.cliente END) AS sin_ficha, COUNT(DISTINCT CASE WHEN c.activo = 0 THEN v.cliente END) AS inactivos FROM ventas v LEFT JOIN clientes c ON c.codigo = v.cliente WHERE v.fecha >= '2026-10-01'"
Ver 'mismo codigo de cliente en dos empresas' "SELECT COUNT(*) AS n FROM (SELECT cliente FROM ventas WHERE fecha >= '2026-09-01' GROUP BY cliente HAVING COUNT(DISTINCT empresa) > 1)"
Ver 'vendedor de la ficha vs vendedor de la venta (octubre)' "SELECT SUM(CASE WHEN c.vendedor = v.vendedor THEN 1 ELSE 0 END) AS igual, SUM(CASE WHEN c.vendedor <> v.vendedor THEN 1 ELSE 0 END) AS distinto FROM (SELECT DISTINCT cliente, vendedor FROM ventas WHERE fecha >= '2026-10-01' AND tipo = 'VEN') v JOIN clientes c ON c.codigo = v.cliente"
