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
$V = "('53','053','27','027','54','054','30','030')"
$C = "FROM clientes c WHERE c.activo = 1 AND CAST(c.vendedor AS INTEGER) IN (53,27,54,30)"
Ver 'columnas de clientes' "SELECT sql FROM sqlite_master WHERE name = 'clientes'"
Ver 'por vendedor: total, con rutas, cantidad de rutas, vendedor de la primera ruta distinto' "SELECT CAST(c.vendedor AS INTEGER) AS ven, COUNT(*) AS total,
  SUM(CASE WHEN json_valid(c.rutas) AND json_array_length(c.rutas) > 0 THEN 1 ELSE 0 END) AS con_ruta,
  SUM(CASE WHEN json_valid(c.rutas) AND json_array_length(c.rutas) > 1 THEN 1 ELSE 0 END) AS mas_de_una_ruta,
  SUM(CASE WHEN json_valid(c.rutas) AND CAST(json_extract(c.rutas,'$[0].vendedor') AS INTEGER) <> CAST(c.vendedor AS INTEGER) THEN 1 ELSE 0 END) AS ruta_de_otro,
  SUM(CASE WHEN NULLIF(json_extract(c.rutas,'$[0].dias'),'') IS NULL THEN 1 ELSE 0 END) AS sin_dia
  $C GROUP BY 1 ORDER BY 1"
Ver 'por vendedor y mes de alta' "SELECT CAST(c.vendedor AS INTEGER) AS ven, substr(c.alta,1,7) AS mes_alta, COUNT(*) AS n $C GROUP BY 1,2 ORDER BY 1,2"
Ver 'por vendedor y fecha de alta desde octubre' "SELECT CAST(c.vendedor AS INTEGER) AS ven, substr(c.alta,1,10) AS alta, COUNT(*) AS n $C AND c.alta >= '2026-10-01' GROUP BY 1,2 ORDER BY 1,2"
Ver 'por vendedor y frecuencia' "SELECT CAST(c.vendedor AS INTEGER) AS ven, c.frecuencia, COUNT(*) AS n $C GROUP BY 1,2 ORDER BY 1,2"
Ver 'por vendedor y frecuencia de la primera ruta' "SELECT CAST(c.vendedor AS INTEGER) AS ven, json_extract(c.rutas,'$[0].frecuencia') AS frec, COUNT(*) AS n $C GROUP BY 1,2 ORDER BY 1,2"
Ver 'por vendedor y dia' "SELECT CAST(c.vendedor AS INTEGER) AS ven, json_extract(c.rutas,'$[0].dias') AS dias, COUNT(*) AS n $C GROUP BY 1,2 ORDER BY 1,2"
Ver 'por vendedor y primera visita' "SELECT CAST(c.vendedor AS INTEGER) AS ven, substr(json_extract(c.rutas,'$[0].primera_visita'),1,7) AS pv1, substr(json_extract(c.rutas,'$[0].primeraVisita'),1,7) AS pv2, COUNT(*) AS n $C GROUP BY 1,2,3 ORDER BY 1,2,3"
Ver 'claves del JSON de rutas (un ejemplo sin datos)' "SELECT json_group_array(DISTINCT j.key) AS claves FROM clientes c, json_each(json_extract(c.rutas,'$[0]')) j WHERE c.activo = 1 AND json_valid(c.rutas)"
Ver 'por vendedor y ramo' "SELECT CAST(c.vendedor AS INTEGER) AS ven, c.ramo, COUNT(*) AS n $C GROUP BY 1,2 ORDER BY 1,3 DESC"
Ver 'por vendedor, con baja cargada' "SELECT CAST(c.vendedor AS INTEGER) AS ven, SUM(CASE WHEN NULLIF(c.baja,'') IS NOT NULL THEN 1 ELSE 0 END) AS con_baja, SUM(CASE WHEN c.latitud IS NULL OR c.latitud = 0 THEN 1 ELSE 0 END) AS sin_ubicacion $C GROUP BY 1 ORDER BY 1"

# Los 22 clientes que estan en la cartera pero no en la exportacion de clientes de Gescom que paso Bruno (21/10/2026 16:30)
$X = "('101466','103062','106218','106559','108768','197','3186','3229','326','329372','3557','4153','5799','711','104111','106161','106162','106273','107503','107885','3039','388')"
Ver 'los 22: estado en la base (sin datos personales)' "SELECT c.codigo, c.activo, c.alta, c.baja, c.actualizado, CAST(c.vendedor AS INTEGER) AS ven, json_extract(c.rutas,'$[0].ruta') AS ruta, json_extract(c.rutas,'$[0].dias') AS dias, c.ramo, c.lista_precio FROM clientes c WHERE c.codigo IN $X OR ltrim(c.codigo,'0') IN $X ORDER BY 6, 1"
Ver 'ultima venta de cada uno' "SELECT v.cliente, MAX(v.fecha) AS ultima, COUNT(*) AS ventas FROM ventas v WHERE v.cliente IN $X OR ltrim(v.cliente,'0') IN $X GROUP BY v.cliente"
Ver 'cuando se actualizaron los clientes por ultima vez' "SELECT MAX(c.actualizado) AS max_act, MIN(c.actualizado) AS min_act FROM clientes c"
