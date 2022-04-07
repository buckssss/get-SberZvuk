param(
    [string[]] $Links, 
    [String] $Token,
    [String] $Login,
    [String] $Password
)

if (!(Test-Path $env:USERPROFILE\.SberZvukDL\config.json)) {
    'FIRST START CONFIG'
    $newconf = @{}
    do {
        $email = read-host 'Введите логин для SberZvuk (email)'
        $password = read-host 'Введите пароль для SberZvuk'
        if ($email -match '\w+[@]\w+\.\w+' -and $Password -ne '') {
            $newconf.email = $email
            $newconf.password = $Password
            $credask = $true
        }
        else {$credask = $false}
    }
    while ($credask -eq $false)
    $newconf.token = Read-Host 'Если логинитесь с помощью соцсетей, введите токен, если нет, просто нажмите Enter'
    do {
        $formatask = Read-Host 'аудио формат 3 - FLAC, 2 - mp3 320, 1 - mp3 128 (только цифру 1, 2 или 3)'
        if ($formatask -eq 3 -or $formatask -eq 2 -or $formatask -eq 1) {
            $newconf.format = $formatask
            $notNumber = $false
        }
        else {$notNumber = $true}
    }
    while ($notNumber -eq $true)
    $asklyrics = read-host 'тексты песен? 1 - да, 2 - нет (по умолчанию нет)'
    if ($asklyrics -eq 1) {$newconf.lyrics = $true}
    else {$newconf.lyrics = $false}
    $askOutpath = read-host 'Папка для сохранения музыки (по умолчанию c:\Music)'
    if ($askOutpath -match '^\w\:\\\w+') {$newconf.outpath = $askOutpath}
    else {$newconf.outpath = 'c:\Music\'}
    $newconf.maxCover = "500x500"
    $formatFallback = Read-Host 'если нет нужного качества, скачивать качество ниже? 1 - да, 2 - нет (по умолчанию да)'
    if ($formatFallback -eq 2) {$newconf.formatFallback = $false}
    else {$newconf.formatFallback = $true}
    if (!(Test-Path $env:USERPROFILE\.SberZvukDL)) {
    'creating ' + $env:USERPROFILE + '\.SberZvukDL'
    New-Item -ItemType Directory $env:USERPROFILE\.SberZvukDL -ErrorAction SilentlyContinue}
    $newconf|ConvertTo-Json > $env:USERPROFILE\.SberZvukDL\config.json
    "`n" + 'config saved to ' + $env:USERPROFILE + '\.SberZvukDL\config.json' + "`n"
}
#$conf = gc .\config.json|ConvertFrom-Json
$conf = gc $env:USERPROFILE\.SberZvukDL\config.json|ConvertFrom-Json
$loginBody = @{}

if ($Token) {'Using Token to log in'}
elseif ($Login -and $Password) {
    $loginBody.email = $Login
    $loginBody.password = $Password
}
Else {
    if ($conf.token -ne '') {
        $token = $conf.token
        'Using Token to log in'
    }
    elseif ($conf.email -ne '' -and $conf.password -ne '') {
        $loginBody.email = $conf.email
        $loginBody.password = $conf.password
    }
    elseif (!($token) -and $conf.token -eq '' -and ($conf.email -eq '' -or $conf.password -eq '')) {
        $loginBody.email = read-host 'Insert login (email)'
        $loginBody.password = read-host 'Insert password'
    }
}

if (!($token)) {
    try {
        $token = (Invoke-RestMethod -Method Post -ContentType 'application/x-www-form-urlencoded' -Uri 'https://sber-zvuk.com/api/tiny/login/email' -Body $loginBody).result.token
    }
    catch {
        $_.Exception
        if ($_.Exception -match '\(403\)\sForbidden') {
            write-host 'Dont forget to put CORRECT login and password to config.json' -foreground RED
            break
        }
    }
    #$token = $login.result.token
    #$token
}

#$login
'got token: ' + $token
$header = @{'x-auth-token' = $token}
$prof = Invoke-RestMethod -uri 'https://sber-zvuk.com/api/v2/tiny/profile' -Headers $header
$prof.result.subscription
$outPath = $conf.outPath
if ($outpath -notmatch '\\$') {$outpath = $outpath + '\'}
if (!(Test-Path $env:USERPROFILE\.SberZvukDL\TagLibSharp.dll)) {
    'downloading TagLibSharp'
    Invoke-WebRequest -Uri 'https://globalcdn.nuget.org/packages/taglibsharp.2.2.0.nupkg' -OutFile $env:temp\TaglibSharp.zip
    Expand-Archive $env:temp\TaglibSharp.zip -DestinationPath $env:temp\TaglibSharp\ -ErrorAction SilentlyContinue
    copy-item $env:temp\TaglibSharp\lib\net45\TagLibSharp.dll $env:USERPROFILE\.SberZvukDL\
}
$TagLib = Get-ChildItem $env:USERPROFILE\.SberZvukDL\TagLibSharp.dll
'loading TagLibSharp lib'
[Reflection.Assembly]::LoadFrom(($TagLib.FullName))|out-null

if ($conf.format -eq '3') {$format = 'flac'}
elseif ($conf.format -eq '2') {$format = 'high'}
elseif ($conf.format -eq '1') {$format = 'mid'}

$streamURI = 'https://sber-zvuk.com/api/tiny/track/stream'
$lyrURI = 'https://sber-zvuk.com/api/tiny/musixmatch/lyrics'
#$albumURI = 'https://sber-zvuk.com/api/tiny/releases'
#$plistURI = 'https://sber-zvuk.com/api/tiny/playlists'
#$trackURI = 'https://sber-zvuk.com/api/tiny/tracks'


$links = $links -split ','|foreach {$_ -replace '\s'}
foreach ($link in $links) {
    if (!($link)) {
        $link = read-host 'insert SberZvuk link'
    }

    $reqID = $link -split '/'|select -Last 1

    if ($link -match '\/release\/') {
        'getting info about album'
        #$albumLink = read-host 'insert album link'
        $reqBody = @{'ids' = $reqID;'include' = 'track,'}
        $reqURL = 'https://sber-zvuk.com/api/tiny/releases'
        $downType = 'releases'
    }
    elseif ($link -match '\/playlist\/') {
        'getting info about playlist'
        #$albumLink = read-host 'insert album link'
        $reqBody = @{'ids' = $reqID;'include' = 'track,release,'}
        $reqURL = 'https://sber-zvuk.com/api/tiny/playlists'
        $downType = 'playlists'
    }
    elseif ($link -match '\/track\/') {
        'getting info about track'
        #$albumLink = read-host 'insert album link'
        $reqBody = @{'ids' = $reqID;'include' = 'track,release,'}
        $reqURL = 'https://sber-zvuk.com/api/tiny/tracks'
        $downType = 'tracks'
    }

    try {
        $downList = Invoke-RestMethod -uri $reqURL -Headers $header -Body $reqBody
    }
    catch {
        if ($_.Exception -match 'Unauthorized') {
            write-host 'Wrong creds or token' -foregroundcolor RED
            break
        }
    }
    if ($downType -eq 'playlists' -or $downType -eq 'releases') {$trackIDs = $downList.result.$downType.$reqID.track_ids}
    else {$trackIDs = $downList.result.$downType.$reqID.id}

    $i = 1
    foreach ($trackID in $trackIDs) {
        $track = $downList.result.tracks.psobject.Properties|?{$_.value.id -eq $trackID }
        $err = ''
        $body = @{}
        $id = $trackID
        $albumID = $track.value.release_id
        $albumArtist = $downList.result.releases.$albumID.artist_names|select -first 1
        $year = $downList.result.releases.$albumID.date -replace '(^\d{4}).+','$1'
        $trackTitle = $track.value.title
        $artists = $track.value.artist_names
        $albumName = $track.value.release_title
        $genres = $track.value.genres
        $trackNumber = $track.value.position.toString("00")
        if ($downType -eq 'releases') {
            $baseFilename = $trackNumber + ' - ' + $trackTitle
            $downPath = $outPath + $albumArtist + '\' + $year + ' - ' + $albumName
        }
        elseif ($downType -eq 'playlists') {
            $position = $i.toString("000")
            $baseFilename = $position + ' - ' + $artists[0] + ' - ' + $trackTitle  + ' - ' + $albumName
            $plistName = $downList.result.playlists.$plistID.title
            $downPath = $outPath + '_plists\' + $plistName
            $i ++
        }
        elseif ($downType -eq 'tracks') {
            $baseFilename = $artists[0] + ' - ' + $trackTitle  + ' - ' + $albumName
            $downPath = $outPath + '_tracks\'
        }
        $hasFLAC = $track.value.has_flac
        if ($format -eq 'flac' -and $hasFLAC -eq $true) {
            $body = @{'id' = $id;'quality' = 'flac'}
            $getFormat = 'FLAC'
            $filename = $baseFilename + '.flac'
        }
        elseif (($format -eq 'flac' -and $conf.formatFallback -eq $true) -or $format -eq 'high') {
                $body = @{'id' = $id;'quality' = 'high'}
                $getFormat = 'MP3'
                $filename = $baseFilename + '.mp3'
        }
        elseif (($format -eq 'high' -and $conf.formatFallback -eq $true) -or $format -eq 'mid') {
                $body = @{'id' = $id;'quality' = 'mid'}
                $getFormat = 'MP3'
                $filename = $baseFilename + '.mp3'
        }
        $filename = $filename  -replace '[\,\/\\\[\]\:\;\?\!\"]','_'
        if (!(Test-Path $downPath)) {
            "`ncreating dir..."
            (New-Item -ItemType Directory $downPath).Fullname
            ''
        }
        if ($body.id) {
            "`ngetting file info " + $baseFilename + ' (' + $getFormat + ')'
            $ii = 0
            do {
                try {
                    $url = (Invoke-RestMethod -uri $streamURI -Headers $header -Body $body).result.stream
                }
                catch {
                    if ($_.Exception -match '\(418\)') {
                        $err = $_.Exception
                        $url = ''
                        Write-Host 'Error 418. Retrying...' -ForegroundColor RED
                    }
                    sleep 3
                }
                $ii ++
            } while ($err -ne '' -and $ii -lt 5)
            $lyrBody = @{'track_id' = $id}
            if ($conf.lyrics -eq $true) {
                $lyrReq = $null
                'getting lyrics...'
                $ii = 0
                do {
                    try {
                        $lyrReq = Invoke-RestMethod -uri $lyrURI -Headers $header -Body $lyrBody
                    }
                    catch {
                        if ($_.Exception -match '\(418\)') {
                            $err = $_.Exception
                            $lyrReq = $null
                            Write-Host 'Error 418. Retrying...' -ForegroundColor RED
                        }
                        sleep 3
                    }
                    $ii ++
                } while ($err -ne '' -and $ii -lt 5)
            }
            $fullName = $downPath + '\' + $filename
            'Downloading file...'
            Start-BitsTransfer -Source $url -Destination $fullName
            'saved file ' + $fullName
            'writing metadata...'
            $file = gci $fullName
            try {
                $afile = [TagLib.File]::Create(($file.FullName))
            }
            catch {
                if ($_.Exception -match 'MPEG') {
                        $newFullname = (join-path $file.Directory.FullName -ChildPath $file.BaseName) + '.flac'
                        Rename-Item $file.FullName -NewName $newFullname
                }
                elseif ($_.Exception -match 'FLAC') {
                    $newFullname = (join-path $file.Directory.FullName -ChildPath $file.BaseName) + '.mp3'
                    Rename-Item $file.FullName -NewName $newFullname
                }
                $afile = [TagLib.File]::Create(($newFullname))
            }
            $afile.tag.year = $year
            if ($afile.MimeType -match 'flac') {
                $afile.tag.Artists = $artists
                $afile.tag.Genres = $genres
            }
            elseif ($afile.MimeType -match 'mp3') {
                $afile.tag.Artists = ($artists -join ' ; ') -split ';'
                $afile.tag.Genres = ($genres -join ' ; ')
            }
            $afile.tag.Album = $albumName
            $afile.tag.AlbumArtists = $albumartist
            $afile.tag.Title = $trackTitle
            $afile.tag.Track = $trackNumber
            if ($conf.lyrics -eq $true -and $lyrReq.result.lyrics -ne '') {$afile.Tag.Lyrics = $lyrReq.result.lyrics}
            $coverLink = 'https://cdn41.zvuk.com/pic?type=release&id=' + $albumID + '&size=' + $conf.maxcover + '&ext=jpg'
            try {
                Invoke-WebRequest $coverLink -OutFile $env:TEMP\cover.jpg
            }
            catch {if ($_.Exception) {rm $env:TEMP\cover.jpg}}
            $afile.Tag.Pictures = [taglib.picture]::createfrompath("$env:TEMP\cover.jpg")
            $afile.save()
        }
        sleep 1
    }
    if ($links.count -gt 1) {
        'wait 5 secs till go to next link...'
        sleep 5
    }
}