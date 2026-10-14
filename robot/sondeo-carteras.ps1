# Sondeo (solo lectura): cartera del vendedor 054 en la ficha de clientes de Gescom, para ver por que da 145 y no 147
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
$R = "EXISTS (SELECT 1 FROM json_each(c.rutas) r WHERE json_extract(r.value,'$.vendedor') IN ('054','54'))"
Ver 'ficha actualizada' "SELECT MAX(actualizado) AS actualizado FROM clientes"
Ver 'con 054 en alguna ruta, por activo' "SELECT activo, COUNT(*) AS n FROM clientes c WHERE $R GROUP BY activo"
Ver 'vendedor 054 en la ficha, por activo' "SELECT activo, COUNT(*) AS n FROM clientes c WHERE c.vendedor IN ('054','54') GROUP BY activo"
Ver 'rutas del 054' "SELECT json_extract(r.value,'$.ruta') AS ruta, json_extract(r.value,'$.dias') AS dias, c.activo, COUNT(*) AS n FROM clientes c, json_each(c.rutas) r WHERE json_extract(r.value,'$.vendedor') IN ('054','54') GROUP BY ruta, dias, c.activo"
Ver 'del 054 pero inactivos (bajas)' "SELECT c.codigo, COALESCE(NULLIF(c.razon_social,''), c.nombre) AS n, c.baja, c.alta FROM clientes c WHERE ($R OR c.vendedor IN ('054','54')) AND c.activo = 0"
Ver 'ruta del 054 pero otro vendedor en la ficha' "SELECT c.codigo, c.vendedor, c.rutas FROM clientes c WHERE $R AND COALESCE(c.vendedor,'') NOT IN ('054','54')"
Ver 'altas recientes del 054' "SELECT c.codigo, COALESCE(NULLIF(c.razon_social,''), c.nombre) AS n, c.alta FROM clientes c WHERE c.vendedor IN ('054','54') AND c.alta IS NOT NULL ORDER BY c.alta DESC LIMIT 10"
Ver 'clientes con venta del 054 en octubre que no estan en su cartera activa' "SELECT v.cliente, COALESCE(NULLIF(c.razon_social,''), c.nombre) AS n, c.vendedor, c.activo, COUNT(*) AS comprobantes FROM ventas v LEFT JOIN clientes c ON c.codigo = v.cliente WHERE v.vendedor IN ('054','54') AND v.fecha >= '2026-10-01' AND NOT (c.activo = 1 AND c.vendedor IN ('054','54')) GROUP BY v.cliente"
