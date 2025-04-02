# Main function to get folder structure in a readable format
function Get-FolderStructure {
    param (
        [string]$Path = '.', # Default is the current directory
        [int]$Depth = 100    # Maximum recursion depth
    )

    # Nested function for recursive tree building
    function Build-Tree {
        param (
            [System.IO.DirectoryInfo]$Directory,
            [int]$CurrentDepth,
            [string]$Indent = '',
            [array]$IgnoredPatterns
        )

        if ($CurrentDepth -gt $Depth) {
            return ''
        }

        # Initialize the output string
        $output = ''

        # Process files first
        $files = @($Directory.GetFiles() | Where-Object { -not (Should-Ignore -Item $_ -IgnoredPatterns $IgnoredPatterns) })
        foreach ($file in $files) {
            $output += "$Indent|-- $($file.Name)`n"
        }

        # Process subfolders
        $subDirs = @($Directory.GetDirectories() | Where-Object { -not (Should-Ignore -Item $_ -IgnoredPatterns $IgnoredPatterns) })
        for ($i = 0; $i -lt $subDirs.Count; $i++) {
            $subDir = $subDirs[$i]
            $isLast = ($i -eq $subDirs.Count - 1)

            # Add folder name with appropriate indentation
            if ($isLast) {
                $output += "$Indent\-- $($subDir.Name)/`n"
                $newIndent = "$Indent    "
            } else {
                $output += "$Indent|-- $($subDir.Name)/`n"
                $newIndent = "$Indent|   "
            }

            # Recursively process the subfolder
            $output += Build-Tree -Directory $subDir -CurrentDepth ($CurrentDepth + 1) -Indent $newIndent -IgnoredPatterns $IgnoredPatterns
        }

        return $output
    }

    # Get the root folder
    $rootDir = Get-Item -Path $Path

    # Get the list of ignored patterns once
    $ignoredPatterns = GetIgnorePatterns -Directory $rootDir

    # Start building the tree
    $structure = "$($rootDir.FullName)`n" + (Build-Tree -Directory $rootDir -CurrentDepth 1 -IgnoredPatterns $ignoredPatterns)
    return $structure
}

# Function to define ignore patterns explicitly
function GetIgnorePatterns {
    param (
        [System.IO.DirectoryInfo]$Directory
    )

    $patterns = @()

    # Folders to ignore
    $patterns += '^\.git$'       # .git folder
    $patterns += '^node_modules$' # node_modules folder
    $patterns += '^coverage$'     # coverage folder
    $patterns += '^build$'        # build folder
    $patterns += '^\..*\.pnp$'    # .pnp folder

    # Files to ignore
    $patterns += '.*\.pnp\.js$'                     # Files ending with .pnp.js
    $patterns += '.*\.DS_Store$'                    # Files ending with .DS_Store
    $patterns += '.*\.env\.local$'                  # Files ending with .env.local
    $patterns += '.*\.env\.development\.local$'     # Files ending with .env.development.local
    $patterns += '.*\.env\.test\.local$'            # Files ending with .env.test.local
    $patterns += '.*\.env\.production\.local$'      # Files ending with .env.production.local

    Write-Host "Final ignored patterns: $($patterns -join ', ')"
    return $patterns
}

# Function to check if a file or folder should be ignored
function Should-Ignore {
    param (
        [System.IO.FileSystemInfo]$Item,
        [array]$IgnoredPatterns
    )

    foreach ($pattern in $IgnoredPatterns) {
        if ($Item.Name -match $pattern) {
            return $true
        }
    }

    return $false
}

# Automatically determine the folder from which the script was run
$folderPath = Get-Location | Select-Object -ExpandProperty Path

# Get folder structure
try {
    $folderStructure = Get-FolderStructure -Path $folderPath

    # Save result to structure.txt in the same folder
    $outputFilePath = Join-Path -Path $folderPath -ChildPath 'structure.txt'
    $folderStructure | Out-File -FilePath $outputFilePath -Encoding UTF8

    Write-Host "Folder structure saved to: $outputFilePath"
} catch {
    Write-Host "Error: $_"
}