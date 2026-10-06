# Tiny static file server (no Node/Python needed) for opening the simulator over http://localhost:8765/
param([int]$Port = 8765)
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Output "Serving $root on http://localhost:$Port/"
$types = @{ ".html" = "text/html; charset=utf-8"; ".js" = "text/javascript; charset=utf-8"; ".json" = "application/json"; ".css" = "text/css" }
while ($listener.IsListening) {
  $ctx = $listener.GetContext()
  $rel = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath.TrimStart("/"))
  if ($rel -eq "") { $rel = "battle_simulator.html" }
  $path = Join-Path $root $rel
  if ((Test-Path $path -PathType Leaf) -and $path.StartsWith($root)) {
    $bytes = [IO.File]::ReadAllBytes($path)
    $ext = [IO.Path]::GetExtension($path).ToLower()
    $ctx.Response.ContentType = if ($types.ContainsKey($ext)) { $types[$ext] } else { "application/octet-stream" }
    $ctx.Response.ContentLength64 = $bytes.Length
    $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
  } else { $ctx.Response.StatusCode = 404 }
  $ctx.Response.Close()
}
