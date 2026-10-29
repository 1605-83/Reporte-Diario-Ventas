# Combos vendidos en el mes por vendedor (pedido de Bruno, 20/10/2026), para "Clientes sin compra de Softys".
# Gescom guarda los combos aparte (tabla venta_combos): cada articulo del combo va con su propio codigo, por eso
# el combo no aparece en los CSV de ventas. Cuenta pedidos de hoy y facturados; las devoluciones restan.
# Uso: powershell -File robot\combos.ps1 [-Combos 1137] [-Salida .]
param([string[]]$Combos = @('1137'), [string]$Salida = '.')
$ErrorActionPreference = 'Stop'
$clave = $env:GESCOM_LPE_CLAVE; if (-not $clave) { throw 'Falta la variable de entorno GESCOM_LPE_CLAVE' }
$BASE = 'https://datos-gescom.panelempresas.workers.dev'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
function Sql([string]$q) {
  $p = @{ Uri = "$BASE/consulta"; Method = 'POST'; UseBasicParsing = $true; Headers = @{ Authorization = "Bearer $clave" }; ContentType = 'application/json'
          Body = [Text.Encoding]::UTF8.GetBytes((@{ sql = $q } | ConvertTo-Json -Compress)) }
  $r = Invoke-WebRequest @p; $j = [Text.Encoding]::UTF8.GetString($r.RawContentStream.ToArray()) | ConvertFrom-Json
  if ($j.error) { throw "La base respondio error: $($j.error)" }; @($j.filas) }
$ahora = (Get-Date).ToUniversalTime().AddHours(-3); $mes = $ahora.ToString('yyyy-MM')
$out = [ordered]@{ mes = $mes; actualizado = $ahora.ToString('yyyy-MM-dd HH:mm'); combos = [ordered]@{} }
foreach ($cb in $Combos) {
  $cods = "'$cb','150$cb'"
  $filas = Sql @"
SELECT CAST(v.vendedor AS INTEGER) AS ven,
       SUM(CASE WHEN v.tipo LIKE 'DEV%' THEN -ABS(c.cantidad) ELSE c.cantidad END) AS cant,
       COUNT(DISTINCT CASE WHEN v.tipo='VEN' THEN v.cliente END) AS clientes
FROM venta_combos c JOIN ventas v ON v.id = c.venta_id
WHERE c.combo IN ($cods) AND v.tipo IN ('VEN','DEV-RE','DEV-CA')
  AND substr(COALESCE(NULLIF(v.entrega,''), v.fecha), 1, 7) = '$mes'
GROUP BY 1
"@
  $v = [ordered]@{}; $cl = [ordered]@{}
  foreach ($f in ($filas | Sort-Object { [int]$_.ven })) { if ($null -eq $f.ven) { continue }; $v["$($f.ven)"] = [double]$f.cant; $cl["$($f.ven)"] = [int]$f.clientes }
  # detalle por cliente: [codigo, cantidad neta, ultima fecha, 1 si ya esta facturado, razon social, localidad]
  $det = Sql @"
SELECT CAST(v.vendedor AS INTEGER) AS ven, v.cliente AS cli,
       SUM(CASE WHEN v.tipo LIKE 'DEV%' THEN -ABS(c.cantidad) ELSE c.cantidad END) AS cant,
       MAX(v.fecha) AS fecha, MAX(CASE WHEN NULLIF(v.comprobante,'') IS NOT NULL THEN 1 ELSE 0 END) AS fact,
       MAX(COALESCE(NULLIF(cl.razon_social,''), cl.nombre)) AS rs, MAX(cl.localidad) AS loc
FROM venta_combos c JOIN ventas v ON v.id = c.venta_id LEFT JOIN clientes cl ON cl.codigo = v.cliente
WHERE c.combo IN ($cods) AND v.tipo IN ('VEN','DEV-RE','DEV-CA')
  AND substr(COALESCE(NULLIF(v.entrega,''), v.fecha), 1, 7) = '$mes'
GROUP BY 1, 2
"@
  $dd = [ordered]@{}
  foreach ($f in ($det | Sort-Object { [int]$_.ven }, fecha)) { if ($null -eq $f.ven) { continue }; $k = "$($f.ven)"
    if (-not $dd.Contains($k)) { $dd[$k] = New-Object System.Collections.ArrayList }
    [void]$dd[$k].Add(@("$($f.cli)".Trim(), [double]$f.cant, "$($f.fecha)", [int]$f.fact, "$($f.rs)".Trim(), "$($f.loc)".Trim())) }
  $out.combos[$cb] = [ordered]@{ v = $v; clientes = $cl ; detalle = $dd }
  "Combo $cb en $($mes): $(($v.Values | Measure-Object -Sum).Sum) en $($v.Count) vendedores"
}
# Todos los combos por dia de carga y vendedor (pedido de Bruno, 29/10/2026: indicador "quien se focalizo en combos"
# del Reporte diario): solo pedidos (VEN), por la fecha de carga, la misma del selector Dia del reporte.
# porDia = { 'aaaa-mm-dd': { vendedor: [combos, clientes con combo] } }
$pd = Sql @"
SELECT substr(v.fecha, 1, 10) AS dia, CAST(v.vendedor AS INTEGER) AS ven, SUM(c.cantidad) AS cant, COUNT(DISTINCT v.cliente) AS clientes
FROM venta_combos c JOIN ventas v ON v.id = c.venta_id
WHERE v.tipo = 'VEN' AND substr(v.fecha, 1, 7) = '$mes'
GROUP BY 1, 2
"@
$out.porDia = [ordered]@{}
foreach ($f in ($pd | Sort-Object dia, { [int]$_.ven })) { if ($null -eq $f.ven -or -not $f.dia) { continue }
  if (-not $out.porDia.Contains("$($f.dia)")) { $out.porDia["$($f.dia)"] = [ordered]@{} }
  $out.porDia["$($f.dia)"]["$($f.ven)"] = @([double]$f.cant, [int]$f.clientes) }
"Combos por dia en $($mes): $($out.porDia.Count) dias"
$dir = Join-Path (Resolve-Path $Salida) 'vivo'; if (-not (Test-Path $dir)) { New-Item -ItemType Directory $dir | Out-Null }
[IO.File]::WriteAllText((Join-Path $dir 'combos.json'), ($out | ConvertTo-Json -Depth 6 -Compress), (New-Object Text.UTF8Encoding $false))
