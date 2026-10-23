# Sondeo (solo lectura): como armar el tablero de vencimientos "lo que mas plata pone en riesgo" (pedido de Bruno,
# 22/10/2026) con las tablas del deposito (Digip). Solo articulos: no imprime clientes (el registro de Actions es publico).
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
foreach ($t in 'digip_analitico','digip_stock','digip_vencimientos','digip_articulos','articulos','precios') { Ver "columnas de $t" "SELECT name, type FROM pragma_table_info('$t')" }
Ver 'analitico: dias cargados' "SELECT dia, COUNT(*) AS n FROM digip_analitico GROUP BY dia ORDER BY dia DESC LIMIT 10"
Ver 'stock y vencimientos: ultima actualizacion' "SELECT 'stock' AS t, MAX(actualizado) AS ult, COUNT(*) AS n FROM digip_stock UNION ALL SELECT 'venc', MAX(actualizado), COUNT(*) FROM digip_vencimientos"
$Q = "('MUZZARELLA LINEA DORADA','CUARTIROLO LINEA DORADA','Poroto TAYAL 300g x 24u','CONGUITOS MANI CON CHOCOLATE 24u')"
Ver 'analitico del ultimo dia, articulos de la captura' "SELECT * FROM digip_analitico WHERE dia = (SELECT MAX(dia) FROM digip_analitico) AND (descripcion IN $Q OR descripcion LIKE 'MUZZARELLA LINEA%' OR descripcion LIKE 'Poroto TAYAL%')"
Ver 'stock por lote de esos articulos' "SELECT articulo, descripcion, lote, vencimiento, dias_vencimiento, cantidad, bultos, unidades_sueltas, estado, area, critico FROM digip_stock WHERE descripcion IN $Q OR descripcion LIKE 'MUZZARELLA LINEA%' OR descripcion LIKE 'Poroto TAYAL%' ORDER BY articulo, vencimiento"
Ver 'vencimientos de esos articulos' "SELECT tipo, articulo, descripcion, vencimiento, dias, unidades, min_dias FROM digip_vencimientos WHERE descripcion IN $Q OR descripcion LIKE 'MUZZARELLA LINEA%' OR descripcion LIKE 'Poroto TAYAL%'"
Ver 'tipos de vencimientos' "SELECT tipo, COUNT(*) AS n, MIN(dias) AS min, MAX(dias) AS max FROM digip_vencimientos GROUP BY tipo"
Ver 'articulos de Gescom de esos codigos' "SELECT a.codigo, a.descripcion, a.unidades_bulto, a.costo_bulto, a.factor_peso, a.empresa, a.proveedor FROM articulos a WHERE a.codigo IN (SELECT DISTINCT articulo FROM digip_stock WHERE descripcion IN $Q OR descripcion LIKE 'MUZZARELLA LINEA%' OR descripcion LIKE 'Poroto TAYAL%')"
Ver 'precios lista 1 de esos codigos' "SELECT articulo, lista, unidad, factor, default_venta, neto, alicuota_iva FROM precios WHERE articulo IN (SELECT DISTINCT articulo FROM digip_stock WHERE descripcion LIKE 'MUZZARELLA LINEA%' OR descripcion LIKE 'Poroto TAYAL%') AND lista IN ('1','01','001') "
Ver 'stock: estados y areas' "SELECT estado, area, COUNT(*) AS n, SUM(cantidad) AS cant FROM digip_stock GROUP BY 1,2 ORDER BY 3 DESC LIMIT 20"
