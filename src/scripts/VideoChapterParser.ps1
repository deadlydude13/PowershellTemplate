<#
.SYNOPSIS
    Parses chapter data from a CSV file and adds it to a video file.

.DESCRIPTION
    Reads chapter data from a csv file and adds it to a video file using FFmpeg.

.PARAMETER ffmpegPath
    	Path to the FFmpeg executable. Used to add chapter information to the video.

.PARAMETER ffprobePath
    Path to the FFprobe executable. Used to retrieve information about the video.

.PARAMETER inputFile
    Path to the video file to which you want to add chapters.

.PARAMETER csvFile
    Path to the CSV file containing the chapter information.

.PARAMETER outputFile
    Path where the video with added chapters should be saved.

.PARAMETER csvDelimiter
    Delimiter used in the CSV file. Defaults to a comma.

.PARAMETER debug
    Boolean indicating whether to output debug information. Defaults to $false.

.EXAMPLE
    .\VideoChapterParser.ps1 -ffmpegPath "C:\ffmpeg\bin\ffmpeg.exe" -ffprobePath "C:\ffmpeg\bin\ffprobe.exe" -inputFile "C:\input_video.mp4" -csvFile "C:\chapters.csv" -outputFile "C:\output_video_with_chapters.mp4" -csvDelimiter "comma" -debug $false
.NOTES
    Author: PowershellMate1000 
    Date:   March 2024
#>
function Test-Executable {
    param(
        [string]$executablePath,
        [string]$executableName,
        [string]$errorMessage
    )
    if (-not (Test-Path -Path $executablePath)) { Write-Error "$errorMessage $executablePath" }
    if ($IsMacOS -and -not (Get-Command $executableName -ErrorAction SilentlyContinue)) {
        Write-Error "$errorMessage $executableName is not installed or not found in the system PATH on macOS."
    }
}
function Read-CSV {
    param(
        [string]$filePath
    )
    Get-Content -Path $filePath | ForEach-Object {
        $values = $_ -split "\t"
        [PSCustomObject]@{
            Time        = $values[0]
            Version     = $values[1]
            Color       = $values[2]
            Description = $values[3]
        }
    }
}
function Convert-TimeToMs {
    param (
        [string]$time
    )
    $parts = $time.Split(':')
    if ($parts.Length -ne 4) {
        Write-Error "Time string format is incorrect. Expected format is HH:MM:SS:FF."
        return
    }
    $totalMilliseconds = (
        [TimeSpan]::FromHours([int]$parts[0]) +
        [TimeSpan]::FromMinutes([int]$parts[1]) +
        [TimeSpan]::FromSeconds([int]$parts[2]) +
        [TimeSpan]::FromMilliseconds([int]$parts[3])
    ).TotalMilliseconds
    # you can use the other time formats as well if you want
    return $totalMilliseconds
}
function Initialize-FFmpegTools {
    param(
        [string]$ffmpegPath,
        [string]$ffprobePath
    )
    function Show-Help {
        Write-Host "Usage: script.ps1 -inputFile <path> -csvFile <path> [-csvDelimiter <delimiter>] -outputFile <path> [-debug] [-help]"
        exit
    }

    function Invoke-FileProcessing {
        param (
            [string]$inputFile,
            [string]$csvFile,
            [string]$outputFile,
            [string]$csvDelimiter,
            [bool]$debug
        )

        if (-not $inputFile -or -not $csvFile) {
            Write-Error "Missing required arguments."
            Show-Help
        }
    
        $delimiter = switch -Regex ($csvDelimiter) {
            "comma" { ","; break }
            "semi|semicolon" { ";"; break }
            "colon" { ":"; break }
            "pipe" { "|"; break }
            "slash" { "/"; break }
            "hash|pound" { "#"; break }
            "tab" { "`t"; break }
            default { "`t" }
        }
        # would also work with a hasthable like
        # $delimiterMap = @{"comma"=","; "semi"=";"; "semicolon"=";"; "colon"=":"; "pipe"="|"; "slash"="/"; "hash"="#"; "pound"="#"; "tab"="`t"}
        # $delimiter = $delimiterMap[$csvDelimiter]
        # if (-not $delimiter) {
        #    $delimiter = "`t"
        #}

        $tempChapterFile = [System.IO.Path]::GetTempFileName()
        if ($debug) { Write-Host "DEBUG - Temp file:`n$tempChapterFile`n" }

        try {
            $chapters = Import-Csv -Path $csvFile -Header 'TimeCode', 'Track', 'Color', 'Title' -Delimiter $delimiter
            $chaptersContent = Generate-ChapterContent -chapters $chapters -inputFile $inputFile
            Set-Content -Path $tempChapterFile -Value $chaptersContent -Encoding UTF8
            & $global:ffmpegPath -i $inputFile -i $tempChapterFile -map_metadata 1 -codec copy $outputFile -y
        }
        finally {
            Remove-Item $tempChapterFile -ErrorAction SilentlyContinue
        }

    }
    Test-Executable -executablePath $ffmpegPath -executableName "ffmpeg" -errorMessage "ffmpeg not found at path:"
    Test-Executable -executablePath $ffprobePath -executableName "ffprobe" -errorMessage "ffprobe not found at path:"
    if (-not $IsWindows) {
        Write-Error "Unsupported OS. Supported: Windows, macOS."
    }
}
function Main {
    param(
        [string]$ffmpegPath,
        [string]$ffprobePath,
        [string]$inputFile,
        [string]$csvFile,
        [string]$outputFile,
        [string]$csvDelimiter,
        [bool]$debug
    )

    Initialize-FFmpegTools -ffmpegPath $ffmpegPath -ffprobePath $ffprobePath

    if ($Help -or $args -contains '-h' -or $args -contains '-help') {
        Show-Help
    }
    Invoke-FileProcessing -inputFile $inputFile -csvFile $csvFile -outputFile $outputFile -csvDelimiter $csvDelimiter -debug $debug
    $csvObjects = Read-CSV -filePath $CsvFilePath
    $csvObjects | Format-Table
}
# Script Execution
Main
-ffmpegPath $ffmpegPath
-ffprobePath $ffprobePath
-inputFile $inputFile
-csvFile $csvFile
-outputFile $outputFile
-csvDelimiter $csvDelimiter
-debug $debug
