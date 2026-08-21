$oldPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($oldPath -notlike '*D:\Mostafa\Tickets\tickets\flutter\bin*') {
    $newPath = $oldPath + ';D:\Mostafa\Tickets\tickets\flutter\bin'
    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
    Write-Output "User PATH updated successfully."
} else {
    Write-Output "User PATH already has Flutter SDK."
}
