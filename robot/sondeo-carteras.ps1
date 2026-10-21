# Sondeo (solo lectura): nombre exacto del proveedor LAS TRES NINAS en Gescom (pedido de Bruno, 21/10/2026: sumarlo a OTM)
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
$P = "(UPPER(p.nombre) LIKE '%NI%AS%' OR UPPER(p.nombre) LIKE '%TRES%' OR p.nombre LIKE '%3%' OR UPPER(p.nombre) LIKE '%NENAS%')"
Ver 'proveedores parecidos' "SELECT p.codigo, p.nombre FROM proveedores p WHERE $P ORDER BY p.nombre"
Ver 'articulos con TRES NI o 3 NI en la descripcion' "SELECT a.codigo, a.descripcion, a.proveedor, p.nombre AS prov FROM articulos a LEFT JOIN proveedores p ON p.codigo = a.proveedor WHERE UPPER(a.descripcion) LIKE '%TRES NI%' OR UPPER(a.descripcion) LIKE '%3 NI%' LIMIT 40"
Ver 'venta de octubre de esos proveedores' "SELECT p.codigo, p.nombre, COUNT(*) AS renglones, ROUND(SUM(i.total),2) AS total FROM ventas v JOIN venta_items i ON i.venta_id = v.id JOIN articulos a ON a.codigo = i.articulo JOIN proveedores p ON p.codigo = a.proveedor WHERE $P AND v.fecha >= '2026-10-01' GROUP BY p.codigo, p.nombre"
