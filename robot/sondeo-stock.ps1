# Sondeo (solo lectura): que tablas de la base de Gescom tienen stock y vencimientos por articulo/lote
# (pedido de Bruno, 22/10/2026: tablero "lo que mas plata pone en riesgo"). Solo estructura y conteos:
# el registro de Actions del repo es publico, no imprime clientes.
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
"===== estado"; try { (Invoke-WebRequest -Uri "$BASE/estado" -UseBasicParsing -Headers @{ Authorization = "Bearer $clave" }).Content } catch { "FALLO: $_" }
Ver 'tablas' "SELECT name, type FROM sqlite_master WHERE type IN ('table','view') ORDER BY name"
$tablas = @(Sql "SELECT name FROM sqlite_master WHERE type IN ('table','view') ORDER BY name") | ForEach-Object { $_.name }
foreach ($t in $tablas) {
  Ver "estructura de $t" "SELECT sql FROM sqlite_master WHERE name = '$t'"
  Ver "filas de $t" "SELECT COUNT(*) AS n FROM `"$t`""
}
