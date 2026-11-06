sub init()
    m.top.functionName = "postPlaybackStatus"
end sub

sub postPlaybackStatus()
    transfer = CreateObject("roUrlTransfer")
    transfer.SetUrl(m.top.url)
    transfer.SetRequest("POST")
    transfer.AddHeader("Content-Type", "application/json")
    transfer.SetConnectionTimeout(5)

    responseCode = transfer.PostFromString(m.top.payload)
    m.top.result = responseCode
    if responseCode < 200 or responseCode >= 300
        print "RokuCaster playback status HTTP error: "; responseCode
    end if
end sub
