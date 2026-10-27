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
Ver 'estructura combos' "SELECT name, sql FROM sqlite_master WHERE name IN ('combos','combo_componentes')"
Ver 'combos 1137 a 1145' "SELECT * FROM combos WHERE CAST(codigo AS INTEGER) BETWEEN 1137 AND 1145"
Ver 'componentes de 1138 a 1145' "SELECT * FROM combo_componentes WHERE CAST(combo AS INTEGER) BETWEEN 1138 AND 1145"
Ver 'articulos con 3791 2732 4996 o 0027 dentro del codigo' "SELECT a.codigo, a.descripcion, p.nombre AS prov FROM articulos a LEFT JOIN proveedores p ON p.codigo = a.proveedor WHERE a.codigo LIKE '%3791%' OR a.codigo LIKE '%2732%' OR a.codigo LIKE '%4996%' OR a.codigo LIKE '%0027' LIMIT 40"
Ver 'articulos gancia fernet 1882 martini amargo obrero' "SELECT a.codigo, a.descripcion, p.nombre AS prov FROM articulos a LEFT JOIN proveedores p ON p.codigo = a.proveedor WHERE UPPER(a.descripcion) LIKE '%GANCIA%' OR UPPER(a.descripcion) LIKE '%1882%' OR UPPER(a.descripcion) LIKE '%MARTINI%' OR UPPER(a.descripcion) LIKE '%OBRERO%' OR UPPER(a.descripcion) LIKE '%BOLSA%' LIMIT 60"
