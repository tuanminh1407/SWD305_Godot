$files = @(
    "Vi-Hà_Nội-bắc.ogg",
    "Vi-saigon-Sài_Gòn.ogg",
    "Vi-saigon-mẹ.ogg",
    "Vi-hanoi-mẹ.ogg"
)

foreach ($f in $files) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($f)
    $hash = [System.Security.Cryptography.MD5]::Create().ComputeHash($bytes)
    $hashString = [System.BitConverter]::ToString($hash).Replace("-", "").ToLower()
    $h1 = $hashString.Substring(0, 1)
    $h2 = $hashString.Substring(0, 2)
    Write-Host "$f -> https://upload.wikimedia.org/wikipedia/commons/$h1/$h2/$f"
}
