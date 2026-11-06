sub Main(args as Dynamic)
    print "RokuCaster: iniciando canal"
    screen = CreateObject("roSGScreen")
    messagePort = CreateObject("roMessagePort")
    screen.SetMessagePort(messagePort)

    deviceInfo = CreateObject("roDeviceInfo")
    resolution = deviceInfo.GetUIResolution()

    scene = screen.CreateScene("MainScene")
    if scene = invalid
        print "RokuCaster: falha ao criar MainScene"
        return
    end if
    scene.screenSize = [resolution.width, resolution.height]

    input = CreateObject("roInput")
    input.SetMessagePort(messagePort)

    screen.Show()
    print "RokuCaster: tela inicial exibida em "; resolution.width; "x"; resolution.height

    if type(args) = "roAssociativeArray"
        launchPlaylistUrl = getParameter(args, "playlistUrl")
        if launchPlaylistUrl = "" and LCase(getParameter(args, "mediaType")) = "shortformvideo"
            launchContentId = getParameter(args, "contentId")
            if isPlaylistManifestUrl(launchContentId) then launchPlaylistUrl = launchContentId
        end if

        launchUrl = getParameter(args, "url")
        if launchUrl = "" then launchUrl = getParameter(args, "contentid")
        launchPlaylist = getParameter(args, "playlist")

        if launchPlaylistUrl <> ""
            launchParameters = {}
            launchParameters.action = "play"
            launchParameters.playlistUrl = launchPlaylistUrl
            launchParameters.statusUrl = getParameter(args, "statusUrl")
            launchParameters.startIndex = getParameter(args, "startIndex")
            scene.callFunc("receiveExternalCommand", launchParameters)
        else if launchUrl <> "" or launchPlaylist <> ""
            scene.callFunc("receiveExternalCommand", args)
        end if
    end if

    while true
        message = wait(0, messagePort)

        if type(message) = "roSGScreenEvent"
            if message.IsScreenClosed() then return
        else if type(message) = "roInputEvent"
            if message.IsInput()
                inputInfo = message.GetInfo()
                print "RokuCaster ECP input: "; FormatJSON(inputInfo)
                scene.callFunc("receiveExternalCommand", inputInfo)
            end if
        end if
    end while
end sub

function getParameter(parameters as Object, targetName as String) as String
    for each parameterName in parameters
        if LCase(parameterName) = LCase(targetName)
            value = parameters[parameterName]
            if value <> invalid then return value.ToStr()
        end if
    end for

    return ""
end function

function isPlaylistManifestUrl(candidateUrl as String) as Boolean
    normalizedUrl = LCase(candidateUrl)
    if Left(normalizedUrl, 7) <> "http://" and Left(normalizedUrl, 8) <> "https://" then return false
    return Instr(1, normalizedUrl, "/playlist/") > 0 and Instr(1, normalizedUrl, ".json") > 0
end function
