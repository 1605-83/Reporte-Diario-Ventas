# Sondeo (solo lectura, sin datos de clientes): todos los combos de Gescom y sus componentes, para armar el Excel
# de combos de Softys (pedido de Bruno, 18/11/2026). El detalle se guarda en archivos (artefacto de la corrida);
# en el log solo se imprimen la estructura y cantidades.
$ErrorActionPreference = 'Stop'
$clave = $env:GESCOM_LPE_CLAVE; if (-not $clave) { throw 'Falta la variable de entorno GESCOM_LPE_CLAVE' }
$BASE = 'https://datos-gescom.panelempresas.workers.dev'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
function Sql([string]$sql) {
  $p = @{ Uri = "$BASE/consulta"; Method = 'POST'; UseBasicParsing = $true; Headers = @{ Authorization = "Bearer $clave" }; ContentType = 'application/json'
          Body = [Text.Encoding]::UTF8.GetBytes((@{ sql = $sql } | ConvertTo-Json -Compress)) }
  $r = Invoke-WebRequest @p; $j = [Text.Encoding]::UTF8.GetString($r.RawContentStream.ToArray()) | ConvertFrom-Json
  if ($j.error) { throw $j.error }; $j.filas }
$dir = New-Item -ItemType Directory -Force 'salida-combos'
"===== estructura"
Sql "SELECT name, sql FROM sqlite_master WHERE name IN ('combos','combo_componentes')" | ConvertTo-Json -Depth 4 -Compress
$q = [ordered]@{
  combos      = "SELECT * FROM combos"
  componentes = "SELECT * FROM combo_componentes"
  articulos   = "SELECT a.*, p.nombre AS prov_nombre FROM articulos a LEFT JOIN proveedores p ON p.codigo = a.proveedor WHERE a.codigo IN (SELECT articulo FROM combo_componentes) OR CAST(a.codigo AS TEXT) IN (SELECT CAST(articulo AS TEXT) FROM combo_componentes)"
  vendidos    = "SELECT c.combo, substr(v.fecha,1,7) AS mes, SUM(c.cantidad) AS cant FROM venta_combos c JOIN ventas v ON v.id = c.venta_id WHERE v.tipo = 'VEN' AND v.fecha >= '2026-09-01' GROUP BY c.combo, substr(v.fecha,1,7)"
}
foreach ($k in $q.Keys) {
  try { $f = @(Sql $q[$k]); "$k : $($f.Count) filas"; [IO.File]::WriteAllText((Join-Path $dir "$k.json"), ($f | ConvertTo-Json -Depth 4), (New-Object Text.UTF8Encoding $false)) }
  catch { "$k : FALLO $_" }
}
