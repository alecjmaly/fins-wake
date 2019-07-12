

###### STEP 1: DEFINE VARIABLES #####

# import dictionary of words (sorted)
[Array]$dictionary = Get-Content C:\Users\u28194\Desktop\words.txt | sort
# import finnegans wake
$wake = Get-Content C:\Users\u28194\Desktop\wake.txt

# get all words in Finnigans Wake
[System.Collections.ArrayList] $wake_words = $wake -split " "


$script = {
    Param( [int]$i, $arr, $min, $max, $dictionary )

    # array to collect valid words
    $word_arr = [System.Collections.ArrayList] @()

    foreach ($word in $arr.value[$min..$max]) {
        # collect if word is found in dictionary 
        If([System.Array]::BinarySearch($dictionary.value, $word.ToLower()) -ge 0) {
            $word_arr.add($word) | Out-Null
        }
    }

    # output to file
    ($word_arr -join ' ') | Set-Content -PassThru C:\Users\u28194\Desktop\fins\fins_wake$($i).txt     
}






###### STEP 2: READ TEXT, COMPARE TO DICT, DUMP FILES #####


# Create and open runspace pool, setup runspaces array with min and max threads
$pool = [RunspaceFactory]::CreateRunspacePool(1, [int]$env:NUMBER_OF_PROCESSORS+1)
$pool.ApartmentState = "MTA"
$pool.Open()
$runspaces = @()


## variables
$chunks = 500  # word chunk size for each file
$total_files = [Math]::Ceiling($wake_words.Count/$chunks)  # total num files based on $chunks size

$counter = 1
for ($i = 0; $i -lt $total_files; $i++) {
    # variables for start and end of book section to evaluate
    $min = $i*$chunks
    $max = $i*$chunks + $chunks - 1
    
    # Create the runspace
    $Runspace = [runspacefactory]::CreateRunspace()
    $Runspace.ApartmentState = [System.Threading.ApartmentState]::STA
    $Runspace.Open()
    # create the PS session and assign the runspace
    $PS = [powershell]::Create()
    $PS.Runspace = $Runspace

    # add the scriptblock and add the argument as reference variables 
    # to avoid having to copy large dictionary and book content for each
    # running thread/runspace
    $PS.AddScript($script) | Out-Null
    $PS.AddArgument([int]$i) | Out-Null 
    $PS.AddArgument([ref]$wake_words) | Out-Null
    $PS.AddArgument($min) | Out-Null
    $PS.AddArgument($max) | Out-Null
    $PS.AddArgument([ref]$dictionary) | Out-Null
    $PS.RunspacePool = $pool  # pooling to reduce thread count didn't work

    # Invoke the scriptblock
    $runspaces += @{ Status=$PS.BeginInvoke() } 

    ## waits if there is more than 5 threads running... pooling didn't work
    $active_runspaces = ($runspaces | where { $_.status.IsCompleted -eq $false }).count
    # while more than 3 threads.. wait for some to finish
    while ($active_runspaces -gt 5) {
        Write-Host Waiting for jobs to finish...
        write-host $active_runspaces active runspaces
        Start-Sleep -Seconds 5
        $active_runspaces = ($runspaces | where { $_.status.IsCompleted -eq $false }).count
    }

    Write-Host ($counter++) / $total_files
}





## waits if there is more than 5 threads running... pooling didn't work
    $active_runspaces = ($runspaces | where { $_.status.IsCompleted -eq $false }).count
    # while more than 3 threads.. wait for some to finish
    while ($active_runspaces -gt 5) {
        Write-Host Waiting for jobs to finish...
        write-host $active_runspaces active runspaces
        Start-Sleep -Seconds 5
        $active_runspaces = ($runspaces | where { $_.status.IsCompleted -eq $false }).count
    }







###### STEP 3: EVAULATE OUTPUT FILES #####

# get output files
$files = Get-ChildItem -Path C:\Users\u28194\Desktop\fins\ |? { $_.FullName -inotlike "*completed.txt" }

# collect text
$text = ''
$text += $files | Get-Content 

# output completed doc
$text | Set-Content -Path "C:\Users\u28194\Desktop\fins\completed.txt"


