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
Ver 'columnas de venta_items' "SELECT name, type FROM pragma_table_info('venta_items')"
Ver 'quesos: gramos por unidad vendida (30 dias)' "SELECT i.articulo, COUNT(*) AS renglones, SUM(i.cantidad) AS cant, AVG(i.factor) AS factor, MIN(i.cantidad) AS mn, MAX(i.cantidad) AS mx FROM venta_items i JOIN ventas v ON v.id = i.venta_id WHERE i.articulo IN ('711','715') AND v.fecha >= date('now','-30 day') GROUP BY i.articulo"
Ver 'pesables en el deposito (unidades_bulto 1000)' "SELECT s.articulo, s.descripcion, SUM(s.cantidad) AS stock, a.unidades_bulto, a.costo_bulto FROM digip_stock s JOIN articulos a ON a.codigo = s.articulo WHERE a.unidades_bulto >= 500 GROUP BY s.articulo"
Ver 'codigos de barras de los quesos' "SELECT articulo, presentacion, unidades, tipo FROM digip_codigos_barras WHERE articulo IN ('711','715')"
Ver 'articulos de digip sin articulo en Gescom' "SELECT COUNT(DISTINCT s.articulo) AS n FROM digip_stock s LEFT JOIN articulos a ON a.codigo = s.articulo WHERE a.codigo IS NULL"
Ver 'muestra de calculo: top en riesgo hoy' "WITH st AS (SELECT articulo, MIN(vencimiento) AS vence, MIN(dias) AS dias FROM digip_vencimientos WHERE tipo='proximo' GROUP BY articulo), stk AS (SELECT articulo, SUM(cantidad) AS stock FROM digip_stock GROUP BY articulo), an AS (SELECT articulo, vendido_30 FROM digip_analitico WHERE dia=(SELECT MAX(dia) FROM digip_analitico)) SELECT st.articulo, a.descripcion, st.vence, st.dias, stk.stock, an.vendido_30, MAX(0, stk.stock - COALESCE(an.vendido_30,0)/30.0*st.dias) AS sin_vender, a.costo_bulto/NULLIF(a.unidades_bulto,0) AS costo_u FROM st JOIN stk ON stk.articulo=st.articulo LEFT JOIN an ON an.articulo=st.articulo LEFT JOIN articulos a ON a.codigo=st.articulo ORDER BY sin_vender * COALESCE(a.costo_bulto/NULLIF(a.unidades_bulto,0),0) DESC LIMIT 12"
