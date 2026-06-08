param (
    [string]
    $Path
)

# Script Settings

$BuildDir = ".build"
$OutDir = "www"
$TimeZone = "JST"
$DateTimeFormat = "MMM d, yyyy hh:mm tt"
$S3Endpoint = $(op read op://Private/blog.iwate.me/endpoint)
$S3BucketName = $(op read op://Private/blog.iwate.me/bucket)
$env:AWS_ACCESS_KEY_ID=$(op read op://Private/blog.iwate.me/username)
$env:AWS_SECRET_ACCESS_KEY=$(op read op://Private/blog.iwate.me/password)
$env:AWS_DEFAULT_REGION=$(op read op://Private/blog.iwate.me/region)


$FooterHtml = @"
<footer>
    <h1>blog.iwate.me</h1>
    <a class="button" href="https://blog.iwate.me">Read other posts</a>
    <p>
        🗻 Bits, Bytes, and Tokyo Nights 🗼
        <a href="https://github.com/iwate">GitHub</a> / <a href="https://bsky.app/profile/iwate.me">SNS</a> / <a href="https://b.iwate.me/">Bookmarks</a>
    </p>
</footer>
<script async="" src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-8979717305625609" crossorigin="anonymous"></script>
<script>
    (adsbygoogle = window.adsbygoogle || []).push({});
</script>
"@

# PowerShell Settings

$ErrorActionPreference = "Stop";

# Install Dependencies

if (-not (Get-Module -ErrorAction Ignore -ListAvailable PSParseHTML)) {
  Write-Verbose "Installing PSParseHTML module for the current user..."
  Install-Module -Scope CurrentUser PSParseHTML -ErrorAction Stop
}

if (-not (Get-Module -Name PSParseHTML)) {
    Import-Module PSParseHTML -ErrorAction Stop
}

# Helpers

function Normalize-UrlString ([string]$Text) {
    $Text = $Text -replace "[<>\[\]{}()/|\\=~*+^``'`"$%&#!?,.;:\p{Cs}]", " "
    $Text = $Text.Trim() 
    $Text = $Text -replace "\s+", "-"
    return $Text.ToLower()
}

function Parse-Utc([string]$Text) {
    return [DateTimeOffset]::ParseExact($Text, "dd-MM-yyyy hh:mm tt", [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal)
}

function Transform([string]$Html) {
    $DOM = $Html | ConvertFrom-Html

    $Title = $DOM.SelectSingleNode("/html/head/title")
    $TitleText = $Title.InnerText -replace ' - Notesnook', ''
    $Title.InnerHtml = "$TitleText"

    $UrlName = Normalize-UrlString -Text $TitleText

    $Description = $DOM.SelectSingleNode("/html/head/meta[@name='description']")?.Attributes["content"].Value
    $CreatedAtUtc = Parse-Utc -Text $DOM.SelectSingleNode("/html/head/meta[@name='created-at']")?.Attributes["content"].Value
    $UpdatedAtUtc = Parse-Utc -Text $DOM.SelectSingleNode("/html/head/meta[@name='updated-at']")?.Attributes["content"].Value
    $Now = [DateTimeOffset]::UtcNow

    # Remove Styles
    # $DOM.SelectNodes("/html/head/style") | ?{ $_ -ne $null} | %{ $_.Remove() }

    # Append Css
    $DOM.SelectSingleNode("/html/head").AppendChild(('<link rel="stylesheet" href="https://cdn.simplecss.org/simple.css">' | ConvertFrom-Html))
    $DOM.SelectSingleNode("/html/head").AppendChild(('<style>iframe[src^="https://www.youtube.com/embed/"] { aspect-ratio: 16/9; width: 100%; }</style>' | ConvertFrom-Html))

    # Append Meta
    $DOM.SelectSingleNode("/html/head").AppendChild(('<meta name="viewport" content="width=device-width, initial-scale=1.0">' | ConvertFrom-Html))
    $DOM.SelectSingleNode("/html/head").AppendChild(("<link rel=""canonical"" href=""https://blog.iwate.me/$UrlName/"" />" | ConvertFrom-Html))

    # Transform
    $DOM.SelectNodes("//*[@class='callout']") ?? @() | %{
        $_.SetAttributeValue("class", "notice")
    }

    $DOM.SelectNodes("//*[starts-with(@src, './attachments/')]") ?? @() | %{
        $_.SetAttributeValue("src", $_.Attributes["src"].Value.Substring(1))
    }

    $Body = $DOM.SelectSingleNode("/html/body")
    $H1 = $DOM.SelectSingleNode("/html/body/h1")

    $Header = @"
    <header>
        <h1>$($H1.InnerText ?? $TitleText)</h1>
        <time datetime="$($Now.ToString("o"))">$($Now.ToLocalTime().ToString($DateTimeFormat, [System.Globalization.CultureInfo]::InvariantCulture)) $TimeZone</time>
    </header>
"@ | ConvertFrom-Html

    if ($H1 -ne $null) {
        $H1.Remove()
    }

    $Footer = $FooterHtml| ConvertFrom-Html

    $Main = ("<main></main>" | ConvertFrom-HTML).ChildNodes | select -First 1
    $Main.MoveChildren($Body.ChildNodes)

    $Body.AppendChild($Header)
    $Body.AppendChild($Main)
    $Body.AppendChild($Footer)

    $Content = $DOM.OuterHtml

    $Summary = @"
    <div class="blog-item">
        <a class="post-link" href="/$UrlName/">$TitleText</a>
        <p class="meta">$Description</p>
        <p class="meta"><time datetime="$($Now.ToString("o"))">$($Now.ToLocalTime().ToString($DateTimeFormat, [System.Globalization.CultureInfo]::InvariantCulture)) $TimeZone</time></p>
    </div>
"@
    return @{
        UrlName = $UrlName;
        Title = $TitleText;
        Content = $Content;
        Summary = $Summary;
    }
}

function Append-Summary([string]$Path, [string]$Summary) {
    $DOM = Get-Content $Path -Encoding UTF8 -Raw | ConvertFrom-HTML
    $node = $Summary | ConvertFrom-HTML
    $href = $node.SelectSingleNode('/div/a').Attributes['href'].Value

    $item = $DOM.SelectSingleNode("//a[@href=""$href""]")
    if ($item -ne $null) {
        return $false
    }

    $DOM.SelectSingleNode("/html/body/main").PrependChild($node)
    Format-HTML -Content $DOM.OuterHtml | Out-File $Path -Encoding UTF8
    Write-Host "Append summary"
    return $true
}

function Append-Sitemap([string]$Path, [string]$Url) {
    $list = Get-Content $Path -Encoding UTF8
    $item = $list | ?{ $_ -eq $Url}
    if ($item -ne $null) {
        return $false
    }

    $Url | Out-File $Path -Append
    Write-Host "Append sitemap"
    return $true
}

function Generate-RSS([string]$SrcPath, [string]$OutPath, [int]$Max = 5) {
    $DOM = Get-Content $SrcPath -Encoding UTF8 -Raw | ConvertFrom-HTML
    $nodes = $DOM.SelectNodes("//*[@class='blog-item']") | Select -First $Max
    $items = @()
    foreach ($node in $nodes) {
        $link = $node.SelectSingleNode('a')
        $desc = $node.SelectSingleNode('p')
        $time = $node.SelectSingleNode('p/time')
        $url = "https://blog.iwate.me$($link.Attributes['href'].Value)"
        $datetime = [DateTimeOffset]::Parse($time.Attributes['datetime'].Value)
        $items += @"
    <item>
      <title>$($link.InnerHtml)</title>
      <link>$([System.Uri]::EscapeUriString($url))</link>
      <description>$($desc.InnerHtml)</description>
      <pubDate>$($datetime.ToString("r"))</pubDate>
      <guid>$([System.Uri]::EscapeUriString($url))</guid>
    </item>
"@
    }

@"
<?xml version="1.0" encoding="UTF-8" ?>
<rss version="2.0">
  <channel>
    <title>blog.iwate.me</title>
    <link>https://blog.iwate.me</link>
    <description>🗻 Bits, Bytes, and Tokyo Nights 🗼</description>
    <language>ja</language>
    <pubDate>Tue, 06 Aug 2024 00:00:00 +0000</pubDate>
    <lastBuildDate>$(Get-Date -Format "r")</lastBuildDate>

$([string]::Join("`n", $items))

  </channel>
</rss>
"@ | Out-File $OutPath
    Write-Host "Generate RSS"
}

function Download-Object([string]$Key) {
    aws s3api get-object --endpoint-url "$S3Endpoint" --bucket "$S3BucketName" --key "$Key" "$OutDir/$Key" > $null
}

function Upload-OutDir() {
    Get-ChildItem -Path $OutDir -Recurse -File | ForEach-Object { $_.FullName } | Sort-Object @{Expression={$_.Length};Descending=$true}| %{
        $Key = $_.Replace("$PWD/$OutDir/", "").Replace("\", "/")
        Write-Host "-> $Key"
        aws s3api put-object --endpoint-url "$S3Endpoint" --bucket "$S3BucketName" --key "$Key" --body "$_" > $null
    }
}

# Script Process

## Pre
$IsZip = $Path -like "*.zip"
$IsHtml = $Path -like "*.html"
if ((-not $IsZip) -and (-not $IsHtml)) {
    Write-Host $Path
    Write-Error "Failed: The file must be zip or html."
    Read-Host
    exit 1
}

if (Test-Path $BuildDir) {
    Remove-Item -Recurse -Force $BuildDir
}

New-Item $BuildDir -ItemType Directory > $null

if (Test-Path $OutDir) {
    Remove-Item -Recurse -Force $OutDir
}

New-Item $OutDir -ItemType Directory > $null

Download-Object -Key "index.html"
Download-Object -Key "sitemap.txt"

## Do

if ($IsZip) {
    Expand-Archive -Path $Path -DestinationPath $BuildDir
}
else {
    Copy-Item -Path $Path -Destination $BuildDir
}

$HtmlFile = Get-Item "$BuildDir/*" -Filter "*.html"
$Html = Get-Content $HtmlFile.FullName -Encoding UTF8 -Raw

$Item = Transform -Html $Html

if (Test-Path "$BuildDir/attachments") {
    Move-Item "$BuildDir/attachments" -Destination "$OutDir/attachments"
}

if (-not (Test-Path "$OutDir/$($Item.UrlName)")) {
    New-Item "$OutDir/$($Item.UrlName)" -ItemType Directory > $null
}

$Item.Content | Out-File "$OutDir/$($Item.UrlName)/index.html" -Encoding UTF8

if (-not(Append-Summary -Path "$OutDir/index.html" -Summary $Item.Summary)) {
    Remove-Item -Path "$OutDir/index.html"
}

if (-not (Append-Sitemap -Path "$OutDir/sitemap.txt" -Url "https://blog.iwate.me/$($Item.UrlName)/")) {
    Remove-Item -Path "$OutDir/sitemap.txt"
} 
else {
    Generate-RSS -SrcPath "$OutDir/index.html" -OutPath "$OutDir/rss.xml"
}

## Post

Upload-OutDir
Remove-Item -Recurse -Force $BuildDir
Remove-Item -Recurse -Force $OutDir
Remove-Item $Path
