sub init()
    m.top.functionName = "fetchPlaylistManifest"
end sub

sub fetchPlaylistManifest()
    transfer = CreateObject("roUrlTransfer")
    transfer.SetUrl(m.top.url)

    manifestJson = transfer.GetToString()
    if manifestJson = invalid or manifestJson = ""
        m.top.error = "The playlist manifest could not be downloaded."
        return
    end if

    m.top.result = manifestJson
end sub
