# Purpose: Requires PSDLE file with Platform, Name, Size (NOT prettySize) Store (url)
# Usage: .\parse.ps1 -file .\psdle_ps4.csv


## PRODUCTID also works instead of Store
param(
    [Parameter(Position=0,Mandatory=1)] [string]$psdleJsonFile,
    [Parameter(Position=1,Mandatory=0)] [string]$jsonFile
)

function Parse-PsdleJson($file)
{
    if (-Not($file))
    {
        throw "psdle json file required"
    }

    $allGames = ((Get-Content $file -Encoding UTF8) | ConvertFrom-Json).items | Sort-Object -Property "platform", "name"
    $allGames = $allGames | Select-Object -Property platform, name, @{ label="Id"; expression={(($_.id -split "/")[-1] -split "-")[1]} }
 
    $i = 1;
    $games = @()
    foreach($game in $allGames)
    {
        $games += [PSCustomObject]@{
            Index = $i++
            Platform = $game.Platform
            Name = $game.Name
            IsBase = $false
            Id = $game.Id
        }
    }
    
    return $games
}

function Parse-CurrentJson($file)
{
    if (-Not($file))
    {
        return @();
    }
    $games = (Get-Content $file -Encoding UTF8) | ConvertFrom-Json | Sort-Object -Property "Name", "Store", "Size"
    return $games;
}


function Sync
$sourceGames = Parse-PsdleJson($psdleJsonFile);
$existingGames = Parse-Json($jsonFile);

foreach($sourceGame in $sourceGames)
{
    $baseGame = $existingGames | Where-Object { $_.Id -eq $sourceGame.Id -and $_.IsBase -eq $true }
    $baseGameExists = (-not(-not($baseGame))
    
    
}

if ($jsonFile)
{
    $games = (Get-Content $jsonFile -Encoding UTF8) | ConvertFrom-Json | Sort-Object -Property "Name", "Store", "Size"
}

$grouped = $games | Group-Object "Id" -AsHashTable -AsString

$allGames = @()
foreach ($key in $grouped.Keys) {
    $gameGroup = $grouped.Item($key)

    $gameItems = @();
    
    $i = 1
    foreach($gameItem in $gameGroup | Sort-Object -Property Name)
    {
        $isBase = $gameItem.IsBase
        if (-Not($isBase))
        {
            $isBase = $false
        }
        
        if ($gameGroup.Count -eq 1)
        {
            #If a single item found, then assume it is the base game.
            $isBase = $true
        }

        $gameItems += [PSCustomObject]@{
            Index = $i++
            Name = $gameItem.Name
            Size = $gameItem.Size
            IsBase = $isBase
            Id = $gameItem.Id
        }
    }
    
    $gameItems = $gameItems | Sort-Object -Property Name
    
    if ($gameItems.Count -gt 1)
    {
        Write-Host "----------------------------------------------"
        $hasBaseGameDefined = $false;
        foreach($gameItem in $gameItems)
        {
            Write-Host "$($gameItem.Index) $($gameItem.Name)"
            if ($gameItem.IsBase)
            {
                $hasBaseGameDefined = $true;
            }
        }
        
        if ($hasBaseGameDefined)
        {
            $allGames += $gameItems
            continue;
        }

        $sortedBySize = $gameItems | Sort-Object  -Property Size -Descending
        if ($sortedBySize.Length -eq 0)
        {
            throw "not implemented"
            Write-Host "Can't determine base game. Enter game name:"
            $gameName = Read-Host
        }
        else
        {
            $likelyGame = $sortedBySize[0]
            
            Write-Host " "
            "'$($likelyGame.Name)' was determined to be the most likely base game item."
            $choice = Read-Host -Prompt "Correct game number [Default $($likelyGame.Index)]"
            if (-Not($choice))
            {
                $choice = $likelyGame.Index
            }
            
            $foundGame = $gameItems | Where-Object { $_.Index -eq $choice }
            
            if ($foundGame)
            {
                $foundGame.IsBase = $true
            }
            else 
            {
                $gameName = Read-Host -Prompt "Can't determine base game. Enter game name"
                
                $gameItems += [PSCustomObject]@{
                    Name = $gameName
                    Size = 0
                    IsBase = $true
                    Id = $likelyGame.Id
                }
            }
        }
       
    }
    
    $allGames += $gameItems
}

#$allGames | Where-Object { $_.IsBase } | % { $_ | Add-Member -NotePropertyName AddOns -NotePropertyValue @()}
$baseGames = $allGames | Where-Object { $_.IsBase }

foreach($baseGame in $baseGames)
{
    $addOns = ($allGames | Where-Object { $_.Id -eq $baseGame.Id } | Where-Object { -Not($_.IsBase) } | Select -Property Name).Name;
    if ($addOns -ne $null)
    {
        $baseGame | Add-Member -NotePropertyName AddOns -NotePropertyValue @()
        $baseGame.AddOns = @($addOns )
    }
    
}

$baseGames | Select -Property Name, AddOns | Sort-Object -Property Name | ConvertTo-Json -Depth 100 | Out-File .\organzied.json
$allGames | Select -Property Name, Size, IsBase, Id | Sort-Object -Property Id, @{Expression = "IsBase"; Descending=$true}, Name | ConvertTo-Json | Out-File .\allGames.json

$baseGames | Sort-Object -Property Name | Select -Property Name  |ConvertTo-Csv | Out-File organzied.csv