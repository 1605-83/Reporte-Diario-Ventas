# Sondeo (solo lectura, solo conteos): por que la cartera de algunos vendedores tiene mas clientes que la base que
# Bruno ve en Gescom (pedido de Bruno, 21/10/2026: 53 = 159, 27 = 134, 54 = 137, 30 = 134; la cartera da 172, 140, 138, 135).
# No imprime nombres ni datos de clientes: el registro de Actions del repo es publico.
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

# ---- 26/11/2026: Bruno dio de baja clientes del vendedor 2 en Gescom y la cartera sigue en 152. Solo conteos. ----
$C2 = "FROM clientes c WHERE CAST(c.vendedor AS INTEGER) = 2"
Ver 'v2: activos, inactivos, con baja' "SELECT c.activo, SUM(CASE WHEN NULLIF(c.baja,'') IS NOT NULL THEN 1 ELSE 0 END) AS con_baja, COUNT(*) AS n $C2 GROUP BY 1"
Ver 'v2: por dia de ultima actualizacion y activo' "SELECT substr(c.actualizado,1,10) AS dia, c.activo, COUNT(*) AS n $C2 GROUP BY 1,2 ORDER BY 1 DESC LIMIT 15"
Ver 'todos: actualizados hoy por activo' "SELECT c.activo, COUNT(*) AS n FROM clientes c WHERE c.actualizado >= date('now','-1 day') GROUP BY 1"
Ver 'todos: ultima actualizacion' "SELECT MAX(c.actualizado) AS max_act FROM clientes c"
Ver 'v2: valores de baja (fechas)' "SELECT substr(c.baja,1,10) AS baja, c.activo, COUNT(*) AS n $C2 AND NULLIF(c.baja,'') IS NOT NULL GROUP BY 1,2 ORDER BY 1 DESC LIMIT 10"
Ver 'tablas de la base' "SELECT name FROM sqlite_master WHERE type='table'"
