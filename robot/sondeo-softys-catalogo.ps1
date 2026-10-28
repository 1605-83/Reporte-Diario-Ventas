# Sondeo (solo lectura, sin datos de clientes): Babysec Multiuso y Maxwipe para el catalogo Softys (pedido de Bruno, 28/10/2026)
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
$W = "UPPER(a.descripcion) LIKE '%MULTIUSO%' OR UPPER(a.descripcion) LIKE '%MAXWIPE%' OR UPPER(a.descripcion) LIKE '%MAX WIPE%' OR a.codigo IN ('1506385','1506286') OR a.codigo LIKE '%6385' OR a.codigo LIKE '%6286'"
Ver 'articulos' "SELECT a.codigo, a.descripcion, a.proveedor, a.unidades_bulto, a.bloqueado FROM articulos a WHERE $W LIMIT 40"
Ver 'precios lista 1' "SELECT p.* FROM precios p JOIN articulos a ON a.codigo = p.articulo WHERE p.lista = '1' AND ($W) LIMIT 60"
