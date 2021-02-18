$packageconfigs = Get-Content $args[0] | 
    Where-Object { $_ -match "Project.+, ""(.+)\\([^\\]+).csproj"", " } | 
    ForEach-Object { "$($matches[1])\packages.config" } 

$packageconfigs = $packageconfigs -split "\r?\n|\r"
$packages = New-Object System.Collections.Generic.List[System.Object]    
foreach ($packageconfig in $packageconfigs)
{
    $file = Get-Content $packageconfig -ErrorAction SilentlyContinue 
    if($?) # If no error occurred while trying to read file
    {
        Write-Host "Reading package $packageconfig."
        foreach ($line in $file)
        {
            $pattern = '.*id="(?<PackageName>[a-zA-z\.]*)".*'
            foreach ($match in [regex]::Matches($line, $pattern))
            {
                #Write-Output $match
                $result = $match[0].Groups['PackageName'].Value
                if ($result.StartsWith('Microsoft') -or ($result.StartsWith('System')))
                {
                    Write-Host "Skipping package $result since it is a Microsoft or System package."
                }
                else 
                {
                    $packages.Add($result)                    
                }
            }    
        }
    }
    else 
    {
        Write-Host "Error opening package $packageconfig. Skipping."
    }
}

$packages = $packages | Sort-Object -Unique

$hashtable = @{}
foreach ($line in $packages)
{
    $lowerline = $line.ToLower()
    $url = "https://api.nuget.org/v3/registration3/$lowerline/index.json"

    $response = Invoke-WebRequest -Uri $url -Method Get -ContentType 'application/json'
    $json = ConvertFrom-Json $response.content

    $latestversion = $json.items[0].count
    $latestversion--

    $licenseurl
    try
    {
        $licenceurl = $json.items[0].items[$latestversion].catalogEntry.licenseUrl
    }
    catch ## We need to go deeper....
    {
        $count = $json.count
        $count--

        $newurl = $json.items[$count].'@id'
        $response = Invoke-WebRequest -Uri $newurl -Method Get -ContentType 'application/json'
        $json = ConvertFrom-Json $response.content

        $count = $json.count
        $count--

        $licenceurl = $json.items[$count].catalogEntry.licenseUrl
    }
    if ([string]::IsNullOrEmpty($licenceurl))
    {
        $hashtable[$line] = "Unknown license"
    }
    $hashtable[$line] = $licenceurl
}

foreach ($h in $hashtable.GetEnumerator()) {
    Write-Host "$($h.Name): $($h.Value)"
}
